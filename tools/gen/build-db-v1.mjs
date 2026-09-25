// サンプル DB(DBVER=1)の DDS ソースを生成する。
// 実行: node tools/gen/build-db-v1.mjs
import { record, field, key } from './dds.mjs';
import { writeFileSync, mkdirSync } from 'node:fs';

const RULER = "....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8";

function write(path, header, lines) {
  console.log(header); // 桁位置の目視確認用(ファイルには書き込まない)
  const body = lines.join('\n') + '\n';
  writeFileSync(path, body);
  console.log('wrote', path, `(${lines.length} lines)`);
}

mkdirSync('db/v1', { recursive: true });

// ---- TOKUIM: 得意先マスタ ----
write('db/v1/tokuim.pf', RULER, [
  record('TOKUIR', 'Customer master'),
  field('TOKCD', 6, 'A', '', ["TEXT('Customer code')"]),
  field('TOKNM', 30, 'A', '', ["TEXT('Customer name')"]),
  field('TOKZIP', 7, 'A', '', ["TEXT('Zip code')"]),
  field('TOKTAN', 6, 'A', '', ["TEXT('Sales rep code')"]),
  field('TOKUPD', 8, 'S', 0, ["TEXT('Updated date YYYYMMDD')"]),
  key('TOKCD'),
]);

// ---- SHOHIM: 商品マスタ ----
write('db/v1/shohim.pf', RULER, [
  record('SHOHIR', 'Product master'),
  field('SHOCD', 6, 'A', '', ["TEXT('Product code')"]),
  field('SHONM', 30, 'A', '', ["TEXT('Product name')"]),
  field('SHOTNK', 7, 'S', 2, ["TEXT('Unit price')"]),
  field('SHOHAT', 5, 'S', 0, ["TEXT('Reorder point')"]),
  key('SHOCD'),
]);

// ---- JUCHUM: 受注マスタ ----
write('db/v1/juchum.pf', RULER, [
  record('JUCHUR', 'Order master'),
  field('JUNO', 6, 'A', '', ["TEXT('Order number')"]),
  field('JUTOK', 6, 'A', '', ["TEXT('Customer code')"]),
  field('JUDATE', 8, 'S', 0, ["TEXT('Order date YYYYMMDD')"]),
  field('JUTAN', 6, 'A', '', ["TEXT('Sales rep code')"]),
  key('JUNO'),
]);

// ---- JUCHUD: 受注明細(様式名は JUCHUR と衝突しないよう JUCHDR) ----
write('db/v1/juchud.pf', RULER, [
  record('JUCHDR', 'Order detail'),
  field('JUNO', 6, 'A', '', ["TEXT('Order number')"]),
  field('JULINE', 3, 'S', 0, ["TEXT('Line number')"]),
  field('JUSHO', 6, 'A', '', ["TEXT('Product code')"]),
  field('JUSU', 5, 'S', 0, ["TEXT('Quantity')"]),
  field('JUTNK', 7, 'S', 2, ["TEXT('Unit price at order time')"]),
  key('JUNO'),
  key('JULINE'),
]);

// ---- ZAIKOM: 在庫マスタ ----
write('db/v1/zaikom.pf', RULER, [
  record('ZAIKOR', 'Stock master'),
  field('ZASHO', 6, 'A', '', ["TEXT('Product code')"]),
  field('ZASU', 7, 'S', 0, ["TEXT('Stock quantity')"]),
  field('ZAUPD', 8, 'S', 0, ["TEXT('Updated date YYYYMMDD')"]),
  key('ZASHO'),
]);

// ---- TANTOM: 担当者マスタ(他システム由来という設定。フィールド名はわざと6文字を超える) ----
write('db/v1/tantom.pf', RULER, [
  record('TANTOR', 'Sales rep master'),
  field('TANTOCODE', 6, 'A', '', ["TEXT('Sales rep code')"]),
  field('TANTONAME', 20, 'A', '', ["TEXT('Sales rep name')"]),
  key('TANTOCODE'),
]);

console.log('done');
