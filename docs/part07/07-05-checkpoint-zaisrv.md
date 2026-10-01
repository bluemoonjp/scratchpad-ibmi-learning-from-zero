# 07-05 チェックポイント: 在庫サービスZAISRV

> 所要時間: 120分(長め)/ 前提レッスン: 07-04(TXCKM・TXCHECK は 05-13。RPG III を通らないルートでは 04-27) / 目標番号: 5 / 観測方法: `WRKSPLF`(印字結果)・`DSPSRVPGM` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・確認)、SQL(`STRSQL`、`TXCKM`登録)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/ZAISRV`(*MODULE→*SRVPGM)・`<USER>1/ZAISRVBD`(*BNDDIR)・`<USER>1/DRIVER`(プログラム)。演習は共有テーブル`ZAIKOM`の中身も書き換える(要`TXRESET`)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

<details><summary>RPG III を通らないルートの人へ</summary>

`TXCKM`・`TXCHECK` は、05-13 ではなく [04-27](../part04v/04-27-route-preparation.md) の手順 A1 で作ってあります。本文の `R0409A`(04-09)は [04-23](../part04v/04-23-external-files.md) の `V0423D`、04-13 は [04-25](../part04v/04-25-cycle-and-control-levels.md) の `V0425D` に読み替えてください。`V0423D` も `ZAIKOM` を書き換えるので、片付けの `TXRESET` は、ルートでも必要です。

</details>

## ゴール

- `F0608A`(06-08、ZAHIK4)の在庫引当ロジックを土台に、`get`・`reserve`・`release`という3手続きを持つサービス・プログラム`ZAISRV`を設計し、`CRTRPGMOD`→`CRTSRVPGM`(バインダー・ソース経由の`EXPORT(*SRCFILE)`)で公開できる。
- `*SRVPGM`化がファイル・ロックの寿命をどう変えるかを説明し、`F0608A`には無かったロック解放を`reserve`に、実際にロックを取った1分岐だけへ過不足なく追加できる。
- `TXCHECK`(`*CMD`形)でこのチェックポイントの完了を機械的に確認し、共有`ZAIKOM`テーブルを`TXRESET`で必ず元に戻せる。

## ウォームアップ

<details><summary>前回の復習(07-04)</summary>

1. 名前付き活動化グループ(`ACTGRP(名前)`)で`CALL`を2回連続実行すると、モジュール内の静的変数(カウンター)の値はどうなりますか? 間に`RCLACTGRP`を挟むとどうなりますか?
2. CLLEから`*SRVPGM`の手続きを呼ぶとき、結合先のサービス・プログラムを指定するのは`CRTBNDCL`のどのパラメーターですか?

答え: 1. 名前付き活動化グループは`CALL`をまたいで存続するため、カウンターは1回目が1・2・3、2回目(`RCLACTGRP`なし)は続きの4・5・6になります。`RCLACTGRP`で活動化グループ自体を削除すると、次の`CALL`は再び1・2・3から始まります。 2. **`CRTBNDCL`コマンド自身にではなく**、CLソースの中に書く宣言コマンド`DCLPRCOPT DFTACTGRP(*NO) BNDSRVPGM(*LIBL/JUCSRV)`で指定します(`PGM`より後・他の実行コマンドより前に置く必要がありますが、`PGM`の直後である必要はなく、`JUYAKL`はそこに置くことを単なる選択としています)。

</details>

## なぜ学ぶか

**このレッスンは第7部のチェックポイントです。** 07-01(モジュール)・07-02(サービス・プログラムとバインディング・ディレクトリー)・07-03(バインダー・ソースと署名)・07-04(活動化グループとILE CL)で学んだ技法を、実際の業務ロジック1つに対してひととおり組み合わせます。**新しい構文は登場しません。** ここまでの技法だけで、実際に価値のあるものを設計・公開できることを確認するのがこのレッスンの狙いです。

題材は06-08の`F0608A`(ZAHIK4)です。`F0608A`は「在庫を`CHAIN`で読み、数量が足りているか確かめ、足りていれば`UPDATE`で引き当てる」という1本のプログラムでした。この引当ロジックが、複数のプログラム(画面・バッチ・将来の第8部の仕組み)から呼ばれる**共有サービス**になったらどうなるか——それがこのチェックポイントの題材です。`get`(在庫の覗き見)・`reserve`(引当)は`F0608A`のロジックをほぼそのまま`*SRVPGM`の手続きへ再配置したものですが、**`release`(在庫を戻す)は`F0608A`には無い、正真正銘の新規ロジックです**(`F0608A`は在庫を減らすことしかしません)。

さらに、`F0608A`を単純に移植しただけでは見落とす、**`*SRVPGM`ならではの不具合**が1つ見つかります。`F0608A`の内側の`CHAIN`(ロックあり)は、在庫不足(SHORT)と分かった直後、レコードをロックしたまま何も書き込まずに終わっていました。`F0608A`自身は`*PGM`なので、この不具合は実害がありませんでした(理由は下の「説明」で詳しく扱います)。ところが同じロジックを`*SRVPGM`へ移すと、**このロックが呼び出し元の活動化グループの寿命いっぱい残ってしまう可能性があります。** `reserve`は、この1点だけに的を絞った修正を加えます。

## 新出

**新しい構文はありません。** `get`・`reserve`は、`F0608A`が既に使っている`likerec`・`%kds`・`chain(n)`・`CHAIN`・`UPDATE`をそのまま流用します。`release`は`F0608A`には無い新規ロジックですが、`reserve`と対称な形(在庫を減らす代わりに増やす)で組み立てるだけで、新しいBIFやキーワードは使いません。`ZAISRV`自身のソースで**初めて実際に書く**のは`UNLOCK`ですが、技法自体は06-11bの`f0611bs.rpgle`が既に3回呼んでいる再利用です。バインダー・ソース(`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`)も07-03で導入済みの技法をそのまま使います。

## 説明

### `ZAISRV`の3手続きと`F0608A`との対応

| `F0608A`(06-08、ZAHIK4) | `ZAISRV`(本レッスン) |
|---|---|
| 外側の`chain(n)`(ロックなし)による在庫の覗き見 | `get(prodCode)`(在庫数を返す。見つからなければ`-1`) |
| 内側の`CHAIN`(ロックあり)→在庫再チェック→`UPDATE` | `reserve(prodCode : qty)`(引当成功で`*on`、SHORT/NOTFOUNDで`*off`) |
| (`F0608A`には無い) | `release(prodCode : qty)`(在庫を戻す。新規ロジック) |

`ZAIKOM`(`db/v1/zaikom.pf`)のフィールドは`F0608A`と同じです: `ZASHO`(商品コード、6A、キー)・`ZASU`(在庫数、7S 0)・`ZAUPD`(更新日、8S 0)。

### `get`: ロックなしの覗き見

```rpgle
zaikomKey.zasho = prodCode;
clear zaikomRec;
chain(n) %kds(zaikomKey) zaikor zaikomRec;

