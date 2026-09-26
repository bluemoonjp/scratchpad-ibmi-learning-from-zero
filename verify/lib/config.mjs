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

// manifest.library の解決(2026-09-27追加)。既定は開発役 <USER>2。マニフェストで
// 実ユーザー名を直接書くと私的パターン露出になるため、`"*B"` という記号だけを
// 特別扱いし、<USER>B(SAVF/退避役、01-04で確立済みの命名)に解決する。それ以外の
// 文字列は(将来の拡張のため)そのまま library 名として使う。
export function resolveLibrary(manifest, cfg) {
  if (manifest.library === '*B') return `${cfg.user.toUpperCase()}B`;
  return manifest.library || `${cfg.user.toUpperCase()}2`;
}
