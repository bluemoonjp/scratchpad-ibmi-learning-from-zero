// DDS(表示装置ファイル)の行を正確な桁位置で生成する小さなジェネレーター。
// 物理・論理ファイル用の tools/gen/dds.mjs と基本の桁位置(6=A 17=名前種別
// 19-28=名前 30-34=長さ 35=データ型 36-37=小数桁 45-=キーワード)は共通。
// 表示装置ファイル特有の桁位置(38=使用法 I/O 39-41=行番号 42-44=桁位置)は
// 実機コンパイル(CRTDSPF、Highest Severity 00)で確認済み(04-11)。
// レコード様式レベルのキーワード(CF03(03) 等のファンクション・キー)は、
// R 行の直後に単独行として置く形で実機確認済み。
// 条件標識(フィールド・定数行を標識でON/OFFする書き方、桁7-16)は、**このリポ
// ジトリーで2回、異なる候補を試して2回とも実機で失敗が確定した**機能。使わない
// こと(下記putCondInd()自体は削除しないが、新しいレッスンでは呼び出さない)。
//   - 候補1(04-11、桁7に標識番号を直接置く形): CPD7410/CPD7606/CPD5238 で失敗。
//   - 候補2(このコード、桁7=関係(A/O)・桁8-16=標識3組×3桁「N(否定、任意)+
//     標識2桁」): 2026-09-26、verify/part05-gen-probe(T0SFL)の実機コンパイルで
//     失敗を確認。1回目の接続でSFLキーワード欠落等の他のバグを直した後、2回目の
//     接続でも依然として失敗し、しかも今回はCPD5238(候補1と同じメッセージ)
//     が新たに現れ、「Expanded Source」欄がCA03(03)以降を一切展開できていない
//     (=標識付きの行がファイル全体の構文解析を壊している)ことを確認した。
// **結論: この生成器の条件標識アプローチはPUB400で機能しない(2/2失敗、うち
// 1回はもう一方の候補と同じ致命的エラーに帰着)。三つ目の桁位置候補を試すより、
// 既に実機確認済みの代替を使うこと。**
// 04-11・第5部の旧システム設計(TK0100D/MN0000D)は、この条件標識には依存せず、
// 代わりにCHAINの結果標識をRPG側でMOVELして出力フィールドの内容を書き換える
// (04-03で確認済みの技法)方式で「見つからない」を表現する、確実な代替を
// 踏襲している。第6部のサブファイル・レッスン(06-11等)も同じ代替を使うこと。
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
// 2026-09-25 修正: 第5部の旧システム設計(TK0100D、tk0100d.dspf)で実際に使ってみた
// ところ、以下4関数に実装ミスが見つかった(IBM公式のDDSリファレンスと照合して確認)。
// 元の実装(コメントアウトのまま残す代わりに履歴として記載):
//   - sflRecordFormat(name): `R name` だけで、必須のレコード・レベルSFLキーワードが
//     無かった。
//   - sflPgmQ(name): `SFLPGMQ(name)` というレコード・レベル呼び出しを生成していたが、
//     実際のSFLPGMQはフィールド・レベルの裸キーワードで、丸括弧に入るのはフィールド名
//     ではなく任意のサイズ(10または276)。
//   - errMsgId(msgId): `ERRMSGID('msgId')` (引用符付き、メッセージ・ファイル省略)を
//     生成していたが、実際の構文は `ERRMSGID(msgid msgfile)`(msgidは引用符なし)。
//   - sflRcdNbr(kind='*ALL'): 既定値`*ALL`が無効な値(有効なのは`*CURSOR`/`*TOP`のみ)
//     で、かつフィールド・レベルのキーワード(専用の数値フィールドが要る)。
// SFLレコード様式(明細行)。件数上限は呼び出し側の SFLCTL レコードの SFLSIZ で持つ。
// 必須のレコード・レベル SFL キーワードを付ける(上の修正1)。
export function sflRecordFormat(name) {
  return recordFormat(name, 'SFL');
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
// SFLRCDNBR はフィールド・レベルのキーワード(専用の数値フィールドが要る)で、
// 有効な値は `*CURSOR`/`*TOP` のみ(`*ALL`は存在しない)。標準の keyword() 行では
// なく、field(..., kw) の kw に渡すテキストとして返す(修正4)。
// 例: field('RRN', 4, 'S', 0, '', '', '', sflRcdNbr('*TOP'))
export function sflRcdNbr(kind) {
  return `SFLRCDNBR(${kind})`;
}
// メッセージ・サブファイル。SFLMSGRCD(引数は行番号。レコード・レベルのキーワードで、
// このヘルパーの実装で問題なし)。
export function sflMsgRcd(lineNbr) {
  return keyword(`SFLMSGRCD(${lineNbr})`);
}
// SFLPGMQ はフィールド・レベルの裸キーワード(丸括弧に入るのはフィールド名ではなく
// 任意のサイズ 10 か 276)。field(..., kw) の kw に渡すテキストとして返す(修正2)。
// 例: field('PGMQ', '', '', '', '', '', '', sflPgmQ())
export function sflPgmQ(size) {
  return size ? `SFLPGMQ(${size})` : 'SFLPGMQ';
}
// ERRMSGID(msgid msgfile): msgid は引用符なし、メッセージ・ファイル名が必須
// (修正3)。フィールド・レベル/レコード・レベルどちらでも使えるが、ここではレコード・
// レベルのキーワード行として返す。フィールド・レベルで使う場合は呼び出し側で
// field(..., kw) の kw に `ERRMSGID(msgid msgfile)` の文字列を直接渡すこと。
export function errMsgId(msgId, msgFile) {
  return keyword(`ERRMSGID(${msgId} ${msgFile})`);
}
