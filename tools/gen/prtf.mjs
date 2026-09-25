// DDS(印刷装置ファイル)の行を正確な桁位置で生成する小さなジェネレーター。
// 基本の桁位置は tools/gen/dds.mjs・tools/gen/dspf.mjs と共通
// (6=A 17=名前種別 19-28=名前 30-34=長さ 35=データ型 36-37=小数桁 45-=キーワード)。
// 印刷装置ファイルは対話的な使用法(38桁目のI/O)を持たないため、その桁は書かない。
// 垂直方向の送りは SPACEA/SKIPB 等のレコード様式レベルのキーワードで行うのが通例で、
// 39-41桁目(行番号)は使わない(固定行番号指定が必要な場合のみ呼び出し側が渡す)。
// 水平方向の桁位置(42-44)は DSPF と同じ意味・桁位置。
// **このファイルの桁位置は一次資料(RPG/400 Reference の DDS 章)と dspf.mjs からの
// 類推に基づく組み立てであり、このリポジトリーではまだ実機コンパイルで確認して
// いない**(実行計画ステップ1のプローブ「E仕様書とコンパイル時配列、DS、印刷装置
// ファイルのコンパイル」で確認する予定)。使う前に必ず実機で確かめること。

function pad(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length); }
function padRight(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : ' '.repeat(n - s.length) + s; }

function line({ nameType = '', name = '', length = '', type = '', dec = '', row = '', col = '', kw = '', comment = false } = {}) {
  let l = ' '.repeat(80).split('');
  const put = (col1, text) => {
    for (let i = 0; i < text.length; i++) l[col1 - 1 + i] = text[i];
  };
  put(6, 'A');
  if (comment) put(7, '*');
  if (nameType) put(17, nameType);
  if (name) put(19, pad(name, 10));
  if (length !== '') put(30, padRight(String(length), 5));
  if (type) put(35, type);
  if (dec !== '') put(36, padRight(String(dec), 2));
  if (row !== '') put(39, padRight(String(row), 3));
  if (col !== '') put(42, padRight(String(col), 3));
  if (kw) put(45, kw);
  const out = l.join('').replace(/\s+$/, '');
  if (out.length > 80) {
    throw new Error(`DDS line exceeds 80 columns (${out.length}): ${out}`);
  }
  return out;
}

export function recordFormat(name, kw) {
  return line({ nameType: 'R', name, kw: kw || '' });
}
export function keyword(kw) {
  return line({ kw });
}
export function field(name, length, type, dec, col, kw) {
  return line({ name, length, type, dec, col, kw: kw || '' });
}
export function constant(text, col, kw) {
  return line({ col, kw: `${text}${kw ? '  ' + kw : ''}` });
}
export function comment(text) {
  return line({ comment: true, kw: text });
}

// レコード様式レベルの垂直送りキーワード(レコード様式のR行の直後に単独行で置く)。
export function spaceA(n = 1) {
  return keyword(`SPACEA(${n})`);
}
export function skipB(n) {
  return keyword(`SKIPB(${n})`);
}
export function skipA(n) {
  return keyword(`SKIPA(${n})`);
}
// オーバーフロー標識(F仕様書の33-34桁目に対応する標識番号を指定する使い方が一般的)。
export function ovrflw(ind) {
  return keyword(`OVERFLOW(${ind})`);
}
export function pagnbr(kind = '') {
  // kind: '' (現在ページ番号を出力するフィールドに使う) | '*NODSP' | '*RESET'
  return keyword(kind ? `PAGNBR(${kind})` : 'PAGNBR');
}
export function date(fmt = '') {
  return keyword(fmt ? `DATE(${fmt})` : 'DATE');
}
export function edtCde(code) {
  return keyword(`EDTCDE(${code})`);
}
export function edtWrd(word) {
  return keyword(`EDTWRD(${word})`);
}
