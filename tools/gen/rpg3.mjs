// RPG III(固定形式)の行を正確な桁位置で生成する小さなジェネレーター。
// 出典: RPG/400 Reference SC09-1817(研究時に一次資料で確認済みの桁位置)。
//
// H仕様書: 6=H
// F仕様書: 7-14 ファイル名 15 タイプ(I/O/U/C) 16 指定(P/S/R/T/F。WORKSTNの
//          組み合わせ(C)ファイルでEXFMTを使う場合はF指定が必須。空欄だと
//          QRG2096でコンパイル失敗。実機コンパイルで確認済み: 04-11) 17 EOF
//          18 順序 19 形式(F/E) 24-27 レコード長 28 限界処理 29-30 キー長
//          (外部記述ファイルでは指定不要・誤り。実機コンパイルで確認済み:
//          QRG2008) 31 レコード・アドレス型(外部記述のキー付きファイルを
//          キー順に読む場合はKを指定する。CHAINなどのランダム・アクセスだけ
//          でなく、READやプライマリー・ファイルの順次アクセスにも必要。
//          空欄だと(相対レコード番号扱いになりCHAINのFactor1が不正になる
//          ほか)キー付き論理ファイルでも到着順で読まれてしまう。実機
//          コンパイル・実行で確認済み: CHAIN無指定時QRG7055、READ/
//          プライマリー・ファイルは無指定でもコンパイルは通るが到着順に
//          なる、DSPFD TYPE(*ACCPTH)でアクセス・パス自体は正しいことを
//          確認したうえで判明) 32 編成 33-34 オーバーフロー標識
//          35-38 キー開始位置 40-46 装置
// C仕様書: ソース順の制約として、7-8桁目が空欄(明細時)のC仕様書行は、
//          非空欄(L1-L9、総合計時)の行より必ず前に書く必要がある。逆順で
//          書くとQRG5002(重大度10)でコンパイル失敗する。実行順序(総合計
//          時が明細時より先に実行される)とソース順は別物。実機コンパイルで
//          確認済み(04-10)。
//          6=C 7-8 制御レベル 9-17 条件標識(3桁×3組、各組「否定N+標識2桁」
//          の順。実機コンパイルで確認済み: 桁→否定の順で書くとQRG5006/5007)
//          18-27 Factor1 28-32 命令コード 33-42 Factor2(リテラルもこの
//          10桁に収まる長さまで) 43-48 結果 49-51 長さ 52 小数(数値の
//          結果フィールドを新規定義するときは両方明示しないと英数字型に
//          なる。実機コンパイルで確認済み: QRG7044) 53 拡張
//          54-59 結果標識(HI/LO/EQ、各2桁。READのEOF標識はEQに書く。
//          実機コンパイルで確認済み: HI/LOだとQRG5056/5134) 60-74 コメント
//          TAG: Factor1にラベル名。GOTO: Factor2にラベル名(実機確認済み、
//          BEGSR/EXSRと同じFactor1/Factor2の使い分け)
//          CHAIN: Factor1にキー値、Factor2にファイル名、結果標識はHI
//          (「見つからない」ときON。READのEQとは違う位置。実機コンパイル・
//          実行で確認済み)
//          UPDAT: 「UPDATE」は6文字で命令コード欄(5桁)に収まらないため、
//          実際の命令コードは5文字の「UPDAT」。Factor2にレコード形式名。
//          CHAIN/READで直前に読んだレコードが対象(実機コンパイル・実行で
//          確認済み)
// O仕様書: 7-14 ファイル/レコード名 15 タイプ(H/D/T/E) 23-31 出力標識
//          (C仕様書と同じ「否定+標識2桁」×3組のはずだが、こちらは
//          まだ実機未確認) 32-37 フィールド名/EXCPT名 38 編集コード
//          40-43 終了位置 45-70 定数
//          複数の名前付きEXCPTグループ: ファイルの最初のO仕様書行に
//          (ファイル名+タイプEと同時に)32-37桁目のEXCPT名を書いてよい。
//          省略すると「無名グループ」の宣言になり、対応する無名EXCPT
//          命令(Factor2省略)がC仕様書に無いとQRG6062でコンパイル失敗
//          する。2つ目以降の名前付きグループは、ファイル名を省略し
//          15桁目にEを再度書いた行を独立させ、32-37桁目に別のEXCPT名を
//          書く。実際のフィールド・定数はそれぞれの次の行(名前もタイプも
//          空欄)に書く。実機コンパイル・実行で確認済み(04-10)。
// I仕様書(外部記述ファイルの上書き専用。RPG/400 Reference 8章で確認):
//          6=I。レコード行(そのレコード様式の上書き開始を宣言): 7-14に
//          外部レコード様式名、他は空欄。フィールド行(制御レベル等を
//          有効にする): 7-20空欄、21-30は外部フィールド名を改名する
//          ときだけ指定、53-58にプログラムで使うフィールド名(改名しない
//          場合でも、制御レベル等を有効にするには必須。空欄のままだと
//          その行は何もしない)、59-60に制御レベル(L1-L9)、61-62に
//          一致標識(M1-M9)。列位置は実機コンパイルで確認済み(04-10)。
//          制御レベルが正しく働くには、ファイルの読み取り順がキー順に
//          なっている必要がある(F仕様書31桁目のK参照)。
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