if %found(zaikom);
  return zaikomRec.zasu;
else;
  return -1;
endif;
```

`F0608A`の外側の`chain(n)`(操作拡張子`N`、ロックを取らない`CHAIN`)をそのまま手続き化しただけです。`get`は数量を受け取らないため、`NOTFOUND`か否かしか判定できません(`SHORT`かどうかは`reserve`側でしか分かりません)。戻り値`-1`は、`get`の戻り値が`packed(7:0)`(在庫が実際に`0`という値も取り得る)である以上、安全な番人として選ばれた値です。

### `reserve`: 本当のロック付き引当と、その1点だけの修正

```rpgle
chain %kds(zaikomKey : 1) zaikor zaikomRec;
if not %found(zaikom);
  // ロック付きCHAINが見つからず失敗 -> ロックは取られていない。
  ok = *off;
elseif zaikomRec.zasu < qty;
  // 見つかり、ロックも取ったが、在庫不足(SHORT)。
  unlock zaikom;
  ok = *off;
else;
  zaikomRec.zasu -= qty;
  update zaikor zaikomRec;   // UPDATEが自動的にロックを解放する。
  ok = *on;
endif;
```

`F0608A`の内側の`CHAIN`(ロックあり)→再チェック→`UPDATE`を、そのまま手続きへ移しています。**追加したのは`unlock zaikom;`の1行だけです。**

**なぜこの1行が必要になったのか。** `F0608A`は`dftactgrp(*no) actgrp(*new)`の`*PGM`です。`*inlr = *on`によるサイクル終了時、(a)`F0608A`自身が開いたファイルは通常の終了処理として閉じられ、かつ(b)`F0608A`はこの活動化グループの最も古い呼び出しスタック項目であるため、システム命名の活動化グループ自体も削除されます(一次資料(ILE Concepts)によれば、`ACTGRP(*NEW)`で作られたシステム命名の活動化グループは、その活動化グループの最も古い呼び出しスタック項目が正常にリターンした時点で削除されます)。どちらの仕組みだけでも、SHORT分岐で取ったロックは`F0608A`の終了と同時に解放されるため、実害がありませんでした。

`ZAISRV`は`nomain`モジュールでRPGサイクル自体を持たず、`*inlr`に到達する場面がありません。しかも`CRTSRVPGM`は`ACTGRP(*CALLER)`で作成するため(下の「ビルド手順」参照)、`ZAISRV`自身は独自の活動化グループを持たず、呼び出し元が今動いている活動化グループにそのまま活動化されます。つまり`ZAISRV`が開いた`ZAIKOM`も、そこで取ったロックも、**呼び出し元の活動化グループのインスタンスが生きている間、あるいは`ZAIKOM`への次の入出力があるまでのどちらか早い方まで残ります**(`f0611bs.rpgle`のヘッダーが述べる「held until this program ends or the row is read again」と同じ理由です。同じ開いた`ZAIKOM`インスタンスを共有する`get`・`reserve`・`release`のどれかが次にこの行を読み書きすれば、それだけでロックが解放・置き換えされ得ます——下の「診断の限界」がこの点に頼っています)。活動化グループのインスタンスがどれだけ長く生きるかは呼び出し元次第です(一次資料(ILE Concepts)によれば): 呼び出し元が`ACTGRP(*NEW)`(`F0608A`自身の流儀、および本レッスンの`DRIVER`自身の流儀)なら、呼び出し元が正常リターンした瞬間に活動化グループが削除されます。呼び出し元が名前付き`ACTGRP(名前)`なら、明示的な`RCLACTGRP`かジョブ終了まで活動化グループはジョブの中に残り続けます。**`F0608A`では実害がなかった「取ったのに離さないロック」が、`*SRVPGM`化すると呼び出し元の設計次第でずっと長く残ってしまう可能性がある——これが本チェックポイントの核心の修正理由です。**

**修正の範囲は、実際にロックを取った1分岐だけです。** `reserve`には3つの分岐がありますが、ロックを取るのは**「見つかり、かつ在庫不足」の分岐だけ**です。

- `not %found`(NOTFOUND)の分岐: 失敗した`CHAIN`はそもそも何もロックしません。解放するものが無いので、`UNLOCK`は不要です。
- `zaikomRec.zasu < qty`(SHORT)の分岐: ロック付き`CHAIN`が成功しているので、確実にロックを持っています。ここに`UNLOCK`を追加します。
- `else`(OK)の分岐: `UPDATE`自体が、取っていたロックを消費・解放します(06-11bの`f0611bs.rpgle`が繰り返し確認している規則です)。

これは「SHORT/NOTFOUND分岐全般」を対象にした修正ではありません。**ロックしていない状態で`UNLOCK`を呼んでも無害かどうかは一次資料でも確認できていない**ため、`ZAISRV`は確実にロックを持っている分岐だけを狙って`UNLOCK`を呼ぶ設計にしてあります。

### `release`: 新規ロジック、しかし既出の技法だけ

```rpgle
chain %kds(zaikomKey : 1) zaikor zaikomRec;
if not %found(zaikom);
  ok = *off;
