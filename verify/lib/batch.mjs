// マニフェスト(verify/partNN/manifest.json)から、1回のSSH接続で流す qsh 標準入力
// スクリプト全体を組み立てる。手順は計画どおり:
//   1. heredoc で ~/vfy/<batch>/ にファイルを書き出し、CCSID を付ける(setccsid)。
//   2. CPYFRMSTMF でメンバーに取り込む。
//   3. バッチ用の CL ラッパーを生成・コンパイルして CALL する。
//   4. 結果(スプール等)を自分のジョブに限って db2 でテキストに戻す。
//   5. 各段を ===MARKER:name=== で区切り、run.mjs 側で機械的に分解できるようにする。
//
// 未検証の前提(初回の実接続で確認すること、docs/probes.md に記録する):
//   - qsh の system() 呼び出しが同一ジョブ内で連続するか(違えば QTEMP は使えない)。
//   - SYSTOOLS.SPOOLED_FILE_DATA の呼び出し方(引数の形)。ここでは最有力候補を既定にし、
//     失敗したら候補を増やして次回の接続で決着させる(推測で試行錯誤しない、という方針)。

import fs from 'node:fs';
import path from 'node:path';
import { repoRoot } from './paths.mjs';
import { buildClWrapperSource, pgmNameForBatch } from './clgen.mjs';

const MARKER = (name) => `===VFY:${name}===`;

// リポジトリー内で完全に統制している相対パス(バッチ名・メンバー名から機械生成)だけを
// 対象にした最小限のエスケープ。空白・ワイルドカード等の紛れ込みを防ぐ。
function assertSafeRelPath(relPath) {
  if (!/^[A-Za-z0-9._/-]+$/.test(relPath)) {
    throw new Error(`安全でない相対パス: ${relPath}`);
  }
}

// qsh(シェル)側で $HOME を展開させてから絶対パスを作る。CL コマンド(CPYFRMSTMF 等)は
// ~ も $HOME も展開しないため(critiques.json の指摘どおり)、CL 文字列に埋め込むときも
// この二重引用符の中で先にシェルへ展開させてから渡す。
function remoteAbs(relPath) {
  assertSafeRelPath(relPath);
  return `$HOME/${relPath}`;
}

function heredocWrite(relPath, content) {
  // ヒアドキュメントの終端マーカーは、教材ソース中には出てこない文字列にしておく。
  const delim = 'VFY_EOF_9f3';
  return [`cat > "${remoteAbs(relPath)}" <<'${delim}'`, content, delim].join('\n');
}

