// マニフェスト(verify/partNN/manifest.json)から、1回のSSH接続で流す qsh 標準入力
// スクリプト全体を組み立てる。手順は計画どおり:
//   1. heredoc で ~/vfy/<batch>/ にファイルを書き出す(CCSID タグは既定では
//      付けない。理由は下記コメント参照)。
//   2. CPYFRMSTMF でメンバーに取り込む。
//   3. バッチ用の CL ラッパーを生成・コンパイルして CALL する。
//   4. 結果(スプール等)を自分のジョブに限って db2 でテキストに戻す。
//   5. 各段を ===MARKER:name=== で区切り、run.mjs 側で機械的に分解できるようにする。
//
// 未検証の前提(初回の実接続で確認すること、docs/probes.md に記録する):
//   - qsh の system() 呼び出しが同一ジョブ内で連続するか(違えば QTEMP は使えない)。
//   - SYSTOOLS.SPOOLED_FILE_DATA の呼び出し方(引数の形)。ここでは最有力候補を既定にし、
//     失敗したら候補を増やして次回の接続で決着させる(推測で試行錯誤しない、という方針)。
//
// db2 ユーティリティーの呼び出し方(2026-09-26、2度目の見直し):
//   - フラグは付けない。IBM Docs「Qshell db2 Utility」7.5.0のフラグ表を実際に
//     取得して確認済み: 命名規則(*SYS/*SQL)を切り替えるフラグはこの
//     ユーティリティーに存在しない(`-S`大文字は「出力の空白・パディングを
//     抑制する」の意味で無関係)。以前あった小文字 `-s` はこの一覧に無い
//     未定義フラグで、ユーティリティーが認識できず全体が失敗する恐れが
//     あったため削除した。
//   - SQL 文はパイプ経由の標準入力ではなく、引用符付きの位置パラメーターとして
//     渡す(`db2 "SQL文"`)。標準入力を読むかどうかはIBM Docsのフラグ表にも
//     rbafy75.txt にも明記が無く未検証だったのに対し、IBM Docs自身の用例
//     (「引用符で囲んでdb2コマンドの後ろに書く」)と、rpgpgm.comの実例
//     (`db2 select fruit from mylib.testfile`)は、どちらも位置パラメーター
//     形式を示している。
//   - ライブラリー修飾は `/` ではなく `.`(ドット)にする。rbafy75.txt の
//     「SQL and system naming conventions」節により `.` は SQL 命名規則・
//     システム命名規則の両方で通ると確認済み(800-816行目)なのに対し、
//     `/` はシステム命名規則でしか通らない(このユーティリティーの既定の
//     命名規則がどちらなのか自体は確認していない)。CLラッパー内部の
//     RUNSQL(`&LIB/...`のまま)はこの変更の対象外(そちらは動作確認済みで、
//     db2ユーティリティーへの直接の引数ではないため)。
//
// CCSID の既定(2026-09-26、実接続3回で完全決着): heredoc(`cat > file <<DELIM`。
// ただし直前に`rm -f`で必ず新規作成にする、下記参照)で書いたファイルは、この
// qshセッションの既定動作で CCSID 273(EBCDIC、PUB400のQCCSIDそのもの)として
// タグ付けされ、実バイト列も本物のEBCDIC(接続3回目、真に新規作成した状態で
// `od -x`実測: `4040...`=EBCDIC空白、`e3f0e9c5d9d6`=EBCDIC "T0ZERO"。タグと
// バイト列が一致している)。
//
// 1回目の接続では、ここでさらに`setccsid 1208`+`STMFCCSID(1208)`を明示的に
// 指定していた(=「実際はEBCDICのバイト列を、ASCII/UTF-8だと嘘のタグ付けする」
// ことに相当)。これがCPYFRMSTMF自身を失敗させた(CPC7305で一度メンバーを
// 追加した直後にCPC7309で削除され、CPFA0A2「情報が有効でない」・CPFA095
// 「ストリーム・ファイルはコピーされなかった」で失敗)——タグとバイト列の
// 食い違いによる変換失敗だったと、3回目の接続で完全に裏付けられた。
//
// 何もしなければ(既定)、CPYFRMSTMF はファイル自身の正しいタグ(273)どおりに
// EBCDICとして正しく読み、コンパイル可能な状態でメンバーへコピーできる
// (`CPCA081: Stream file copied to object.`、3回目の接続で確認済み。
// 実際にT0ZEROがコンパイルまで成功した)。
//
// 途中、2回目の接続では`rm -f`をまだ入れておらず、対象パスが1回目の接続の
// `cat >`+`setccsid 1208`で既にCCSID 1208にタグ付けされたまま残っていた
// (ssh結果のstderrに`mkdir: ... File exists`の警告があった。`cat >`は既存
// ファイルをtruncateして書き直すだけでCCSIDタグ自体は変えない)ため、2回目に
// 観測した「CCSID=1208・バイト列もASCII」は「1回目のsetccsidが残したタグ」を
// 見ていただけだった(advisor指摘、3回目の`rm -f`追加で解消・裏付け済み)。
//
// 結論: 既定は「何もしない」(setccsid/STMFCCSIDを一切出さない)のままでよい。
// 将来、非ASCII/DBCSを扱うマニフェスト(第9部の09-02b等)で明示的に別のCCSIDを
// 指定する必要が生じたときのために、`ccsid`に具体的な数値を指定する経路自体は
// 残す。

