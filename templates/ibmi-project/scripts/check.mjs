#!/usr/bin/env node
// リポジトリー内のチェック(依存パッケージなし、素の Node で動く)。
// 1. 配布ソース(固定形式 RPG III / RPG IV / CL / DDS 等)の ASCII / LF / 桁数
// 2. リポジトリー全体の、汎用化された禁止パターン(個人を特定できる情報の漏洩防止)
//
// 注意: これは最終防衛線ではない。実在のユーザー名・ライブラリー名などの
// 具体的な禁止パターンは、このスクリプトには含めていない。自分のプロジェクト固有の
// 秘密(実在のユーザー名・接続先ホスト名等)は、push 前に別途 grep で確認すること。

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();

function gitFiles() {
  const out = execFileSync('git', ['ls-files'], { cwd: ROOT, encoding: 'utf8' });
  return out.split('\n').filter(Boolean);
}

// 桁位置が意味を持つ、配布用の固定形式ソース拡張子
const FIXED_FORM_EXTS = new Set([
  '.rpg', '.clp', '.clle', '.pf', '.lf', '.dspf', '.prtf', '.cmd',
]);
// **FREE / 埋め込み SQL 等、比較的自由な RPGLE 系(ASCII/LF は要求するが桁数は緩め)
const FREE_FORM_EXTS = new Set(['.rpgle', '.rpgleinc', '.sqlrpgle', '.bnd']);

const MAX_COLS_DEFAULT = 80;
const MAX_COLS_OVERRIDES = [
  // CVTRPGSRC の出力(固定形式 RPG IV)を RCDLEN 112 のソース物理ファイルに置く場合は
  // 100 桁まで許容する。自分のプロジェクトの実際の RCDLEN に合わせて調整すること。
  { test: (p) => /qrpgle112/i.test(p) || /-4x\./i.test(p), max: 100 },
];

function maxColsFor(relPath) {
  for (const o of MAX_COLS_OVERRIDES) {
    if (o.test(relPath)) return o.max;
  }
  return MAX_COLS_DEFAULT;
}

const errors = [];

function checkFixedForm(relPath, buf) {
  const text = buf.toString('utf8');
  if (buf.includes(0x0d)) {
    errors.push(`${relPath}: CR (\\r) が含まれています。LF のみにしてください。`);
  }
  if (text.includes('\t')) {
    errors.push(`${relPath}: タブ文字が含まれています。桁位置がずれるため使わないでください。`);
  }
  for (let i = 0; i < buf.length; i++) {
    const b = buf[i];
    // 許可するのは LF(0x0A)と印字可能 ASCII(0x20-0x7E)のみ
    if (b !== 0x0a && !(b >= 0x20 && b <= 0x7e)) {
      const upto = buf.subarray(0, i).toString('utf8');
      const line = upto.split('\n').length;
      errors.push(`${relPath}:${line}: ASCII 範囲外のバイト(0x${b.toString(16)})が含まれています。`);
      break;
    }
  }
  const maxCols = maxColsFor(relPath);
  const lines = text.split('\n');
  lines.forEach((line, idx) => {
    if (line.length > maxCols) {
      errors.push(`${relPath}:${idx + 1}: 行が ${maxCols} 桁を超えています(${line.length} 桁)。`);
    }
  });
}

function checkFreeForm(relPath, buf) {
  if (buf.includes(0x0d)) {
    errors.push(`${relPath}: CR (\\r) が含まれています。LF のみにしてください。`);
  }
  const text = buf.toString('utf8');
  for (let i = 0; i < buf.length; i++) {
    const b = buf[i];
    if (b !== 0x0a && b !== 0x09 && !(b >= 0x20 && b <= 0x7e)) {
      const upto = buf.subarray(0, i).toString('utf8');
      const line = upto.split('\n').length;
      errors.push(`${relPath}:${line}: ASCII 範囲外のバイト(0x${b.toString(16)})が含まれています。`);
      break;
    }
  }
}

// 自分のプロジェクト固有の禁止パターンをここに追加する(実在のユーザー名・
// ホスト名・メール・アドレス等)。以下は例として汎用的なものだけを残してある。
const FORBIDDEN_PATTERNS = [
  {
    name: 'windows-profile-path',
    re: /[A-Za-z]:\\+Users\\+[^\\/\s"'`]+/g,
  },
  {
    name: 'email-address',
    re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g,
    allow: [
      /@example\.(com|jp|org|net)$/,
      /@(test|invalid)\.(com|jp)$/,
    ],
  },
];

function checkForbiddenPatterns(relPath, text) {
  for (const pat of FORBIDDEN_PATTERNS) {
    const matches = text.matchAll(pat.re);
    for (const m of matches) {
      const value = m[0];
      if (pat.allow && pat.allow.some((a) => a.test(value))) continue;
      if (pat.allowGroup && pat.allowGroup(m[1])) continue;
      const upto = text.slice(0, m.index);
      const line = upto.split('\n').length;
      errors.push(`${relPath}:${line}: 禁止パターン(${pat.name})に一致: ${value}`);
    }
  }
}

const files = gitFiles();
for (const relPath of files) {
  const abs = path.join(ROOT, relPath);
  const ext = path.extname(relPath).toLowerCase();
  let buf;
  try {
    buf = readFileSync(abs);
  } catch {
    continue;
  }
  // バイナリらしきファイルはスキップ(NUL バイトを含むもの)
  if (buf.includes(0x00)) continue;

  if (FIXED_FORM_EXTS.has(ext)) {
    checkFixedForm(relPath, buf);
  } else if (FREE_FORM_EXTS.has(ext)) {
    checkFreeForm(relPath, buf);
  }

  // 禁止パターンはテキストとして読めるすべてのファイルに適用する
  const text = buf.toString('utf8');
  checkForbiddenPatterns(relPath, text);
}

if (errors.length > 0) {
  console.error(`check.mjs: ${errors.length} 件の問題が見つかりました。\n`);
  for (const e of errors) console.error(' - ' + e);
  process.exit(1);
} else {
  console.log(`check.mjs: OK(${files.length} ファイルを検査しました)`);
}