else;
  zaikomRec.zasu += qty;
  update zaikor zaikomRec;
  ok = *on;
endif;
```

`F0608A`には対応するロジックがありません。`reserve`と**対称な形**(`-=`の代わりに`+=`)で組み立てただけで、`likerec`・`%kds`・`CHAIN`・`%found`・`UPDATE`という、ここまでに既に使った技法しか登場しません。`release`には`UNLOCK`が1回も出てきません。分岐が2つしかなく(NOTFOUND=ロックなし、成功=`UPDATE`が自動解放)、「見つかってロックは取ったが書き込まずに終わる」という分岐自体が存在しないためです。

**既知の制限(このチェックポイントでは扱いません)**: `ZASU`は`7S 0`(最大`9999999`)、`reserve`・`release`の`qty`も`packed(7:0)`(同じく最大`9999999`)です。`reserve`のSHORT判定は在庫がマイナスになる方向の暴走を防ぎますが、`release`の`zaikomRec.zasu += qty`には対称な上限チェックがありません。`F0608A`は減らすことしかしないため、この問題を持ちませんでした。実際に問題になるほど大きな`qty`で`release`を呼ぶ設計は、このチェックポイントの範囲外です。

### バインダー・ソース: 07-03の技法をそのまま適用する

`ZAISRV`は初めての公開なので、`PGMLVL(*CURRENT)`ブロックが1つあるだけです(07-03で扱った「既存クライアントを壊さず手続きを追加する」`PGMLVL(*PRV)`のブロックは、まだ必要ありません)。

```text
STRPGMEXP PGMLVL(*CURRENT)
   EXPORT SYMBOL('GET')
   EXPORT SYMBOL('RESERVE')
   EXPORT SYMBOL('RELEASE')
