// DDS(表示装置ファイル)の行を正確な桁位置で生成する小さなジェネレーター。
// 物理・論理ファイル用の tools/gen/dds.mjs と基本の桁位置(6=A 17=名前種別
// 19-28=名前 30-34=長さ 35=データ型 36-37=小数桁 45-=キーワード)は共通。
// 表示装置ファイル特有の桁位置(38=使用法 I/O 39-41=行番号 42-44=桁位置)は
// 実機コンパイル(CRTDSPF、Highest Severity 00)で確認済み(04-11)。
// レコード様式レベルのキーワード(CF03(03) 等のファンクション・キー)は、
// R 行の直後に単独行として置く形で実機確認済み。
// 条件標識(フィールド・定数行を標識でON/OFFする書き方)は今回未確認。
// 04-11 では代わりに、CHAINの結果標識をRPG側でMOVELして出力フィールドの
// 内容を書き換える(04-03で確認済みの技法)方式で「見つからない」を表現する。
function pad(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length); }
function padRight(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : ' '.repeat(n - s.length) + s; }

function line({ nameType = '', name = '', length = '', type = '', dec = '', usage = '', row = '', col = '', kw = '', comment = false } = {}) {
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
  if (usage) put(38, usage);
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
export function field(name, length, type, dec, usage, row, col, kw) {
  return line({ name, length, type, dec, usage, row, col, kw: kw || '' });
}
export function constant(text, row, col, kw) {
  return line({ row, col, kw: `${text}${kw ? '  ' + kw : ''}` });
}
export function comment(text) {
  return line({ comment: true, kw: text });
}
