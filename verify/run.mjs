#!/usr/bin/env node
// PUB400 実機検証ハーネス。使い方は verify/README.md を参照。
//
//   node verify/run.mjs --status              台帳の状態・次に接続してよい時刻を表示
//   node verify/run.mjs --next-allowed         次に接続してよい時刻だけを ISO8601 で表示
//   node verify/run.mjs --dry-run <partNN>     verify/<partNN>/manifest.json から
//                                               送るスクリプトを組み立てて表示するだけ(接続しない)
//   node verify/run.mjs <partNN>               実際に1回接続し、結果を
//                                               work/verify/results/<partNN>-<timestamp>.json に保存する
//
// 実名・実パスはこのファイル(コミットされる)には一切書かない。接続情報は
// verify/lib/config.mjs 経由で読む。

import fs from 'node:fs';
import path from 'node:path';
import { repoRoot } from './lib/paths.mjs';
import { loadConfig } from './lib/config.mjs';
import { loadLedger, computeGate, recordStart, recordEnd } from './lib/ledger.mjs';
import { runSsh, classifyResult } from './lib/ssh.mjs';
import { anonymize } from './lib/anonymize.mjs';
import { loadManifest, buildQshScript, splitSections } from './lib/batch.mjs';

function printGate(gate) {
  console.log(`allowed: ${gate.allowed}`);
  if (gate.cap !== null) {
    console.log(`24時間の上限: ${gate.cap}回中 ${gate.countInWindow}回`);
  }
  console.log(`next-allowed: ${gate.nextAllowedAt ? gate.nextAllowedAt.toISOString() : '(認証失敗により無期限停止)'}`);
  if (gate.reasons.length) {
    console.log('理由:');
    for (const r of gate.reasons) console.log(`  - ${r}`);
  }
}

function cmdStatus() {
  const ledger = loadLedger();
  const gate = computeGate(ledger);
  console.log(`台帳の接続記録数: ${ledger.connections.length}`);
  console.log(`authFailedEver: ${ledger.authFailedEver}`);
  printGate(gate);
}

function cmdNextAllowed() {
  const ledger = loadLedger();
  const gate = computeGate(ledger);
  console.log(gate.nextAllowedAt ? gate.nextAllowedAt.toISOString() : 'BLOCKED_AUTH_FAILED');
}

function cmdDryRun(batchDirName) {
  const cfg = loadConfigForDryRun();
  const { manifest, baseDir } = loadManifest(batchDirName);
  const script = buildQshScript(manifest, cfg, { baseDir });
  console.log(`--- ${batchDirName} が送るスクリプト(接続はしていません) ---`);
  console.log(script);
}

function loadConfigForDryRun() {
  // --dry-run は接続しないので、ユーザー名が未設定でもプレースホルダーで見られるようにする。
  try {
    return loadConfig();
  } catch {
    return { user: 'DRYRUN', keyPath: '(未設定)', host: 'pub400.com', port: 2222 };
  }
}

async function cmdRun(batchDirName) {
  const ledger = loadLedger();
  const gate = computeGate(ledger);
  if (!gate.allowed) {
    console.error('接続できません(歯止めに抵触):');
    printGate(gate);
    process.exitCode = 1;
    return;
  }

  const cfg = loadConfig();
  const { manifest, baseDir } = loadManifest(batchDirName);
  const script = buildQshScript(manifest, cfg, { baseDir });

  const ledgerIndex = recordStart(manifest.batch, `verify/run.mjs ${batchDirName}`);
  console.log(`接続を開始します(台帳 index=${ledgerIndex})...`);

  const result = await runSsh(cfg, script);
  // connectionStatus は「SSH接続・認証が成功したか」だけを表す(===VFY:start=== が
  // 出たかどうかで判定。verify/lib/ssh.mjs 参照)。スクリプト内の各ステップ
  // (コンパイル・実行・RPG0102の自動応答等)が実際に成功したかどうかは、
  // これとは別に sections の中身(特に vfylog セクション)を読んで判断すること。
  const connectionStatus = classifyResult(result);
  recordEnd(
    ledgerIndex,
    connectionStatus,
    connectionStatus === 'success' ? '' : (result.stderr || '').slice(0, 500),
  );

  const sections = splitSections(result.stdout);
  const anonymizedSections = Object.fromEntries(
    Object.entries(sections).map(([k, v]) => [k, anonymize(v, cfg)]),
  );

  const resultsDir = path.join(repoRoot(), 'work', 'verify', 'results');
  fs.mkdirSync(resultsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const resultsPath = path.join(resultsDir, `${manifest.batch}-${stamp}.json`);
  fs.writeFileSync(
    resultsPath,
    JSON.stringify(
      {
        batch: manifest.batch,
        connectionStatus,
        exitCode: result.code,
        killedForTimeout: result.killedForTimeout,
        sections: anonymizedSections,
        stderr: anonymize(result.stderr, cfg),
      },
      null,
      2,
    ),
    'utf8',
  );

  console.log(`接続の成否: ${connectionStatus}`);
  console.log('スクリプトの中身(各ステップの成否)は保存した結果ファイルの sections を読んで判断してください。');
  console.log(`保存先: ${path.relative(repoRoot(), resultsPath)}`);
  if (connectionStatus !== 'success') {
    console.log('--- stderr(実名は<USER>に置換済み) ---');
    console.log(anonymize(result.stderr, cfg).slice(0, 2000));
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--status') || args.length === 0) {
    cmdStatus();
    return;
  }
  if (args.includes('--next-allowed')) {
    cmdNextAllowed();
    return;
  }
  const dryRunIdx = args.indexOf('--dry-run');
  if (dryRunIdx !== -1) {
    const target = args[dryRunIdx + 1];
    if (!target) throw new Error('--dry-run には対象(例: part05)を指定してください。');
    cmdDryRun(target);
    return;
  }
  // 上記以外は、先頭の非フラグ引数を対象として実接続する。
  const target = args.find((a) => !a.startsWith('--'));
  if (!target) throw new Error('対象(例: part05)を指定してください。');
  await cmdRun(target);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exitCode = 1;
});