ENDPGMEXP
```

`get`・`reserve`・`release`のどれにも`EXTPROC`/`EXTPGM`を指定していないため、07-02で確認した既定のルール(プロトタイプ名を大文字化したものがエクスポート名になる)により、実際のエクスポート・シンボルは`GET`・`RESERVE`・`RELEASE`(大文字)になります。下の「実機メモ」のとおり、`DRIVER`が実際にこの綴りの`EXTPROC`で束縛・実行に成功していることが、この大文字化ルールの裏付けです。

### ビルド手順: `CRTRPGMOD`→`CRTSRVPGM`→`*BNDDIR`→`DRIVER`

`*SRVPGM`は`CRTBNDRPG`では作れません(一次資料(CLコマンド・リファレンス)の`CRTBNDRPG`パラメーター一覧に、`*SRVPGM`を出力する項目自体がありません)。07-02と同じ2段階(`CRTRPGMOD`→`CRTSRVPGM`)で作ります。実際のコマンドは下の「実演」節の手順3にまとめてあります。

`ACTGRP(*CALLER)`は明示的に書きます(一次資料(CLコマンド・リファレンス)の`CRTSRVPGM`の説明によれば、「このサービス・プログラムが呼び出されると、呼び出し元の活動化グループに活動化される」という指定です)。上で述べたロックの寿命の議論は、この指定を前提にしています。

続いてバインディング・ディレクトリーです。**`ZAISRVBD`は07-02の`JUCSRVBD`とは別の、新規のバインディング・ディレクトリーです**(`JUCSRVBD`は`JUCSRV`という別のサービス・プログラムを指すため、`ZAISRV`を登録するには使えません)。コマンドは「実演」節の手順4にあります。

最後に、テスト・ドライバー`DRIVER`です。コマンドは「実演」節の手順5にあります。

### `DRIVER`はなぜ1回の`CALL`の中だけでロック持ち越しを試すのか

`DRIVER`自身は`dftactgrp(*no) actgrp(*new)`という、`F0608A`と同じ流儀のシステム命名の活動化グループです。一次資料(ILE Concepts)によれば、`ACTGRP(*NEW)`は`DRIVER`が正常リターンした瞬間に削除されます。つまり**別々の2回の`CALL PGM(DRIVER)`は、それぞれ独立した新しい活動化グループを得るため、1回目の`CALL`で起きたことは2回目の`CALL`には一切引き継がれません。** ロックの持ち越しを確かめたいなら、**同じ1回の実行の中で`reserve`を2回連続呼ぶ**しかありません(07-03の`countCustOrders`の2回連続呼び出し検証と同じ注意点です)。`DRIVER`のソース自身がこの設計になっており、`reserve`→`reserve`→`get`という並びを1回の`CALL`の中に収めています。

### `DRIVER`の10行のロック・テスト

`DRIVER`を実行すると、次の10行が印字されます(実機で確認済みの実際の値、下の「実機メモ」参照)。

```text
0-BASELINE       P00001 QTY=0        OK= Y ZASU=45       get() peek
1-RESERVE-OK     P00001 QTY=2        OK= Y ZASU=43       expect ON, -qty
2-RESERVE-SHORT  P00001 QTY=9999999  OK= N ZASU=43       expect OFF, same
2B-DIAG-CHAIN    P00001 QTY=0        OK= Y ZASU=0        NO CONFLICT SEEN
3-RELEASE        P00001 QTY=2        OK= Y ZASU=45       expect ON, =start
4-TWICE-A        P00001 QTY=2        OK= Y ZASU=41       expect ON
4-TWICE-B        P00001 QTY=2        OK= Y ZASU=41       expect ON, -2*qty
5-RESTORE        P00001 QTY=2        OK= Y ZASU=45       expect =start
6-NOTFOUND-GET   P99999 QTY=0        OK= Y ZASU=-1       expect -1
7-NOTFOUND-RSV   P99999 QTY=2        OK= N ZASU=0        expect OFF
```

各列は、左から順に「手順名」「対象の商品コード」「`reserve`/`release`に渡した数量」「戻り値(`Y`=`*on`/`N`=`*off`)」「`ZASU`欄(下の注記参照)」「期待値のメモ」です。

- **`0`〜`1`〜`3`〜`5`行**: `get`による在庫の覗き見です。`45`(開始)→`43`(2個引当)→`45`(2個返却)→`45`(2回引当・2回返却で往復)と、素直に増減しています。
- **`2-RESERVE-SHORT`行**: `qty=9999999`(`packed(7:0)`の最大値)を渡し、確実にSHORTになる引当を試しています。戻り値は`N`(`*off`)、在庫は`43`のまま変わっていません(`F0608A`のSHORT結論と同じです)。
- **`2B-DIAG-CHAIN`行に注意してください。この行の`ZASU=`欄は、実際の在庫数ではありません。** `DRIVER`自身が持つ、`ZAISRV`とは別の独立したオープン・インスタンスから、SHORT引当の直後に同じ行へロック付き`CHAIN`を試みた診断です。この`ZASU=`欄は`%STATUS`相当の診断コードを表示する欄ですが、**今回のNO CONFLICT SEENの行は、実際には`%STATUS`を呼ばずリテラル`0`を代入したものです。** `%STATUS(zaikom)`を実際に呼ぶのは、この診断用`CHAIN`が(モニターの対象になるような)エラーを起こした別の分岐だけで、今回の確認済み実行ではその分岐を通っていません(在庫の実際の値は直前の`2-RESERVE-SHORT`行が示す`43`のままです)。下の「診断の限界」を必ず読んでください。
- **`4-TWICE-A`・`4-TWICE-B`行が同じ`ZASU=41`を表示しているのはバグではありません。** `DRIVER`のソースは、2回連続の`reserve`呼び出し(A側・B側)を**両方とも先に実行してから**、まとめて1回だけ`get`で在庫を読み直し、その同じ値を両方の行の印字に使っています(1回目の直後の値、たとえば`43`のはずの値は、この2行のどちらにも現れません)。
- **`6-NOTFOUND-GET`行の`ZASU=-1`**は、`get`の番人値です(存在しない商品コード`P99999`)。
- **`7-NOTFOUND-RSV`行の`ZASU=0`**は、実際の在庫値でも`%STATUS`でもありません。`reserve`は数量を返す手続きではないため、この欄には`DRIVER`側が表示用にただ固定値`0`を埋めているだけです(`get`の番人値`-1`とは別物で、比べる意味のある値ではありません)。

### 診断の限界 ー 正直に書くべきこと

`2B-DIAG-CHAIN`行の`NO CONFLICT SEEN`は、**「ロック解放の修正が実際に効いている」ことの証明ではありません。** この診断には**対照実験がありません**——`UNLOCK`を削った版の`ZAISRV`を同じ手順で実行し、そちらでは実際に競合(ロック中エラー)が現れる、という比較を行っていないため、「修正がある場合とない場合で結果が変わる」ことをこの1回のテストだけでは示せていません。示せているのは「修正を入れた版が、エラーを起こさずに走る」ことだけです。

さらに、この診断自体にも2つの弱点があります。

1. **同じ作業単位の中で、別のオープン・インスタンスからのロック付き`CHAIN`が、実際に競合として現れるのか、それとも黙って通ってしまうのか、一次資料でも確認できていません。** つまり`UNLOCK`が無かったとしても、`NO CONFLICT SEEN`という同じ結果になった可能性を、このテストだけでは排除できません。
2. **`4-TWICE-A`/`4-TWICE-B`(reserveを2回連続呼ぶテスト)も、単独では弱いテストです。** 同じオープン・データ・パスに対する2回目の`CHAIN`は、たとえ1回目のロックが残っていたとしても、それを読み直すだけで静かに置き換えてしまう可能性があります。この2行が示せているのは「2回連続で呼んでもハングやエラーが起きない」ことだけで、「1回目のロックが本当に解放されていた」ことの証明ではありません。

**このチェックポイントの範囲では、これ以上の区別を機械的に行う手段がありません。** 本当に区別力のある確認は、06-11bの演習5と同じ形(別の5250/SSHセッションから`WRKOBJLCK OBJ(<自分のユーザー名>1/ZAIKOM) OBJTYPE(*FILE)`でロックの様子を外から観察する)で、下の演習(発展)に回しています。この確認はV3(対話操作)専用で、このリポジトリーではまだ誰も試していません。

## 実演

**この実演で作る3つのオブジェクト(`ZAISRV`・`ZAISRVBD`・`DRIVER`)は、実機コンパイル・実行(V1/V2、下の「実機メモ」参照)まで確認済みです。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込みます(1回の接続でまとめて行います)。`<自分のユーザー名>1/QSRVSRC`は07-03で作成済みのはずです。まだ無ければ`CRTSRCPF FILE(<自分のユーザー名>1/QSRVSRC) RCDLEN(112) TEXT('Binder source')`で作成してから進めてください。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/07-05/zaisrv.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/ZAISRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/07-05/zaisrv.bnd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QSRVSRC.FILE/ZAISRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/07-05/driver.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/DRIVER.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`ZAISRV`をコンパイルします。

   ```text
   CRTRPGMOD MODULE(<自分のユーザー名>1/ZAISRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(ZAISRV)
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/ZAISRV) MODULE(<自分のユーザー名>1/ZAISRV) EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(ZAISRV) ACTGRP(*CALLER)
   ```

   `CRTRPGMOD`はHighest Severity 10で成功するはずです(`RNF7534`: 非サイクル・モジュールでは`ZAIKOM`を明示的にクローズすべき、という助言。警告のみで作成自体は成功します)。

4. バインディング・ディレクトリーを作ります(`ZAISRVBD`はこの課で初めて作るので、存在確認は不要です)。

   ```text
   CRTBNDDIR BNDDIR(<自分のユーザー名>1/ZAISRVBD)
   ADDBNDDIRE BNDDIR(<自分のユーザー名>1/ZAISRVBD) OBJ((*LIBL/ZAISRV *SRVPGM))
   ```

5. `DRIVER`をコンパイルします。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/DRIVER) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(DRIVER) DFTACTGRP(*NO) ACTGRP(*NEW) BNDDIR((*LIBL/ZAISRVBD))
   ```

   Highest Severity 00になることを確認してください。

