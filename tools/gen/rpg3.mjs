// RPG III(固定形式)の行を正確な桁位置で生成する小さなジェネレーター。
// 出典: RPG/400 Reference SC09-1817(研究時に一次資料で確認済みの桁位置)。
//
// H仕様書: 6=H
// F仕様書: 7-14 ファイル名 15 タイプ(I/O/U/C) 16 指定(P/S/R/T/F) 17 EOF
//          18 順序 19 形式(F/E) 24-27 レコード長 28 限界処理 29-30 キー長
//          31 レコード・アドレス型 32 編成 33-34 オーバーフロー標識
//          35-38 キー開始位置 40-46 装置
// C仕様書: 6=C 7-8 制御レベル 9-17 条件標識(3桁×3組、各組「否定N+標識2桁」
//          の順。実機コンパイルで確認済み: 桁→否定の順で書くとQRG5006/5007)
//          18-27 Factor1 28-32 命令コード 33-42 Factor2(リテラルもこの
//          10桁に収まる長さまで) 43-48 結果 49-51 長さ 52 小数(数値の
//          結果フィールドを新規定義するときは両方明示しないと英数字型に
//          なる。実機コンパイルで確認済み: QRG7044) 53 拡張
//          54-59 結果標識(HI/LO/EQ、各2桁。READのEOF標識はEQに書く。
//          実機コンパイルで確認済み: HI/LOだとQRG5056/5134) 60-74 コメント
//          TAG: Factor1にラベル名。GOTO: Factor2にラベル名(実機確認済み、
//          BEGSR/EXSRと同じFactor1/Factor2の使い分け)
// O仕様書: 7-14 ファイル/レコード名 15 タイプ(H/D/T/E) 23-31 出力標識
//          (C仕様書と同じ「否定+標識2桁」×3組のはずだが、こちらは
//          まだ実機未確認) 32-37 フィールド名/EXCPT名 38 編集コード
//          40-43 終了位置 45-70 定数
function blank(n) { return ' '.repeat(n); }
function put(arr, col1, text) {
  for (let i = 0; i < text.length; i++) arr[col1 - 1 + i] = text[i];
}

// Conditioning-indicator groups (C-spec 9-17, O-spec 23-31): 3 groups of 3
// columns each, and within each group the layout is [N][digit][digit] -
// the N (negation) flag comes BEFORE the 2-digit indicator number, not
// after (confirmed by real compilation: putting the digits first produced
// QRG5006 "Not entry not N or blank" / QRG5007 "Conditioning-Indicator
// entry invalid", because the first digit landed in the N-flag column).
// `inds` is an array of up to 3 strings, each either '30' or 'N30'.
function putCondInd(arr, groupStartCol, inds) {
  inds.forEach((raw, i) => {
    if (!raw) return;
    const neg = raw.startsWith('N');
    const num = neg ? raw.slice(1) : raw;
    const base = groupStartCol + i * 3;
    if (neg) put(arr, base, 'N');
    put(arr, base + 1, num);
  });
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
// `ind`: conditioning indicator(s), e.g. '30', 'N30', or ['30','N31'] for
// up to 3 (AND'ed). See putCondInd() for the column layout within 9-17.
export function cSpec({ level = '', ind = '', f1 = '', op, f2 = '', result = '', len = '', dec = '', ext = '', hi = '', lo = '', eq = '', comment: cm = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'C');
  put(l, 7, level);
  putCondInd(l, 9, Array.isArray(ind) ? ind : [ind]);
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
// `ind`: conditioning indicator(s) for this output line, same format as cSpec's `ind` (see putCondInd()).
export function oSpec({ name = '', type = '', ind = '', field = '', editCode = '', endPos = '', constant = '', blankAfter = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'O');
  if (name) put(l, 7, name);
  if (type) put(l, 15, type);
  putCondInd(l, 23, Array.isArray(ind) ? ind : [ind]);
  put(l, 32, field);
  if (editCode) put(l, 38, editCode);
  if (blankAfter) put(l, 39, blankAfter);
  if (endPos !== '') put(l, 40, String(endPos).padStart(4, ' '));
  if (constant) put(l, 45, constant);
  return finish(l);
}
