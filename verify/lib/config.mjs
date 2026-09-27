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

// manifest.library2 の解決(2026-09-27追加、05-12のような2ライブラリー間の
// 移送・切り戻しを検証するため)。省略時は null(&LIB2 を使わないマニフェストの
// 既定)。"*B"/"*2" は resolveLibrary と同じ記号を使う。
export function resolveLibrary2(manifest, cfg) {
  if (!manifest.library2) return null;
  if (manifest.library2 === '*B') return `${cfg.user.toUpperCase()}B`;
  if (manifest.library2 === '*2') return `${cfg.user.toUpperCase()}2`;
  return manifest.library2;
}

// &LIB2 は &LIB より必ず先に置換すること: "&LIB2" は "&LIB" を前方一致で含むため、
// 逆順で置換すると "&LIB2/" が "<lib>2/" のように壊れる。lib2 未指定のマニフェストが
// &LIB2 を使っていたら、私的パターン露出(置換されずマニフェストにそのまま残る)より
// 前に気づけるよう例外にする。検索する区切りは常に "/"(マニフェスト側の書き方)。
// destSep は置換後の区切り: CL/sh 用は "/" のまま、collect の SQL 用は "."(スキーマ
// 修飾)を渡す(既存の &LIB 置換と同じ変換規則)。
export function substituteLibraryPlaceholders(text, lib, lib2, destSep = '/') {
  let result = text;
  if (lib2) {
    result = result.replaceAll('&LIB2/', `${lib2}${destSep}`).replaceAll('&LIB2', lib2);
  } else if (/&LIB2\b/.test(result)) {
    throw new Error('マニフェストが &LIB2 を使っていますが、manifest.library2 が指定されていません。');
  }
  return result.replaceAll('&LIB/', `${lib}${destSep}`).replaceAll('&LIB', lib);
}