6. **実行の前に、`<自分のユーザー名>1/TXRESET`を実行しておくことを勧めます。** `DRIVER`自身の`0-BASELINE`行は`get`でその時点の在庫を読むだけなので、`TXRESET`をしなくても動きますが、先に実行しておくと、上の「説明」で示した実際の数値(`45`→`43`→…)とそのまま一致し、照合しやすくなります。

   ```text
   <自分のユーザー名>1/TXRESET
   CALL PGM(<自分のユーザー名>1/DRIVER)
   ```

   `WRKSPLF`で、上の「説明」節に示した10行が印字されていることを確認してください。

7. `DSPSRVPGM SRVPGM(<自分のユーザー名>1/ZAISRV)`を実行し、エクスポートされている手続きの一覧に`GET`・`RESERVE`・`RELEASE`(いずれも大文字)が出ることを確認してください。

8. `TXCKM`にこのレッスンの行を登録します。`TXCKM`・`TXCHECK`(および`*CMD`)は05-13(RPG III を通らないルートでは 04-27)で既にコンパイル済みのはずです(まだの場合は05-13または04-27の手順に従ってください)。二重登録を避けるため、まず同じ`LESSON`の行を消してから入れ直します。

   ```sql
   DELETE FROM <自分のユーザー名>1/TXCKM WHERE LESSON = '07-05';

   INSERT INTO <自分のユーザー名>1/TXCKM
     (LESSON, SEQNBR, OBJNAME, OBJTYPE, OBJATTR, CKDESC)
   VALUES
     ('07-05', 1, 'ZAISRV',   '*SRVPGM', ' ', 'ZAISRV service program exists'),
     ('07-05', 2, 'ZAISRVBD', '*BNDDIR', ' ', 'ZAISRVBD binding directory exists'),
     ('07-05', 3, 'DRIVER',   '*PGM',    ' ', 'DRIVER checkpoint program exists');
   ```

