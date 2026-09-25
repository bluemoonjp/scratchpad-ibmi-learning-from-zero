// DDS(表示装置ファイル)の行を正確な桁位置で生成する小さなジェネレーター。
// 物理・論理ファイル用の tools/gen/dds.mjs と基本の桁位置(6=A 17=名前種別
// 19-28=名前 30-34=長さ 35=データ型 36-37=小数桁 45-=キーワード)は共通。
// 表示装置ファイル特有の桁位置(38=使用法 I/O 39-41=行番号 42-44=桁位置)は
// 実機コンパイル(CRTDSPF、Highest Severity 00)で確認済み(04-11)。
// レコード様式レベルのキーワード(CF03(03) 等のファンクション・キー)は、
// R 行の直後に単独行として置く形で実機確認済み。
// 条件標識(フィールド・定数行を標識でON/OFFする書き方、桁7-16)は、**04-11で
// 実際に試みて失敗した既知の障害**(docs/probes.md 参照: 桁7に標識番号を直接
// 置く形を試し、CPD7410/CPD7606/CPD5238 で失敗、正しい桁位置を特定できずに
// 保留にした)。ここで採用している桁位置(桁7=関係(A/O、同じフィールド/定数を
// 追加の標識条件で継続する2行目以降に指定)、桁8-16=標識3組×3桁(各組「N(否定、
// 任意)+標識2桁」))は、04-11 で失敗した「桁7に標識番号を直接置く」形とは異なる
// (IBM の DDS の一般公開資料に基づく候補)が、**このリポジトリーではまだ実機
// コンパイルで確認していない**。使う前に必ず候補どおりコンパイルが通ることを
// 実機で確かめること(verify/part05-gen-probe/ が確認用のバッチを用意している。
// もし同じ CPD7410 系で失敗したら、桁位置そのものを疑うこと)。
// 04-11 では代わりに、CHAINの結果標識をRPG側でMOVELして出力フィールドの
// 内容を書き換える(04-03で確認済みの技法)方式で「見つからない」を表現した。
// 第5部の旧システム設計(TK0100D/MN0000D)も、この条件標識には依存せず同じ
// MOVEL方式を踏襲する。
function pad(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length); }
function padRight(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : ' '.repeat(n - s.length) + s; }

// `ind`: up to 3 entries like '30' or 'N30' (AND'ed on this line, same
// notation as tools/gen/rpg3.mjs's cSpec `ind`). `indRel`: '' | 'A' | 'O',
// column 7, used only on a 2nd/3rd DDS line that adds another OR'd (or
// AND'ed) indicator combination to the SAME field/constant/keyword above it.
function putCondInd(l, put, ind, indRel) {
  if (indRel) put(7, indRel);
  const inds = Array.isArray(ind) ? ind : [ind];
  inds.forEach((raw, i) => {
    if (!raw) return;
    const neg = raw.startsWith('N');
    const num = neg ? raw.slice(1) : raw;
    const base = 8 + i * 3;
    if (neg) put(base, 'N');
    put(base + 1, num);
  });
}

function line({ nameType = '', name = '', length = '', type = '', dec = '', usage = '', row = '', col = '', kw = '', comment = false, ind = '', indRel = '' } = {}) {
  let l = ' '.repeat(80).split('');
  const put = (col1, text) => {
    for (let i = 0; i < text.length; i++) l[col1 - 1 + i] = text[i];
  };
  put(6, 'A');
  if (comment) put(7, '*');
  if (ind) putCondInd(l, put, ind, indRel);
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
export function keyword(kw, { ind = '', indRel = '' } = {}) {
  return line({ kw, ind, indRel });
}
export function field(name, length, type, dec, usage, row, col, kw, { ind = '', indRel = '' } = {}) {
  return line({ name, length, type, dec, usage, row, col, kw: kw || '', ind, indRel });
}
export function constant(text, row, col, kw, { ind = '', indRel = '' } = {}) {
  return line({ row, col, kw: `${text}${kw ? '  ' + kw : ''}`, ind, indRel });
}
export function comment(text) {
  return line({ comment: true, kw: text });
}

// サブファイル(SFL)系の便利関数。桁位置は他と同じ(45桁目からのキーワード欄)で、
// 実体は keyword()/recordFormat() のラッパーにすぎない。SFLDSPCTL/SFLDSP/SFLCLR/
// SFLEND 等のON/OFFは呼び出し側が条件標識(ind)を渡して制御する。
// SFLレコード様式(明細行)。件数上限は呼び出し側の SFLCTL レコードの SFLSIZ で持つ。
export function sflRecordFormat(name) {
  return recordFormat(name);
}
// SFLCTL レコード様式。`sflName`: 対応する SFL レコード様式名。
export function sflCtlRecordFormat(name, sflName) {
  return recordFormat(name, `SFLCTL(${sflName})`);
}
export function sflSiz(n) {
  return keyword(`SFLSIZ(${n})`);
}
export function sflPag(n) {
  return keyword(`SFLPAG(${n})`);
}
// `ind`/`indRel`: SFLDSP/SFLDSPCTL/SFLCLR は状態遷移のたびにON/OFFする標識で
// 条件づけるのが通例(例: 初期表示はOFF、READC後にON)。
export function sflDsp(ind, indRel) {
  return keyword('SFLDSP', { ind, indRel });
}
export function sflDspCtl(ind, indRel) {
  return keyword('SFLDSPCTL', { ind, indRel });
}
export function sflClr(ind, indRel) {
  return keyword('SFLCLR', { ind, indRel });
}
export function sflEnd(kind = '') {
  // kind: '' (既定の +) | '*MORE' | '*SCRBAR' 等
  return keyword(kind ? `SFLEND(${kind})` : 'SFLEND');
}
export function sflNxtChg() {
  return keyword('SFLNXTCHG');
}
export function sflRcdNbr(kind = '*ALL') {
  // kind: '*ALL'(既定の絶対番号)| '*CURSOR' | '*NORCD'
  return keyword(`SFLRCDNBR(${kind})`);
}
// メッセージ・サブファイル。`sflPgmQ`: プログラム・メッセージ待ち行列名(DDS上の名前)。
export function sflMsgRcd(recName) {
  return keyword(`SFLMSGRCD(${recName})`);
}
export function sflPgmQ(name) {
  return keyword(`SFLPGMQ(${name})`);
}
export function errMsgId(msgId) {
  return keyword(`ERRMSGID('${msgId}')`);
}
