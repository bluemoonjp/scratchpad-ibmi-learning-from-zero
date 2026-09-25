// SSH接続の実行。docs/probes.md で実績のある形をそのまま踏襲する:
//   ssh -i <鍵> -p 2222 -o BatchMode=yes -o ConnectTimeout=20 -o IdentitiesOnly=yes
//       -o StrictHostKeyChecking=accept-new <USER>@pub400.com /usr/bin/qsh
// リモート・コマンドとして /usr/bin/qsh を直接起動し(ログイン・シェルを経由しない)、
// 標準入力からシェル・コマンドを渡す。

import { spawn } from 'node:child_process';

export function buildSshArgs(cfg) {
  return [
    '-i', cfg.keyPath,
    '-p', String(cfg.port),
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=20',
    '-o', 'ServerAliveInterval=30', // ハングしかけた接続をこちら側から早めに検知するため
    '-o', 'IdentitiesOnly=yes',
    '-o', 'StrictHostKeyChecking=accept-new',
    `${cfg.user}@${cfg.host}`,
    '/usr/bin/qsh',
  ];
}

// ハングの恐れがある試験がバッチの最後に置かれている前提でも、こちら側のkillタイマーで
// 必ず終わらせる。timeoutMsは「1接続で複数ステップをまとめて流す」運用を想定し長めに取る。
export function runSsh(cfg, stdinScript, { timeoutMs = 180_000 } = {}) {
  return new Promise((resolve) => {
    const args = buildSshArgs(cfg);
    const child = spawn('ssh', args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    let killedForTimeout = false;

    const timer = setTimeout(() => {
      killedForTimeout = true;
      child.kill('SIGKILL');
    }, timeoutMs);

    child.stdout.on('data', (d) => {
      stdout += d.toString('utf8');
    });
    child.stderr.on('data', (d) => {
      stderr += d.toString('utf8');
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      resolve({ code, stdout, stderr, killedForTimeout });
    });
    child.on('error', (err) => {
      clearTimeout(timer);
      resolve({ code: null, stdout, stderr: `${stderr}\n${err.message}`, killedForTimeout: false, spawnError: err });
    });

    child.stdin.write(stdinScript);
    child.stdin.end();
  });
}

// 台帳に書く status(=接続そのものの成否)を分類する。
//
// 重要: stdout/stderr の全体を "Connection refused" 等の文字列で走査してはいけない。
// リモート側の出力(例: P33 で curl が返す "Connection refused" のような通信エラー
// メッセージ、EACCES を含むエラー行)がたまたま含まれているだけで、接続自体は
// 成功しているのに auth_failed/refused_or_timeout に誤判定し、無期限停止や3時間
// 停止を誤って発動してしまう(advisor 指摘)。
//
// 代わりに、buildQshScript() が最初に送る `echo ===VFY:start===` が stdout に
// 現れたかどうかだけを見る。これは「SSH 認証が成功し、qsh がこちらのスクリプトを
// 実行し始めた」ことの確実な証拠であり、そのあとリモート側で何が起きても
// (スクリプト内の個々のステップの成否は結果ファイルの sections で別途判断する)、
// 接続としては成功として台帳に記録する。
const START_MARKER = '===VFY:start===';

export function classifyResult({ code, stdout, stderr, killedForTimeout, spawnError }) {
  if (stdout.includes(START_MARKER)) {
    return 'success';
  }
  if (spawnError) return 'refused_or_timeout';
  // 公開鍵が拒否された場合、OpenSSH クライアントは exit 255 で
  // "Permission denied (publickey" を stderr に出す(鍵認証のみを使う設定のため、
  // パスワード等へのフォールバックは起きない)。
  if (code === 255 && /Permission denied \(publickey/i.test(stderr)) {
    return 'auth_failed';
  }
  // start マーカーが出る前に切れた(タイムアウトで kill された、接続確立前に
  // 切断された等)場合は、接続そのものが失敗したとみなす。
  return 'refused_or_timeout';
}