9. `*CMD`経由で実行します(`CALL PGM(...) PARM(...)`ではありません。[付録E](../appendix/e-naming.md)が説明する32バイト・リテラルの罠を避けるためです)。**`TXCHECK`はオブジェクトの実在・型しか確認しません**(`get`/`reserve`/`release`のロジックが正しいかどうかは、上の手順6で確認した10行のほうが本体です)。

   ```text
   TXCHECK LESSON('07-05') LIB(<自分のユーザー名>1)
   ```

   ジョブ・ログに`TXCHECK PASS: ...`が3件と、`TXCHECK: lesson 07-05 - ... passed,`/`... failed.`という要約(2行に分かれて出ます)が出れば、3つのオブジェクトすべてが存在し、正しい型でコンパイルされていることが機械的に確認できたことになります。

## 演習

1. `WRKSPLF`で10行を確認したら、`STRSQL`で`SELECT ZASU FROM <自分のユーザー名>1/ZAIKOM WHERE ZASHO='P00001'`を実行し、`5-RESTORE`行が示した値(`TXRESET`直後の開始値と同じ)と一致していることを確認してください。

2. `2-RESERVE-SHORT`行(`qty=9999999`)が`F0608A`の`SHORT`結論と同じであることを、06-08自身の実機メモの値と見比べて確認してください。

3. (発展・コントロール実験、未確認)`reserve`の`unlock zaikom;`の行を一時的にコメントアウトし、`CRTRPGMOD`→`CRTSRVPGM`(`REPLACE(*YES)`)で`ZAISRV`を作り直し、`DRIVER`を再実行してください。`2B-DIAG-CHAIN`行の結果が変わるかどうか(`NO CONFLICT SEEN`のままか、別の結果になるか)は、**一次資料でも確認できておらず、このリポジトリーでもまだ試されていません。** 実際に試して、その結果を記録してください。試し終えたら、**必ず`unlock zaikom;`の行を元に戻し、`ZAISRV`を再度作り直しておいてください**(この演習は共有の模範解答オブジェクト自体を書き換えるため、元に戻し忘れると他の演習・レッスンに影響します)。この演習で`DRIVER`を再実行した場合は、`<自分のユーザー名>1/TXRESET`で`ZAIKOM`を元に戻すことも忘れないでください。

