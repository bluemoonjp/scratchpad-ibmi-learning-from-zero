// DDS(物理ファイル)の行を正確な桁位置で生成する小さなジェネレーター。
// 桁位置: 6=A(固定) 7=コメント(*) 17=名前種別(R/K/空) 19-28=名前(10桁)
//         30-34=長さ(5桁, 右詰め) 35=データ型(1桁) 36-37=小数桁(2桁)
//         45-=キーワード
function pad(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length); }
function padRight(s, n) { s = String(s); return s.length >= n ? s.slice(0, n) : ' '.repeat(n - s.length) + s; }

function line({ nameType = '', name = '', length = '', type = '', dec = '', kw = '', comment = false } = {}) {
  let l = ' '.repeat(80).split('');
  const put = (col1, text) => { // col1: 1-indexed start
    for (let i = 0; i < text.length; i++) l[col1 - 1 + i] = text[i];
  };
  put(6, 'A');
  if (comment) put(7, '*');
  if (nameType) put(17, nameType);
  if (name) put(19, pad(name, 10));
  if (length !== '') put(30, padRight(String(length), 5));
  if (type) put(35, type);
  if (dec !== '') put(36, padRight(String(dec), 2));
  if (kw) put(45, kw);
  const out = l.join('').replace(/\s+$/, '');
  if (out.length > 80) {
    throw new Error(`DDS line exceeds 80 columns (${out.length}): ${out}`);
  }
  return out;
}

export function record(name, text) {
  return line({ nameType: 'R', name, kw: text ? `TEXT('${text}')` : '' });
}
export function field(name, length, type, dec, kwList) {
  const kw = Array.isArray(kwList) ? kwList[0] || '' : (kwList || '');
  const rest = Array.isArray(kwList) ? kwList.slice(1) : [];
  const lines = [line({ name, length, type, dec: type === 'S' || type === 'P' ? dec : '', kw })];
  for (const k of rest) lines.push(line({ kw: k }));
  return lines.join('\n');
}
export function key(name, extra) {
  return line({ nameType: 'K', name, kw: extra || '' });
}
export function comment(text) {
  return line({ comment: true, kw: text }); // NOTE: comment text placed from col45 for simplicity; real comments can start col8
}
export function unique() {
  return line({ nameType: '', kw: 'UNIQUE' });
}
