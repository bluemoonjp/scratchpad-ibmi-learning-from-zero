#!/usr/bin/env node
// FLDREF (src/legacy/qddssrc/fldref.pf, DDS) と FLDREFR
// (src/legacy/qrpgsrc/fldrefr.rpg, RPG III I仕様書DS) が、同じフィールド名・
// 長さ・型・小数桁を保っていることを確認する恒久的なチェック。
//
// 経緯: 生成時に手で「6文字以内」を確認したin-script assertionはその場限りの
// 一時生成スクリプトの一部で、生成後にスクリプト自体を削除したため
// リポジトリーには残らなかった(critique参照)。このスクリプトはその代わりに
// 常駐し、`node scripts/check-fldref-fldrefr-consistency.mjs` で何度でも
// 再実行できる。
//
// 桁位置は生成元と同じ前提(tools/gen/dds.mjs field()/tools/gen/rpg3.mjs
// iSpecSubfield())に基づく。パーサーはこの2ファイル専用で、汎用DDS/RPG
// パーサーではない。

import { readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const DDS_PATH = 'src/legacy/qddssrc/fldref.pf';
const RPG_PATH = 'src/legacy/qrpgsrc/fldrefr.rpg';

const MAX_SYMBOL_LEN = 6; // RPG III symbolic name limit

function readLines(relPath) {
  const text = readFileSync(path.join(ROOT, relPath), 'utf8');
  return text.split('\n');
}

// ---- DDS (fldref.pf) field lines ----
// dds.mjs field()/line(): col6='A', col17=nameType (blank for a plain field
// line, 'R' for the record line, 'K' for a key line), col19-28=name(10,
// left-justified), col30-34=length(5, right-justified), col35=type(1),
// col36-37=decimals(2, right-justified).
function parseDdsFields(relPath) {
  const fields = [];
  for (const line of readLines(relPath)) {
    if (line.length < 37) continue;
    if (line[5] !== 'A') continue; // col6
    if (line[6] === '*') continue; // comment line
    const nameType = line[16]; // col17
    if (nameType !== ' ') continue; // skip record (R) / key (K) lines
    const name = line.slice(18, 28).trim(); // col19-28
    if (!name) continue;
    const lengthStr = line.slice(29, 34).trim(); // col30-34
    const type = line[34]; // col35
    const decStr = line.slice(35, 37).trim(); // col36-37
    if (!lengthStr || !type || type === ' ') continue;
    fields.push({
      name,
      length: Number(lengthStr),
      type,
      decimals: decStr === '' ? null : Number(decStr),
      source: `${relPath}: ${line}`,
    });
  }
  return fields;
}

// ---- RPG III I-spec DS subfields (fldrefr.rpg) ----
// rpg3.mjs iSpecSubfield()/iSpecDS(): col6='I'. The DS header line has
// literal 'DS' at col19-20 (index 18-19); subfield lines instead carry
// from/to at col44-47/48-51 (index 43-46/47-50, right-justified),
// decimals at col52 (index 51), name at col53+ (index 52+).
function parseRpgSubfields(relPath) {
  const subfields = [];
  for (const line of readLines(relPath)) {
    if (line.length < 53) continue;
    if (line[5] !== 'I') continue; // col6
    if (line[6] === '*') continue; // comment line (col7)
    if (line.slice(18, 20) === 'DS') continue; // DS header line
    const name = line.slice(52).trim(); // col53-
    if (!name) continue;
    const fromStr = line.slice(43, 47).trim(); // col44-47
    const toStr = line.slice(47, 51).trim(); // col48-51
    const decChar = line[51]; // col52
    if (!fromStr || !toStr) continue;
    const from = Number(fromStr);
    const to = Number(toStr);
    subfields.push({
      name,
      length: to - from + 1,
      decimals: decChar === ' ' || decChar === '' ? null : Number(decChar),
      source: `${relPath}: ${line}`,
    });
  }
  return subfields;
}

const errors = [];

const ddsFields = parseDdsFields(DDS_PATH);
const rpgSubfields = parseRpgSubfields(RPG_PATH);

if (ddsFields.length === 0) {
  errors.push(`${DDS_PATH}: フィールド定義行が1件も見つかりませんでした(パーサーの前提が崩れていないか確認してください)。`);
}
if (rpgSubfields.length === 0) {
  errors.push(`${RPG_PATH}: サブフィールド定義行が1件も見つかりませんでした(パーサーの前提が崩れていないか確認してください)。`);
}

// 6文字シンボル名制限(RPG III)。DDS側は10文字まで許容されるため、この
// チェックはFLDREFR(RPG)側の名前、およびFLDREF側でFLDREFRと対応させる名前
// の両方に適用する(このリポジトリーには意図的な反例 db/v1/tantom.pf の
// TANTOCODE/TANTONAME が既にある)。
for (const f of [...ddsFields, ...rpgSubfields]) {
  if (f.name.length > MAX_SYMBOL_LEN) {
    errors.push(`${f.source}\n  -> フィールド名 "${f.name}" が RPG III の6文字制限を超えています(${f.name.length}文字)。`);
  }
}

// 名前で対応付けて、長さ・小数桁が一致するか確認する。
// 型についてはDDS側のみ表現がある(A=英数字, S=ゾーン10進数)。RPG III
// I仕様書のサブフィールドには型欄が無く、decimalsの有無(52桁目)でしか
// 数値/英数字を区別できないため、「decimals!=nullならDDS側typeは数値系
// (S/P/B)、nullならA」という緩い対応で検証する。
const numericTypes = new Set(['S', 'P', 'B']);
const ddsByName = new Map(ddsFields.map((f) => [f.name, f]));
const rpgByName = new Map(rpgSubfields.map((f) => [f.name, f]));

for (const [name, ddsField] of ddsByName) {
  const rpgField = rpgByName.get(name);
  if (!rpgField) {
    errors.push(`${DDS_PATH} のフィールド "${name}" に対応する FLDREFR (${RPG_PATH}) のサブフィールドがありません。`);
    continue;
  }
  if (ddsField.length !== rpgField.length) {
    errors.push(`フィールド "${name}": 長さ不一致 - ${DDS_PATH}=${ddsField.length}, ${RPG_PATH}=${rpgField.length}`);
  }
  const ddsIsNumeric = numericTypes.has(ddsField.type);
  const rpgIsNumeric = rpgField.decimals !== null;
  if (ddsIsNumeric !== rpgIsNumeric) {
    errors.push(`フィールド "${name}": 型の不一致の疑い - ${DDS_PATH} type=${ddsField.type}(数値系=${ddsIsNumeric}) vs ${RPG_PATH} decimals=${rpgField.decimals}(数値系として扱われている=${rpgIsNumeric})`);
  }
  if (ddsIsNumeric && (ddsField.decimals ?? 0) !== (rpgField.decimals ?? 0)) {
    errors.push(`フィールド "${name}": 小数桁不一致 - ${DDS_PATH}=${ddsField.decimals}, ${RPG_PATH}=${rpgField.decimals}`);
  }
}

for (const [name] of rpgByName) {
  if (!ddsByName.has(name)) {
    errors.push(`${RPG_PATH} のサブフィールド "${name}" に対応する FLDREF (${DDS_PATH}) のフィールドがありません。`);
  }
}

if (errors.length > 0) {
  console.error(`check-fldref-fldrefr-consistency.mjs: ${errors.length} 件の不整合が見つかりました。\n`);
  for (const e of errors) console.error(' - ' + e);
  process.exit(1);
} else {
  console.log(`check-fldref-fldrefr-consistency.mjs: OK(FLDREF/FLDREFR ${ddsFields.length} フィールドが一致、全シンボル名が${MAX_SYMBOL_LEN}文字以内)`);
}