4. (発展・V3、このリポジトリーではまだ誰も試していません)06-11bの演習5と同じ形です。可能なら別の5250/SSHセッションを開き、片方で`2-RESERVE-SHORT`相当の状況(在庫不足の`reserve`)を意図的に起こしている間に、もう片方のセッションから`WRKOBJLCK OBJ(<自分のユーザー名>1/ZAIKOM) OBJTYPE(*FILE)`を実行し、ロックが実際に残っていない(修正が効いている)ことを外から観察してください。1つのPUB400アカウントで実際に2セッションを同時に開けるかどうか自体、06-11bの時点でも未確認のままです。

### 採点表

自分で採点してください。「✓」の数ではなく、理由を説明できるかを重視してください。

| 観点 | 基準 |
|---|---|
| `ZAISRV`のコンパイル | `ZAISRV`(`CRTRPGMOD`→`CRTSRVPGM`)がHighest Severity 10以下で実際にコンパイルできた(V1) |
| `DRIVER`の実行結果 | `DRIVER`を実行し、10行が「説明」節の実機値と一致することを確認した(V2) |
| ロックを解放したか | `reserve`の`UNLOCK`が、実際にロックを取った1分岐(SHORT)だけに追加されており、`NOTFOUND`分岐・`OK`分岐には無いことを、コードを見て自分の言葉で説明できる |
| `TXCHECK` | `TXCHECK LESSON('07-05') LIB(...)`(`*CMD`形)を実行し、3件ともPASSすることを確認した(V2) |

## セルフチェック

- [ ] `get`・`reserve`が、`F0608A`のどの部分をそれぞれ移植したものか説明できる。
- [ ] `release`が`F0608A`には無い新規ロジックであり、それでも新しい構文を1つも使っていないことを説明できる。
- [ ] `reserve`の`UNLOCK`が、SHORT分岐(実際にロックを取った1分岐)だけに追加されており、NOTFOUND分岐・OK分岐には無い理由を説明できる。
- [ ] `*PGM`(`F0608A`)と`*SRVPGM`(`ZAISRV`、`ACTGRP(*CALLER)`)で、ロック・開いたファイルの寿命がどう変わるかを、活動化グループの観点から説明できる。
- [ ] `DRIVER`の10行が、実機メモの値と一致することを確認できた(`4-TWICE-A`/`4-TWICE-B`が同じ`ZASU`を表示する理由も含めて)。
- [ ] `2B-DIAG-CHAIN`の`NO CONFLICT SEEN`が、修正の効果を証明したものではなく、対照実験の無いテストであることを、自分の言葉で説明できる。
- [ ] `TXCHECK`(`*CMD`形)で3件ともPASSすることを確認した。
- [ ] **演習後、`<自分のユーザー名>1/TXRESET`を実行し、`ZAIKOM`を初期状態に戻した。**

## 片付け

`ZAISRV`・`ZAISRVBD`・`DRIVER`はそのまま残してください。第8部(08-02)が、この`ZAISRV`一式をそのまま再利用します。**ただし`reserve`/`release`は`F0608A`(06-08)・`R0409A`(04-09)と同じ共有テーブル`ZAIKOM`を書き換えます。** 04-13・06-07の演習・06-15のチェックポイントは、いずれも`ZAIKOM`が既知の値であることを前提にしているため、演習で`DRIVER`を実行したら、**必ず`<自分のユーザー名>1/TXRESET`を実行**してから片付けを終えてください。演習3(コントロール実験)で`ZAISRV`を一時的に書き換えた場合は、`unlock zaikom;`の行を元に戻した状態で再作成してあることも確認してください。`TXCKM`の07-05向け3行は残しておいてかまいません(次回の`TXCHECK`実行でそのまま再利用できます)。

## まとめ

| 英語 | 日本語 |
|---|---|
| Give-back logic (`release`) | 引き当てた分を戻す、引当と対称なロジック |
| Lock lifetime tied to activation group | ロックの寿命が活動化グループの寿命に縛られること |
| `ACTGRP(*CALLER)` | 呼び出し元の活動化グループへ活動化される指定 |
| Smoke test | 「エラーなく走るか」だけを見る、区別力の弱いテスト |
| Control experiment | 対照実験(修正の有無で結果を比較する実験) |

これで第7部は完了です。モジュール・サービス・プログラム・バインダー・ソースと署名・活動化グループとILE CLという、ILE本来の仕組みをひととおり扱いました。次は第8部(08-01、gitプロジェクトとSRCSTMFビルド)から始まります。

## 実機メモ