export function loadManifest(batchDirName) {
  const manifestPath = path.join(repoRoot(), 'verify', batchDirName, 'manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!manifest.batch) manifest.batch = batchDirName;
  return { manifest, manifestPath, baseDir: path.dirname(manifestPath) };
}

export function buildQshScript(manifest, cfg, { baseDir } = {}) {
  const lib = manifest.library || `${cfg.user.toUpperCase()}2`;
  const remoteDir = manifest.remoteDir || `vfy/${manifest.batch}`;
  const lines = [];

  lines.push(`echo ${MARKER('start')}`);
  lines.push(`mkdir -p "${remoteAbs(remoteDir)}"`);

  const fileSteps = manifest.steps.filter((s) => s.type === 'file');
  for (const step of fileSteps) {
    const localPath = path.resolve(baseDir || repoRoot(), step.localPath);
    const content = fs.readFileSync(localPath, 'utf8');
    const remoteRel = `${remoteDir}/${path.basename(step.localPath)}`;
    lines.push(`echo ${MARKER(`transfer:${step.member}`)}`);
    lines.push(heredocWrite(remoteRel, content));
    lines.push(`setccsid ${step.ccsid || 37} "${remoteAbs(remoteRel)}"`);
    if (step.ensureSrcFile) {
      // 既に存在すれば CPF7302 で失敗するだけなので無視してよい(system の終了コードは
      // 見ずに、あとの CPYFRMSTMF が成功するかどうかで判断する)。
      lines.push(
        `system "CRTSRCPF FILE(${lib}/${step.remoteSrcFile}) RCDLEN(${step.ensureSrcFile.recordLength}) TEXT('verify harness auto-create')" 2>&1`,
      );
    }
    lines.push(
      `system "CPYFRMSTMF FROMSTMF('${remoteAbs(remoteRel)}') ` +
        `TOMBR('/QSYS.LIB/${lib}.LIB/${step.remoteSrcFile}.FILE/${step.member}.MBR') MBROPT(*REPLACE) STMFCCSID(${step.ccsid || 37})" 2>&1`,
    );
    lines.push(`echo ${MARKER(`transfer-end:${step.member}`)}`);
  }

  const clSteps = manifest.steps.filter((s) => s.type === 'cl');
  if (clSteps.length) {
    const { pgmName, source } = buildClWrapperSource(manifest, cfg);
    const wrapperRel = `${remoteDir}/${pgmName.toLowerCase()}.clp`;
    lines.push(`echo ${MARKER('wrapper-source')}`);
    lines.push(heredocWrite(wrapperRel, source));
    lines.push(`setccsid 37 "${remoteAbs(wrapperRel)}"`);
    lines.push(
      `system "CPYFRMSTMF FROMSTMF('${remoteAbs(wrapperRel)}') ` +
        `TOMBR('/QSYS.LIB/${lib}.LIB/QCLSRC.FILE/${pgmName}.MBR') MBROPT(*REPLACE) STMFCCSID(37)" 2>&1`,
    );
    lines.push(`echo ${MARKER('compile')}`);
    lines.push(
      `system "CRTCLPGM PGM(${lib}/${pgmName}) SRCFILE(${lib}/QCLSRC) SRCMBR(${pgmName}) REPLACE(*YES)" 2>&1`,
    );
    lines.push(`echo ${MARKER('run')}`);
    lines.push(`system "CALL PGM(${lib}/${pgmName})" 2>&1`);
    lines.push(`echo ${MARKER('run-end')}`);
  }

  const collectSteps = manifest.steps.filter((s) => s.type === 'collect');
  for (const [i, step] of collectSteps.entries()) {
    lines.push(`echo ${MARKER(`collect:${step.kind || 'sql'}:${i}`)}`);
    const sql =
      step.sql ||
      // 既定: 自分のジョブ・自分のユーザーのスプールをテキストで取り出す最有力候補。
      // SYSTOOLS.SPOOLED_FILE_DATA の実際の引数名は未検証(初回接続で確定させる)。
      `SELECT SPOOLED_DATA FROM TABLE(SYSTOOLS.SPOOLED_FILE_DATA(` +
        `JOB_NAME => '*', JOB_USER => CURRENT_USER, JOB_NUMBER => '*', ` +
        `SPOOLED_FILE_NAME => '*', SPOOLED_FILE_NUMBER => -1)) X ` +
        `ORDER BY ORDINAL_POSITION`;
    lines.push(`echo "${sql.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('$', '\\$')}" | db2 -s 2>&1`);
    lines.push(`echo ${MARKER(`collect-end:${i}`)}`);
  }

  lines.push(`echo ${MARKER('end')}`);
  return lines.join('\n') + '\n';
}

// stdoutを ===VFY:marker=== の区切りでセクションに分解する。
export function splitSections(stdout) {
  const parts = stdout.split(/===VFY:([^=]+)===/);
  const sections = {};
  // parts[0] はマーカー前の余り。以降は [marker, body, marker, body, ...]
  for (let i = 1; i < parts.length; i += 2) {
    const name = parts[i];
    const body = parts[i + 1] || '';
    sections[name] = (sections[name] || '') + body;
  }
  return sections;
}

export { pgmNameForBatch };
