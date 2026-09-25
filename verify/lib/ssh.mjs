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

// 台帳に書く status を、実際の結果から機械的に分類する。
export function classifyResult({ code, stdout, stderr, killedForTimeout, spawnError }) {
  const text = `${stdout}\n${stderr}`;
  if (spawnError) return 'refused_or_timeout';
  if (killedForTimeout) return 'refused_or_timeout';
  if (/Permission denied|Authentication failed/i.test(text)) return 'auth_failed';
  if (
    /Connection refused|Connection timed out|Operation timed out|Could not resolve hostname|Connection closed by remote host|No route to host/i.test(
      text,
    )
  ) {
    return 'refused_or_timeout';
  }
  if (code === 0) return 'success';
  return 'unknown';
}