- **確認日: 2026-09-27。接続`part07-05-checkpoint`(1回接続、CONFIRMED SUCCESS)。** `ZAISRV`はSeverity 10(`RNF7534`、`TOKUIM`同様の「非サイクル・モジュールは明示クローズ推奨」という助言、無害)、`ZAISRVBD`新規作成・1件登録、`DRIVER`はHighest Severity 00でコンパイル成功しました。**いずれもV1です。**
- **`DRIVER`の10行のロック・テストは、接続結果の`run`セクションの生テキストを直接読んで確認しました(V2)。** `WRKSPLF`・`DSPSPLF`で確認したものではありません——このハーネスの非対話SSHジョブは、印刷装置ファイル(`QSYSPRT`)への出力に対して実スプール・ファイルを作らないため(`CPYSPLF`は`CPF3303`で確実に失敗します)。5250で実際に`WRKSPLF`を操作して見る部分は、読者自身の確認(V3)に委ねます。上の「説明」節に引用した10行は、この接続の生ログとまったく同じ値です。
- **TXCHECK(直接`CALL`形、V2)**: 同じ`part07-05-checkpoint`接続の`run`セクションに、次のとおり印字されています(要約が2つの`SNDPGMMSG`に分かれているため2行になっている点も含め、生テキストのままの引用です)。

  ```text
  TXCHECK PASS: ZAISRV service program              exists
  TXCHECK PASS: ZAISRVBD binding directory              exists
  TXCHECK PASS: DRIVER checkpoint program              exists
  TXCHECK: lesson 07-05 - 0000000003 passed,
  0000000000 failed.
  ```

- **TXCHECK(`*CMD`形、学習者が実際に打つ形、V2)**: 別の接続`part06-b7-bundle`(確認日2026-09-28、CONFIRMED SUCCESS)で、`tools/qcmdsrc/txcheck.cmd`の`*CMD`ラッパーを、専用のCLヘルパー(`TXCHKRUN`、内部で`CALL PGM(QCMDEXC)`により`TXCHECK LESSON('07-05') LIB(<自分のユーザー名>1)`という文字列をそのまま実行する)経由で確認しています(`TXCKM`の07-05向け3行は`part07-05-checkpoint`が既に投入済みのものをそのまま再利用しており、この接続では再投入していません)。この接続の`run`セクションにも、上と一字一句同じ5行(3件のPASSと、2行に分かれた要約)が印字されました。

  ```text
  TXCHECK PASS: ZAISRV service program              exists
  TXCHECK PASS: ZAISRVBD binding directory              exists
  TXCHECK PASS: DRIVER checkpoint program              exists
  TXCHECK: lesson 07-05 - 0000000003 passed,
  0000000000 failed.
  ```

  **要約行のゼロ埋め(`0000000003`・`0000000000`)は、直接`CALL`形・`*CMD`形の両方の接続で同じ形で現れます。** これは呼び出し経路の違いによるものではなく、`txcheck.clp`自身の`CHGVAR`が`*DEC`の値を`*CHAR`型の変数へ代入する際に0でパディングされた文字列になり、続く`%TRIM`は空白だけを取り除いて0までは取り除かない、というTXCHECK自身のCLロジックに起因します。
- **`RUNTXRESET`**: `part07-05-checkpoint`接続内で`TXRESET: data restored to the initial state.`まで確認済みです(V2)。
- **この「実演」節が示す取り込み手順(読者自身が`CPYFRMSTMF`でメンバーを用意する経路)そのものは、上記どちらの接続でも検証していません。** 両接続とも、検証ハーネス自身がソースを直接メンバーへ書き込む、ハーネス固有の転送経路を使っています(06-08自身の実機メモに書かれている制約と同じ状況です)。ただし`part07-05-checkpoint`接続のログには`CPC7305: Member ZAISRV added to file QRPGLESRC in <USER>2.`(`ADDPFM`を経由せず`CPYFRMSTMF MBROPT(*REPLACE)`だけでメンバーが新規作成されたことを示すメッセージ)が実際に記録されており、07-01〜07-04と同じ`ADDPFM`なしの取り込み手順でメンバーが作られること自体は、この点で間接的に裏付けられています(06-06自身の実機メモが同じ経路について述べているのと同じ状況です)。
- `GET`/`RESERVE`/`RELEASE`(大文字)というエクスポート・シンボルの綴りは、`DRIVER`が実際にこの綴りの`EXTPROC`でコンパイル・束縛・実行に成功したこと(上記のV1/V2)によって裏付けられています。**`DSPSRVPGM SRVPGM(<自分のユーザー名>1/ZAISRV)`自体は、このリポジトリーの検証ではまだ実行しておらず、エクスポート一覧を直接見て確認したものではありません(未確認)。**
- **「診断の限界」の繰り返し**: `2B-DIAG-CHAIN`行の`NO CONFLICT SEEN`は、`UNLOCK`を欠いた版との対照実験を伴わない、単発の観測です。「同じ作業単位内での、別オープン・インスタンスからのロック付き`CHAIN`が実際に競合として現れるか」という前提自体も一次資料で確認できておらず、演習(発展)のコントロール実験・第2セッションからの`WRKOBJLCK`観察(V3)は、このリポジトリーではまだ誰も試していません。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
