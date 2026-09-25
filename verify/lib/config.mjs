// 接続情報の読み込み。実名・実パスはこのファイルにもコミット先にも書かない。
// 環境変数 PUB400_USER か、コミット対象外の verify/config.local.json(.gitignore の
// *.local.* に一致)から読む。鍵の既定パスは ~/.ssh/pub400。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { repoRoot } from './paths.mjs';

function expandHome(p) {
  if (p.startsWith('~')) return path.join(os.homedir(), p.slice(1));
  return p;
}

export function loadConfig() {
  const configPath = path.join(repoRoot(), 'verify', 'config.local.json');
  let fileConfig = {};
  if (fs.existsSync(configPath)) {
    fileConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }

  const user = process.env.PUB400_USER || fileConfig.user;
  if (!user) {
    throw new Error(
      '接続先ユーザーが未設定です。環境変数 PUB400_USER を設定するか、' +
        'verify/config.example.json を verify/config.local.json にコピーして user を書いてください' +
        '(config.local.json はコミットされません)。',
    );
  }

  const keyPath = expandHome(fileConfig.keyPath || '~/.ssh/pub400');
  if (!fs.existsSync(keyPath)) {
    throw new Error(`鍵ファイルが見つかりません: ${keyPath}`);
  }

  return {
    user,
    keyPath,
    host: fileConfig.host || 'pub400.com',
    port: fileConfig.port || 2222,
  };
}