import fs from 'node:fs';
import path from 'node:path';
import { repoRoot } from './paths.mjs';
import { buildClWrapperSource, pgmNameForBatch } from './clgen.mjs';

const MARKER = (name) => `===VFY:${name}===`;

// manifest の file/cl ステップで `ccsid` を省略した場合や `false` を明示した場合は
// 何も出さない(上記コメント参照、2026-09-26に既定を反転)。具体的な数値を指定した
// 場合だけ setccsid/STMFCCSID を出す。
function resolveCcsid(explicit) {
  if (!explicit) return null;
  return explicit;
}

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
  // 2026-09-26、実接続で発見・確認済みのバグ修正: content は fs.readFileSync で
  // 読んだファイルの中身そのままで、通常は末尾に改行(\n)を1つ持つ。それを
  // そのまま [line1, content, delim].join('\n') すると、content 自身の末尾の
  // \n と、join が line1/content/delim の間に挿入する \n が二重になり、
  // 転送先のファイルに実在する余分な空行が1行増えてしまう(harness-selftest
  // 接続2回目、T0ZERO の実機コンパイルで実際に確認: RPG III コンパイラーが
  // その余分な空行を「Form-Type entry invalid」(QRG2001)として拒否し、
  // T0ZERO が一度もコンパイルできなかった)。content 末尾の改行を1つ取り除いて
  // から join することで、常にちょうど1個の改行だけが終端マーカーの前に来るようにする。
  const trimmedContent = content.replace(/\n$/, '');
  // 2026-09-26、advisor指摘: 同じ相対パスへ複数回接続をまたいで書く場合(このハーネスの
  // 常用パターン)、`cat >` は既存ファイルを truncate して書き直すだけで、CCSID タグ
  // 自体は据え置かれる(前回そのファイルに setccsid 等で付けたタグが残ったまま)。
  // これだと「本当に新規作成したファイルの既定タグ」を毎回正しく観測できない
  // (harness-selftest 接続2・3回目の比較でこの汚染が疑われた)。`cat >` の前に
  // 明示的に削除してから書き直すことで、常に「真に新規作成した直後の既定タグ」を
  // 観測できるようにする(存在しなければ rm は無視されるだけで無害)。
  const p = remoteAbs(relPath);
  return [`rm -f "${p}" 2>&1`, `cat > "${p}" <<'${delim}'`, trimmedContent, delim].join('\n');
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
  lines.push(`echo HOME=$HOME`);
  lines.push(`mkdir -p "${remoteAbs(remoteDir)}"`);

  const fileSteps = manifest.steps.filter((s) => s.type === 'file');
  for (const step of fileSteps) {
    const localPath = path.resolve(baseDir || repoRoot(), step.localPath);
    const content = fs.readFileSync(localPath, 'utf8');
    // 既定は `${remoteDir}/basename`(フラット、既存16本のマニフェストが使う形)。
    // `remotePath` を明示すれば、任意の相対パスへ直接置ける(2026-09-27追加)。
    // CLONEDIR配下のgit clone済みツリーを前提にCPYFRMSTMFするツール
    // (TXLEGACY/TXSNAP/TXMIGR等)を検証するとき、そのツールが期待する相対パス
    // (例: `ibmi-kyozai/src/legacy/qrpgsrc/za0500.rpg`)へ直接ファイルを置くのに使う——
    // 実際にgit cloneする必要はなく(第5部はまだmainに無く、cloneしても取れない。
    // draft側をoriginにpushして晒す判断も避けられる)、ハーネスが個々のファイルを
    // そのものずばりの位置へ置くだけで、ツール自身のCPYFRMSTMFはそのまま動く。
    const remoteRel = step.remotePath || `${remoteDir}/${path.basename(step.localPath)}`;
    lines.push(`echo ${MARKER(`transfer:${step.member || remoteRel}`)}`);
    if (remoteRel.includes('/')) {
      lines.push(`mkdir -p "${remoteAbs(path.posix.dirname(remoteRel))}" 2>&1`);
    }
    lines.push(heredocWrite(remoteRel, content));
    // 2026-09-26、advisor指摘: heredoc(`cat > ... <<DELIM`)で書いた直後のファイルが
    // 実際にどのCCSIDでタグ付けされ、どんなバイト列になっているかを、setccsidで
    // 上書きする前に見る診断(harness-selftest失敗の原因調査用、step.debugCcsid で
    // 明示的に有効にしたときだけ出す。既定はオフで他のマニフェストへの影響なし)。
    // 2026-09-26、advisor指摘(2回目): `attr -p CCSID` は誤った構文だった
    // (接続2回目の結果: `attr: 001-2249 Attribute ... is not valid.`)。
    // `ls -S` が既にCCSIDを1列目に出す(接続2回目で確認済み)ので、それだけで足りる。
    if (step.debugCcsid) {
      const p = remoteAbs(remoteRel);
      lines.push(`echo ${MARKER(`debug-ccsid:${step.member}:before`)}`);
      lines.push(`ls -S "${p}" 2>&1`);
      lines.push(`od -x "${p}" 2>&1 | head -2`);
      lines.push(`echo ${MARKER(`debug-ccsid:${step.member}:before-end`)}`);
    }
    const ccsid = resolveCcsid(step.ccsid);
    if (ccsid) {
      lines.push(`setccsid ${ccsid} "${remoteAbs(remoteRel)}"`);
    }
    if (step.debugCcsid) {
      const p = remoteAbs(remoteRel);
      lines.push(`echo ${MARKER(`debug-ccsid:${step.member}:after`)}`);
      lines.push(`ls -S "${p}" 2>&1`);
      lines.push(`od -x "${p}" 2>&1 | head -2`);
      lines.push(`echo ${MARKER(`debug-ccsid:${step.member}:after-end`)}`);
    }
    if (step.ensureSrcFile) {
      // 既に存在すれば CPF7302 で失敗するだけなので無視してよい(system の終了コードは
      // 見ずに、あとの CPYFRMSTMF が成功するかどうかで判断する)。
      lines.push(
        `system "CRTSRCPF FILE(${lib}/${step.remoteSrcFile}) RCDLEN(${step.ensureSrcFile.recordLength}) TEXT('verify harness auto-create')" 2>&1`,
      );
    }
    // `remoteSrcFile`/`member` を省略した場合は、IFS上にファイルを置くだけで終わる
    // (CPYFRMSTMFでどのメンバーにも取り込まない)。CLONEDIR配下のツリーを再現する
    // ためのファイル(TXLEGACY等が自分でCPYFRMSTMFする対象)はこちらを使う。
    if (step.remoteSrcFile) {
      const stmfCcsid = ccsid ? ` STMFCCSID(${ccsid})` : '';
      lines.push(
        `system "CPYFRMSTMF FROMSTMF('${remoteAbs(remoteRel)}') ` +
          `TOMBR('/QSYS.LIB/${lib}.LIB/${step.remoteSrcFile}.FILE/${step.member}.MBR') MBROPT(*REPLACE)${stmfCcsid}" 2>&1`,
      );
    }
    lines.push(`echo ${MARKER(`transfer-end:${step.member || remoteRel}`)}`);
  }

  // `sh` ステップ: qsh(PASE)のシェル・コマンドを直接埋め込む(`system("...")`で
  // CLコマンドとして解釈させるのではない)。CL には無い操作が必要なマニフェスト向け
  // (2026-09-27追加、2Cの一部)。`file`ステップの後・`cl`ステップの前に置かれる。
  const shSteps = manifest.steps.filter((s) => s.type === 'sh');
  for (const step of shSteps) {
    lines.push(`echo ${MARKER(`sh:${step.label || 'step'}`)}`);
    // collectステップと同じ理由で&LIBを置換する(2026-09-27、advisor指摘: 実装
    // 漏れがあり、マニフェストに実ライブラリー名を決め打ちで書く=私的パターン
    // 露出の恐れがあった)。cl ステップと違い1行のCL文をwrapClStatement()で
    // 折り返す仕組みは経由しないため、`&LIB/`形も単純な文字列置換で済ませる。
    lines.push(step.cmd.replaceAll('&LIB/', `${lib}/`).replaceAll('&LIB', lib));
    lines.push(`echo ${MARKER(`sh-end:${step.label || 'step'}`)}`);
  }

  const clSteps = manifest.steps.filter((s) => s.type === 'cl');
  if (clSteps.length) {
    const { pgmName, source, logTable } = buildClWrapperSource(manifest, cfg);
    const wrapperRel = `${remoteDir}/${pgmName.toLowerCase()}.clp`;

    // ラッパーが DELETE FROM/INSERT INTO する先の表。無ければ作る(存在すれば
    // SQL0601 で失敗するだけなので、system の終了コードは見ずに無視する)。
    // QTEMP ではなくライブラリー内の永続表にするのは、qsh の system() 呼び出しが
    // 同一ジョブ内で連続する保証がない(未検証)ため、DONE/FAILSAFE 時点の
    // INSERT(ラッパーと同じジョブ内)だけがジョブ・ログを確実に読める経路だから。
    lines.push(`echo ${MARKER('ensure-log-table')}`);
    lines.push(
      `system "RUNSQL SQL('CREATE TABLE ${logTable} (SEQ INT, MSG VARCHAR(200))') COMMIT(*NONE)" 2>&1`,
    );

    lines.push(`echo ${MARKER('wrapper-source')}`);
    lines.push(heredocWrite(wrapperRel, source));
    // ccsid の扱いは上の file ステップと同じ方針(既定 1208、`false` で無指定に戻せる)。
    const wrapperCcsid = resolveCcsid(manifest.wrapperCcsid);
    if (wrapperCcsid) {
      lines.push(`setccsid ${wrapperCcsid} "${remoteAbs(wrapperRel)}"`);
    }
    const wrapperStmfCcsid = wrapperCcsid ? ` STMFCCSID(${wrapperCcsid})` : '';
    lines.push(
      `system "CPYFRMSTMF FROMSTMF('${remoteAbs(wrapperRel)}') ` +
        `TOMBR('/QSYS.LIB/${lib}.LIB/QCLSRC.FILE/${pgmName}.MBR') MBROPT(*REPLACE)${wrapperStmfCcsid}" 2>&1`,
    );
    lines.push(`echo ${MARKER('compile')}`);
    lines.push(
      `system "CRTCLPGM PGM(${lib}/${pgmName}) SRCFILE(${lib}/QCLSRC) SRCMBR(${pgmName}) REPLACE(*YES)" 2>&1`,
    );
    lines.push(`echo ${MARKER('run')}`);
    lines.push(`system "CALL PGM(${lib}/${pgmName})" 2>&1`);
    lines.push(`echo ${MARKER('run-end')}`);

    lines.push(`echo ${MARKER('vfylog')}`);
    // db2 ユーティリティーへは、パイプ経由の標準入力ではなく引用符付きの
    // 位置パラメーターとして渡す(2026-09-26、advisor指摘・一次資料で再確認: IBM
    // Docsの用例もrpgpgm.comの実例も、標準入力ではなく `db2 "SQL文"` の形。
    // 標準入力を読むかどうかはこの2資料のどちらにも明記が無い、確認されていない
    // 前提だった)。区切りも `.`(SQL命名規則でも通る、rbafy75.txt 800-816行目)に
    // 統一する。RUNSQL(CLラッパー内部)は `/` のままでよい(そちらは動作確認済み)。
    const logTableDotted = logTable.replace('/', '.');
    lines.push(`db2 "SELECT MSG FROM ${logTableDotted} ORDER BY SEQ" 2>&1`);
    lines.push(`echo ${MARKER('vfylog-end')}`);
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
    // collect ステップは別の db2 呼び出し(接続先ジョブと同一かどうか未検証)で
    // 走るため、clSteps と違い CURRENT_SCHEMA 等の対象ライブラリー文脈に頼れない。
    // clSteps の substLib() と同じ置換をここでも行い、manifest 側で &LIB と
    // 書けるようにする(cl ステップとの一貫性、決め打ちの絶対ライブラリー名を
    // manifest に書かずに済ませるため)。`&LIB/` は `<lib>.`(ドット区切り)に
    // 変える(2026-09-26、db2ユーティリティー呼び出し方式の見直しに合わせる。
    // 上のvfylogと同じ理由・同じ根拠)。&LIB 単体(スラッシュを伴わない参照)が
    // 残っていた場合はそのまま名前だけの置換にする。
    const substitutedSql = sql.replaceAll('&LIB/', `${lib}.`).replaceAll('&LIB', lib);
    // db2 へは引用符付きの位置パラメーターとして渡す(パイプ経由の標準入力では
    // ない。上のvfylogと同じ理由)。
    lines.push(`db2 "${substitutedSql.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('$', '\\$')}" 2>&1`);
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