// I-spec record line (externally described files): opens an override block
// for one external record format. `fmt`: external record format name.
export function iSpecRecord(fmt) {
  const l = blank(80).split('');
  put(l, 6, 'I');
  put(l, 7, fmt);
  return finish(l);
}

// I-spec field line (externally described files): activates control-level
// (`level`: 'L1'-'L9') and/or matching-field (`match`: 'M1'-'M9') for one
// field of the record format opened by the preceding iSpecRecord() line.
// `name` (cols 53-58) is required even when not renaming the field.
export function iSpecField({ extName = '', name, level = '', match = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'I');
  if (extName) put(l, 21, extName);
  put(l, 53, name);
  if (level) put(l, 59, level);
  if (match) put(l, 61, match);
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

// E-spec (compile-time array/table header; RPG/400 Reference chapter 6, positions
// 6/11-18/19-26/27-32/33-35/36-39/40-42/43/44/45). Positions 11-26 (from/to file
// name) are left blank here because this generator only targets compile-time
// arrays/tables (loaded at compile time, not from a prerun-time file).
// `name`: array/table name (27-32). `entriesPerRecord`: entries per compile-time
// data record (33-35, right-adjusted). `maxEntries`: total elements (36-39,
// right-adjusted). `length`: element length in bytes (40-42). `format`: ''
// (zoned/character) | 'P' (packed) | 'B' (binary). `decimals`: '' for a
// character array, else the number of decimal positions (44). `sequence`: ''
// (unsequenced) | 'A' | 'D' (required if the array is searched with a
// high/low LOKUP or sorted with SORTA).
export function eSpec({ name, entriesPerRecord, maxEntries, length, format = '', decimals = '', sequence = '' }) {
  const l = blank(80).split('');
  put(l, 6, 'E');
  put(l, 27, name);
  put(l, 33, String(entriesPerRecord).padStart(3, ' '));
  put(l, 36, String(maxEntries).padStart(4, ' '));
  put(l, 40, String(length).padStart(3, ' '));
  if (format) put(l, 43, format);
  if (decimals !== '') put(l, 44, String(decimals));
  if (sequence) put(l, 45, sequence);
  return finish(l);
}

// Compile-time array/table data records (RPG/400 Reference, "Loading a
// Compile-Time Array"): a record with `**` in positions 1-3 must precede the
// first data record of each array, then each entry is written left-adjusted
// at a fixed `length`, `entriesPerRecord` entries per line, starting at
// position 1 (not through the normal spec-form column layout, so these lines
// do NOT start with a form-type letter in column 6). `entries` are already
// formatted to `length` characters by the caller (e.g. zero-padded numeric
// literals, or character strings) so this function does not right/left-pad
// them itself - only groups them into records and adds the `**` header.
export function compileTimeArrayData(entries, { entriesPerRecord, length }) {
  for (const e of entries) {
    if (e.length !== length) {
      throw new Error(`compile-time array entry length mismatch: expected ${length}, got ${e.length} ("${e}")`);
    }
  }
  const lines = ['**'];
  for (let i = 0; i < entries.length; i += entriesPerRecord) {
    lines.push(entries.slice(i, i + entriesPerRecord).join(''));
  }
  return lines;
}

// I-spec data-structure header (RPG/400 Reference chapter 8, "Data Structure
// Specification Entries"). Must be followed immediately by iSpecSubfield()
// lines for its subfields, and data-structure specifications as a whole must
// come after all record-level I-specs in the source.
// `name`: DS name, up to 6 chars (7-12; optional, blank = unnamed/global DS).
// `option`: '' | 'I' (initialize all subfields on program start) | 'S'
// (program status DS) | 'U' (data area DS) (18). `occurrences`: '' or 1-9999
// for a multiple-occurrence DS (44-47, right-adjusted). `length`: '' (derived
// from the highest subfield `to` position) or an explicit length (48-51,
// right-adjusted).
export function iSpecDS({ name = '', option = '', occurrences = '', length = '' } = {}) {
  const l = blank(80).split('');
  put(l, 6, 'I');
  if (name) put(l, 7, name);
  if (option) put(l, 18, option);
  put(l, 19, 'DS');
  if (occurrences !== '') put(l, 44, String(occurrences).padStart(4, ' '));
  if (length !== '') put(l, 48, String(length).padStart(4, ' '));
  return finish(l);
}

// I-spec data-structure subfield line (RPG/400 Reference, "Data Structure
// Subfield Specifications"). One line per subfield, immediately after the
// iSpecDS() header (or the previous subfield of the same DS).
// `init`: '' | 'I' with `initValue` set (8, 21-42) to initialize the subfield
// to a literal/named constant. `format`: '' (zoned/character) | 'P' (packed)
// | 'B' (binary) (43). `from`/`to`: subfield position within the DS,
// right-adjusted, leading zeros optional (44-47/48-51). `decimals`: '' for a
// character subfield, else decimal positions (52). `name`: subfield name,
// required (53-58).
export function iSpecSubfield({ init = '', initValue = '', format = '', from, to, decimals = '', name }) {
  const l = blank(80).split('');
  put(l, 6, 'I');
  if (init) {
    put(l, 8, init);
    if (initValue) put(l, 21, initValue);
  }
  if (format) put(l, 43, format);
  put(l, 44, String(from).padStart(4, ' '));
  put(l, 48, String(to).padStart(4, ' '));
  if (decimals !== '') put(l, 52, String(decimals));
  put(l, 53, name);
  return finish(l);
}
