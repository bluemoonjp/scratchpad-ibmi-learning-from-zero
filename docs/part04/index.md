# 第4部 RPG III を書く

> RPG III を学ばない人へ: 職場が `CRTBNDRPG` の固定形式 RPG IV の場合は、この部と第5部の代わりに[第4部V](../part04v/index.md)(04-21〜04-28)を通るルートがあります。`CRTRPGPGM` の職場は、この部を通ってください。

## この部の目標

RPG III(RPG/400)で、小さなプログラムを自分で書けるようになります。仕様書の桁位置、標識、ファイル入出力、帳票、画面、デバッグまでを扱います。

## 道具

5250(PDM/SEU、仕様書ごとの `F4` プロンプト)。

## 観測方法

`WRKSPLF`(帳票もコンパイル・リストも同じ場所に出ます)。画面は画面そのものを見ます。

## この部で扱わないこと

サブファイル・配列・データ構造を書くこと(読むのは第5部)、一致レコード。

## 同時接続数

5250×1(全レッスン共通)。

## レッスン一覧

- [04-01 RPG III の世界と最初の1本](04-01-first-program.md)
- [04-02 C 仕様書の桁と算術演算](04-02-c-spec-arithmetic.md)
- [04-03 文字の操作と定数](04-03-character-ops.md)
- [04-04 標識と比較](04-04-indicators-and-comp.md)
- [04-05 構造化命令とサブルーチン](04-05-structured-opcodes.md)
- [04-06 外部記述ファイルを順に読む](04-06-sequential-read.md)
- [04-07 キーで読む](04-07-chain.md)
- [04-08 帳票と受注照会の帳票版 JUCINQ3](04-08-jucinq3-report.md)
- [04-08b RPG III の CALL・PARM・PLIST を自分で書く](04-08b-call-parm-plist.md)(枝番レッスン。推奨ルートに入る。05-13 の前に済ませる)
- [04-09 更新・追加・削除とロック: 在庫引当 ZAHIK3](04-09-update-lock.md)
- [04-10 RPG サイクルと制御レベル](04-10-cycle-and-control-levels.md)
- [04-11 表示装置ファイルを手書きして照会画面を作る](04-11-display-file-inquiry.md)
- [04-12 デバッグと実行時エラー](04-12-debugging-runtime-errors.md)
- [04-13 チェックポイント: 商品別在庫一覧表](04-13-checkpoint-stock-list.md)
