// 実行結果(ジョブログ・SQL出力等)から実名・ライブラリー名を <USER> に置き換える。
// 教材や work/verify/results/ に書く前に必ずこれを通す。

export function anonymize(text, cfg) {
  if (!text) return text;
  const user = cfg.user.toUpperCase();
  let out = text;
  // 長い形(ライブラリー接頭辞)から先に置換しないと、短い形の置換で壊れる。
  out = out.replaceAll(new RegExp(`${user}1`, 'gi'), '<USER>1');
  out = out.replaceAll(new RegExp(`${user}2`, 'gi'), '<USER>2');
  out = out.replaceAll(new RegExp(`${user}B`, 'gi'), '<USER>B');
  out = out.replaceAll(new RegExp(user, 'gi'), '<USER>');
  return out;
}
