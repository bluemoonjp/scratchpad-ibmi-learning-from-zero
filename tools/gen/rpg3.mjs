// RPG III(固定形式)の行を正確な桁位置で生成する小さなジェネレーター。
// 出典: RPG/400 Reference SC09-1817(研究時に一次資料で確認済みの桁位置)。
//
// H仕様書: 6=H
// F仕様書: 7-14 ファイル名 15 タイプ(I/O/U/C) 16 指定(P/S/R/T/F) 17 EOF
//          18 順序 19 形式(F/E) 24-27 レコード長 28 限界処理 29-30 キー長
//          31 レコード・アドレス型 32 編成 33-34 オーバーフロー標識
//          35-38 キー開始位置 40-46 装置
// C仕様書: 6=C 7-8 制御レベル 9-17 条件標識(9,12,15 + N) 18-27 Factor1
//          28-32 命令コード 33-42 Factor2 43-48 結果 49-51 長さ 52 小数
//          53 拡張 54-59 結果標識(HI/LO/EQ、各2桁) 60-74 コメント
// O仕様書: 7-14 ファイル/レコード名 15 タイプ(H/D/T/E) 23-31 出力標識
//          32-37 フィールド名/EXCPT名 38 編集コード 40-43 終了位置
//          45-70 定数
function blank(n) { return ' '.repeat(n); }
function put(arr, col1, text) {
  for (let i = 0; i < text.length; i++) arr[col1 - 1 + i] = text[i];
}
function finish(arr, maxCol = 80) {
  const out = arr.join('').replace(/\s+$/, '');
  if (out.length > maxCol) {
    throw new Error(`RPG III line exceeds ${maxCol} columns (${out.length}): ${out}`);
  }
  return out;
}

// 桁6は空白のまま、桁7の * だけでコメント行になる(私的リポジトリーの
// HELLO.rpg で実機コンパイル済みの形に合わせている)。
export function comment(text) {
  const l = blank(80).split('');
  put(l, 7, '*');
  put(l, 9, text);
  return finish(l);
}

export function hSpec(opts = {}) {
  const l = blank(80).split('');
  put(l, 6, 'H');
  return finish(l);
}

// F-spec: name(<=8), type 'I'|'O'|'U'|'C', designation 'P'|'S'|'R'|'T'|'F'|' ',
// form 'F'|'E', recLen (program-described only), device e.g. 'DISK','PRINTER','WORKSTN'
export function fSpec({ name, type, designation = ' ', eof = ' ', seq = ' ', form, recLen = '', device = '', keyLen = '', addType = '', org = '', overflow = '', extra = '' }) {
  const l = blank(80).split('');
  put(l, 6, 'F');
  put(l, 7, name);
  put(l, 15, type);
  put(l, 16, designation);
  put(l, 17, eof);
  put(l, 18, seq);
  put(l, 19, form);
  if (recLen !== '') put(l, 24, String(recLen).padStart(4, ' '));
  if (keyLen !== '') put(l, 29, String(keyLen).padStart(2, ' '));
  if (addType !== '') put(l, 31, addType);
  if (org !== '') put(l, 32, org);
  if (overflow !== '') put(l, 33, overflow);
  put(l, 40, device);
  if (extra) put(l, 47, extra);
  return finish(l);
}

// C-spec factory. All fields optional strings; caller supplies exact text.
export function cSpec({ level = '', ind = '', f1 = '', op, f2 = '', result = '', len = '', dec = '', ext = '', hi = '', lo = '', eq = '', comment: cm = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'C');
  put(l, 7, level);
  put(l, 9, ind);
  put(l, 18, f1);
  put(l, 28, op);
  put(l, 33, f2);
  put(l, 43, result);
  if (len !== '') put(l, 49, String(len).padStart(3, ' '));
  if (dec !== '') put(l, 52, String(dec));
  put(l, 53, ext);
  put(l, 54, hi);
  put(l, 56, lo);
  put(l, 58, eq);
  if (cm) put(l, 60, cm);
  return finish(l);
}

// O-spec factory (basic: EXCPT/detail lines with field list handled by caller as raw text after col 32 if needed)
export function oSpec({ name = '', type = '', ind = '', field = '', editCode = '', endPos = '', constant = '', blankAfter = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'O');
  if (name) put(l, 7, name);
  if (type) put(l, 15, type);
  if (ind) put(l, 23, ind);
  put(l, 32, field);
  if (editCode) put(l, 38, editCode);
  if (blankAfter) put(l, 39, blankAfter);
  if (endPos !== '') put(l, 40, String(endPos).padStart(4, ' '));
  if (constant) put(l, 45, constant);
  return finish(l);
}
