# 08-04 単体テスト:自作TESTKIT

> 所要時間: 105分(長め)/ 前提レッスン: 08-03 / 目標番号: 6 / 観測方法: `TESTRES`(テスト結果テーブル、`SELECT`で確認)・ジョブ・ログ(`FAIL`行と`MONITOR`の挙動)/ 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・確認)、SQL(`STRSQL`・`RUNSQL`)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/TESTKIT`(*MODULE→*SRVPGM)・`<USER>1/TESTKITBD`(*BNDDIR)・`<USER>1/TSTJUCSRV`(プログラム)・`<USER>1/TSTZAISRV`(プログラム、演習で作成)・`<USER>1/TESTRES`(テーブル、`testInit()`が作成)。演習中QTEMPに一時的な`ZAIKOM`の複製を作りますが、共有の本物の`ZAIKOM`・`JUCHUM`・`TOKUIM`は書き換えません / DBVER: 1 / 依存するプローブ: P24(`ASSERT-T`がこのPUB400のPTFレベルでは未対応と確認済み)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- RPGUnitを使わずに、`*ESCAPE`と`MONITOR`だけでアサーション(比較・ログ・失敗時の例外送出)を組み立てられる。
- 自作の`TESTKIT`(*SRVPGM)を使って、07-02/07-03で作った`JUCSRV`に対する10件のテスト・ケース(`TSTJUCSRV`、12アサーション)を実行し、`TESTRES`テーブルで結果を確認できる。
- データを使うテストがなぜ同一ジョブ内で完結する必要があるのか(活動化グループ・QTEMPの生存期間)を、`ZAISRV`の境界値テストで自分の手を動かして確認できる。

## ウォームアップ

<details><summary>前回までの復習(07-03/07-05/06-09)</summary>

1. (07-03)`countCustOrders`を同じ活動化グループ内で2回連続呼ぶと、`close`/`open`の修正が無かった場合、2回目の呼び出しはなぜ`0`を返してしまうのですか?
2. (07-05)`ZAISRV`が`ACTGRP(*CALLER)`で作られている理由は何ですか?このことが「テストで使ったロック・開いたファイルの寿命」にどう関係しますか?
3. (06-09)`monitor`/`on-error`は、監視対象の文で例外が起きたとき、処理をどこへ進めますか?

答え: 1. `JUCHUM`はモジュール・スコープの大域ファイルで、`USROPN`(暗黙のオープンをしない指定)が付いています。一度読み切ってEOFまで達すると、その活動化グループが生きている限りその位置のままなので、2回目の呼び出しはいきなり`%EOF`が`*on`の状態から始まってしまい、1件も数えずに`0`を返します。`countCustOrders`は毎回`close`→`open`してから読み直すことで、呼び出しのたびに先頭から数え直す設計になっています。 2. `ACTGRP(*CALLER)`は「呼び出し元の活動化グループにこのサービス・プログラムを活動化させる」指定です。`ZAISRV`自身は`nomain`モジュールで`*inlr`に到達する場面が無いため、呼び出し元の活動化グループが生きている間(または`ZAIKOM`への次の入出力があるまで)、開いたファイル・取ったロックが残り続けます。08-04のテストも「1回のジョブ・1つの活動化グループの中で完結させる」という同じ前提の上に立っています。 3. `monitor`ブロックの中で例外(この教材では主に`*ESCAPE`)が起きると、その時点で`monitor`ブロックの残りの文はスキップされ、`on-error`ブロックへ処理が移ります。`on-error`ブロックを抜けたら、`monitor`/`on-error`全体の直後の文から実行が続きます——つまり、例外が起きてもプログラム全体は止まりません。

</details>

**08-03(規約・リンター)は、あえてここでは復習しません。** 08-03が課す制約(「エクスポートされる手続きの名前・シグネチャー・戻り値を変えない、振る舞い非破壊的なリファクタリングに限る」)は、既存の`JUCSRV`・`ZAISRV`を一切書き換えずにテストだけを追加する、という本レッスンの設計とも矛盾しないため、直接の依存がありません。

## なぜ学ぶか

第7部でせっかく`JUCSRV`・`ZAISRV`という*SRVPGMを作りましたが、これまでは「実行して、印字結果を目で見て確認する」というやり方しかしていません。第8部の後半(08-05/08-05b)では、レガシー・プログラムを出力を変えずに作り直す「特性検定(characterization test)」という手法を使います。08-05/08-05b自体は`TXSNAP`/`git diff`による基準出力の比較という別の技法を使いますが、「変更の前に、今の正しい動作を機械的に確かめる仕組みを用意してから変える」という考え方そのものは共通です。08-04では、この考え方を`TESTKIT`というコンパクトな道具で先に体験しておきます。`TESTKIT`自身は、第8部の終わり(08-08)で開発中の`ZAISRV`への機能追加を検証する道具として再び登場します(ただし08-08は`TESTKIT`自体を`<USER>2`への昇格対象には含めません——テスト用の道具一式は通常本番へは届けないためです)。

IBM iにはRPGUnitという有名な単体テスト・フレームワークがありますが、**このリポジトリにはRPGUnitはインストールも確認もされていません。** さらに、ILE RPGにはRPG言語自身が用意する`ASSERT-T`という命令もありますが、これも使えません——`work/design/refs/ilerpgref75.txt`が「2026年前半のコンパイル時PTFで追加」と明記しているのに対し、実際にPUB400で`ASSERT-T`を含む小さなプログラムをコンパイルしてみたところ(P24機能梯子、`docs/probes.md`確認日2026-09-26)、`RNF5347`(代入演算子が必要)・`RNF7030`(未定義の名前/標識)で一貫して失敗し続けることが確認されています。**つまりこのPUB400の現在のPTFレベルでは、`ASSERT-T`命令そのものが認識されません。** 同じ機能梯子の他の11項目(`**FREE`・`DIM(*AUTO)`・`FOR-EACH`・`MONITOR`系など)はすべて実機確認済みなので、原因は個別の書き間違いではなく`ASSERT-T`自体がこの環境に無いことだと判断できます。

RPGUnitも`ASSERT-T`も使えない以上、**このレッスンでは、これまでに実機確認済みの技法(06-13/06-14の埋め込みSQL、06-09の`QMHSNDPM`)だけを組み合わせて、最小限のテスト・アサーション用*SRVPGM(`TESTKIT`)を自分たちで作ります。** これは「車輪の再発明」ではなく、RPGUnitが内部で使っているのとまさに同じ発想(比較し、ログに書き、失敗なら例外を投げる)を、手元にある部品だけで組み立てる練習です。

## 新出

- 中核概念:
  1. テスト自動化を「例外で終了状態に落とす」という発想。RPGUnitが無くても、`*ESCAPE`と呼び出し元の`MONITOR`/終了コードで代替できます。
  2. アサーションは「比較し、ログに書き、違えば例外を投げる」手続きの組合せに過ぎません。特別な言語機能ではありません。
  3. データを使うテストは、同一ジョブ内で完結させる必要があります(活動化グループ・QTEMP・ロックの生存期間がジョブをまたがないという、07-03/07-05で学んだ知識の応用です)。
- 構文:
  1. `TESTKIT`のassert系手続き(`assertEqualsChar`/`assertEqualsNum`/`assertTrue`)の呼び出し方。
  2. `TESTRES`テーブルへのINSERT(テスト結果を1件ずつ記録するという発想。実際のSQL文自体は06-13/06-14の復習です)。
  3. `*ESCAPE`メッセージの送出(失敗を呼び出し元に伝える手段)。
  4. `monitor`/`on-error`との併用(1件の失敗が残りのケースを巻き込まないようにする書き方)。
  5. `CRTSQLRPGI OBJTYPE(*MODULE)`(`TESTKIT`を`NOMAIN`モジュールとしてビルドする指定。06-13は既定値`OBJTYPE(*PGM)`しか使っておらず、この値の指定はこのレッスンが初出です——詳しくは下の「なぜ.sqlrpgleなのか」参照)。
  6. `OVRDBF`の`OVRSCOPE(*JOB)`(オーバーライドの有効範囲をジョブ全体に広げる指定。03-10は無指定の`OVRDBF`/`DLTOVR`しか扱っておらず、この値の指定はこのレッスンが初出です)。

  **design doc(`work/design/part08-design-v1.md`)は本節の構文を4項目と見積もっていましたが、上の5・6は当初「既習の応用」に誤分類されていたもので、実際には新出です。スタイル・ガイドの上限(コマンド等6つまで)は満たしています。**
- **読解用(新出に数えない)**:
  - `ASSERT-T`: RPG言語自身が持つアサート命令ですが、上の「なぜ学ぶか」で説明したとおりこのPUB400では未対応(P24確認済み)です。存在だけ知っておいてください。
  - RPGUnit: IBM iの代表的な単体テスト・フレームワークですが、このリポジトリにはインストールも確認もされていません。「紹介のみ、導入しない」という扱いです。
  - `DLTOVR`の`LVL(*JOB)`: 演習1・片付けで、`OVRDBF`の取り消し方法の1つとして紹介しますが、一次資料でも確認できておらず未検証のため、実際に使うことは求めません(確実なのはサインオフし直すことです)。
- **既習の応用(新出に数えない)**: `CRTBNDDIR`/`ADDBNDDIRE`(07-02)、`OVRDBF`/`DLTOVR`の無指定形(03-10)、`CRTDUPOBJ`(05-12)。いずれも構文自体は既に確認済みで、このレッスンでは組み合わせ方が新しいだけです。**`RUNSQL`は05-07/05-11/05-13で`STRSQL`と並ぶ選択肢として名前だけは既出ですが、`RUNSQL SQL('...') COMMIT(*NONE)`という具体的な構文が本文に登場するのはこのレッスンが初出です**(構文の上限(6つ)にはこれ以上余裕が無いため、新出には数えず、この段落で個別に注記するにとどめます)。

## 説明

### `TESTKIT`の4つの手続き

`TESTKIT`(`src/qrpglesrc/testkit.sqlrpgle`)は次の4つの手続きをエクスポートする*SRVPGMです。

| 手続き | 役割 |
|---|---|
| `testInit()` | `TESTRES`テーブルが無ければ作る(既にあれば何もしない) |
| `assertEqualsChar(testName, expected, actual)` | 文字列2つを比較する |
| `assertEqualsNum(testName, expected, actual)` | 数値2つを比較する(`packed(15:5)`、後述) |
| `assertTrue(testName, actual)` | 標識1つが`*on`かどうかを確認する |

`TESTKIT`を呼ぶ側(`TSTJUCSRV`)は、次のようにこの4つをプロトタイプ宣言してから使います(`solutions/08-04/tstjucsrv.rpgle`)。

```rpgle
dcl-pr testInit extproc(*dclcase);
end-pr;

dcl-pr assertEqualsChar extproc(*dclcase);
  testName char(30) const;
  expected char(30) const;
  actual   char(30) const;
end-pr;

dcl-pr assertEqualsNum extproc(*dclcase);
  testName char(30) const;
  expected packed(15:5) const;
  actual   packed(15:5) const;
end-pr;

dcl-pr assertTrue extproc(*dclcase);
  testName char(30) const;
  actual   ind const;
end-pr;
```

`EXTPROC(*DCLCASE)`が必要な理由は07-02/07-03で確認済みのルールと同じです。`src/qsrvsrc/testkit.bnd`の`EXPORT SYMBOL`は`'testInit'`のように引用符付き・小文字混じりで書かれており、こうした引用符付きのエクスポート名は、コンパイラーの既定(大文字化)ではなく`dcl-proc`側の綴りそのままと一致させる必要があります。`EXTPROC(*DCLCASE)`は、その綴りを呼び出し側のプロトタイプの名前に固定する指定です。

`testInit()`の実装は次のとおりです(実際の`CREATE TABLE`文のあとには、SQLSTATE 42710「すでに存在する」だけを許容するという設計を説明する長いコメントが続きますが、ここでは省略しています。全文は`src/qrpglesrc/testkit.sqlrpgle`を参照してください)。

```rpgle
dcl-proc testInit export;
  dcl-pi *n extproc(*dclcase);
  end-pi;

  exec sql
    CREATE TABLE TESTRES (
      SEQ      INT GENERATED ALWAYS AS IDENTITY,
      TESTNM   VARCHAR(30),
      EXPECTED VARCHAR(30),
      ACTUAL   VARCHAR(30),
      RESULT   VARCHAR(4),
      PRIMARY KEY (SEQ)
    );

  return;
end-proc;
```

`TESTRES`(結果テーブル)は、`SEQ`(行番号、自動採番)・`TESTNM`(ケース名)・`EXPECTED`(期待値、文字列化して保存)・`ACTUAL`(実際の値、同じく文字列化)・`RESULT`(`PASS`または`FAIL`)の5列です。**`testInit()`はテーブルが無ければ作るだけで、中身を空にはしません**(この点は下の「実機メモ」で説明する、実機で見つかった実際のバグとその修正の経緯があります)。

このCREATE TABLE文はライブラリー名を書いていない(無修飾)SQL文です。**無修飾のDDL文(CREATE TABLE)は、無修飾のDML文(SELECT/INSERT)とは違うルールで解決先を探します**——DMLは`*LIBL`をたどって探しますが、DDLは**現行ライブラリー(`*CURLIB`)** に対して行われます。01-05で確認したとおり、この教材では現行ライブラリーは普段`<USER>1`のままのはずです(`DSPLIBL`の「現行ライブラリー」欄で確認できます)。ふだんどおり`<USER>1`で学習を進めていれば、`TESTRES`は特に何もしなくても`<USER>1`に作られます(検証ハーネス自身が`CHGCURLIB`を挟んでいる事情は、下の「実機メモ」を参照してください)。

`assertEqualsNum`は次のとおりです。

```rpgle
dcl-proc assertEqualsNum export;
  dcl-pi *n extproc(*dclcase);
    testName char(30) const;
    expected packed(15:5) const;
    actual   packed(15:5) const;
  end-pi;

  dcl-s expectedTxt char(30);
  dcl-s actualTxt   char(30);

  expectedTxt = %char(expected);
  actualTxt   = %char(actual);

  if expected = actual;
    logResult(testName : expectedTxt : actualTxt : *on);
  else;
    logResult(testName : expectedTxt : actualTxt : *off);
    raiseFail(testName);
  endif;

  return;
end-proc;
```

引数が`packed(15:5)`(小数点以下5桁)になっているのは、`countCustOrders`の`zoned(5:0)`も`get`/`reserve`/`release`の`packed(7:0)`も、`CONST`パラメーターの自動変換でそのまま渡せる、十分に広い型を選んだからです(型ごとに手続きを分けずに済みます)。**`%char()`は小数点以下の桁数どおりに文字列化するため、`TESTRES`の`EXPECTED`/`ACTUAL`列には`2`ではなく`2.00000`のような形で記録されます。** これは2026-09-28の実機接続(`part08-04-testkit`)で実際に確認済みです——`04-CNT-C00001`行は`EXPECTED`/`ACTUAL`とも`2.00000`、`3B-GET-NOTFOUND`行は`-1.00000`、`0`だったケース(`07-CNT-NOTFOUND`・`1B-STOCK-ZERO`)は先頭のゼロが無い`.00000`という形でした。**`DECEDIT`(制御仕様書=`ctl-opt`のキーワード、既定値はピリオド)が左右するのは小数点の文字(ピリオドかコンマか)だけで、先頭ゼロの有無とは無関係です**——一次資料(`ilerpgref75.txt`44254-44262行目)は、`%CHAR(numeric)`が小数の値を常に「without leading zeros」(先頭ゼロ無し)で文字列化し、小数点の文字だけが`DECEDIT`キーワードに従うと明記しています。`docs/style-guide.md`が指摘するとおりPUB400のSQL側(`QDECFMT`)はコンマ設定ですが、これは`RUNSQL`等のSQL文字列リテラルの解釈に関わる別の設定で、`TESTKIT`の`ctl-opt`は`DECEDIT`を指定していないため既定のピリオドのままです——上の実測値がすべてピリオド区切りだったのはこのためです。テーブルを`SELECT`するときは、この先頭ゼロが無い表示形式を念頭に置いてください。

`assertEqualsChar`・`assertTrue`は同じ形で、それぞれ文字列比較・標識の確認をしたあと、内部の`logResult`(結果を1行INSERTする、非公開の共通処理)を呼びます。

```rpgle
dcl-proc logResult;
  dcl-pi *n;
    testName char(30) const;
    expected char(30) const;
    actual   char(30) const;
    passed   ind const;
  end-pi;

  dcl-s result varchar(4);

  if passed;
    result = 'PASS';
  else;
    result = 'FAIL';
  endif;

  exec sql
    INSERT INTO TESTRES (TESTNM, EXPECTED, ACTUAL, RESULT)
      VALUES (:testName, :expected, :actual, :result);

  return;
end-proc;
```

### 失敗したらどうなるか:`*ESCAPE`と`MONITOR`

`assertEqualsChar`/`assertEqualsNum`/`assertTrue`は、比較結果が`PASS`でも`FAIL`でも、まず`logResult`で1行記録します。**`FAIL`のときだけ、追加でもう1つのことをします**——呼び出し元に向けて`*ESCAPE`メッセージを送ります。

```rpgle
dcl-proc raiseFail;
  dcl-pi *n;
    testName char(30) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);
  dcl-s  msgText char(200);

  msgText = 'TESTKIT: assertion failed - ' + %trimr(testName);

  qmhsndpm('CPF9898' : msgFile : msgText : %len(%trimr(msgText))
             : '*ESCAPE' : '*' : 2 : msgKey : errCode);

  return;
end-proc;
```

`QMHSNDPM`(06-09で確認済みのAPI)を、メッセージ・タイプ`*ESCAPE`で呼んでいます。7番目の引数`2`(`callStackEntry`の段数、`callStackCtr`)が肝心な部分です。`raiseFail`は`assertXxx`から呼ばれ、`assertXxx`はテスト・ケース側のコードから呼ばれる、という2段の入れ子になっているため、「`raiseFail`自身」を`0`、「`raiseFail`を呼んだ`assertXxx`」を`1`、「`assertXxx`を呼んだテスト・ケース側のコード」を`2`と数えます。**例外を実際に受け取ってほしいのはテスト・ケース側のコードなので、`2`が正しい値です。**(`src/qrpglesrc/testkit.sqlrpgle`の`raiseFail`直前のコメントも、レッスン執筆時に見つかったこの数え違いの記載ミスを`2`に修正済みです。)

**この`*ESCAPE`は、呼び出し元が何もしなければ、呼び出し元のプログラムをそこで異常終了させます。** 1つのテスト・ケースに10件のアサーションがあるとき、最初の1件が失敗しただけで残り9件が実行されずに終わってしまっては困ります。そこで、テスト・ケース側は**アサーション1件ごとに`monitor`/`on-error`で包みます**。

```rpgle
monitor;
  assertEqualsNum('04-CNT-C00001' : 2 : countCustOrders('C00001'));
on-error;
endmon;
```

`on-error`ブロックの中身はわざと空です。**アサーション自体の失敗はすでに`TESTRES`へ記録済みなので、ここでやることは何もありません**(`*ESCAPE`を捕まえて処理を先へ進めること自体が目的です)。**ただし、この空の`on-error`は「アサーションの失敗」以外の想定外エラー(テスト対象の手続き自体が起こす例外など)も同じように黙って握りつぶします。** その場合は`logResult`が一度も呼ばれないため、`TESTRES`の行数が期待した件数(`TSTJUCSRV`なら12件)に届かないことで気づくことになります——アサーション失敗と、テスト対象コード自体のエラーとでは、`TESTRES`に現れる痕跡が違う、という点に注意してください。

**では、なぜ`assertXxx`は戻り値(`ind`)を返す設計にしなかったのでしょうか。** `*ESCAPE`は、「呼び出し元に制御が戻ったあとに発火する」わけではありません。`raiseFail`・`assertXxx`それぞれの呼び出し履歴の段は、自分自身の`return;`文を一度も実行しないまま取り消され(異常終了し)、`callStackCtr`で指定した段(テスト・ケース側のコード)へ、例外として一気に制御が渡ります——一次資料(`ilerpgprogguide75.txt`「Returning from a Called Program or Procedure」節)は、「手続きの外側にあるものがその呼び出しを終わらせたとき、手続きは異常終了する」例として、まさにこの「呼び出し元へ直接エスケープ・メッセージを送る」ケースを挙げています。つまり`monitor`で包んでいない場合、呼び出し元は「`assertXxx`の戻り値を読む」という次の文に到達しないのは確かですが、それは`assertXxx`が一度正常にreturnしたからではなく、`assertXxx`自身の呼び出しがreturnを実行しないまま巻き戻されるからです。戻り値で分岐させる設計は、この巻き戻しの仕組みと相性が悪いため、`TESTKIT`の4つの手続きはすべて戻り値を返さない(VOID)設計にしてあります。「実行が次の文まで続いた」ことそのものがPASSの証拠、「`*ESCAPE`で処理が飛んだ」ことがFAILの証拠です。

### なぜ`.sqlrpgle`なのか(設計書からの意図的な逸脱)

`work/design/part08-design-v1.md`の08-04節の一覧では、このファイルは`src/qrpglesrc/testkit.rpgle`(埋め込みSQLを使わない、ふつうの`**FREE`)と書かれています。**実際のファイルは`testkit.sqlrpgle`(埋め込みSQL付き)です。** 正直に理由を書きます。

`TESTKIT`は`TESTRES`テーブルへ行をINSERTする必要があります。`**FREE` RPGからそれを行う手段は、実質的に(a)埋め込みSQL(`EXEC SQL INSERT ...`、06-13/06-14で実機確認済み)か、(b)`QCMDEXC`でCLコマンド`RUNSQL`を呼ぶか、の2択でした。**(b)はこのリポジトリでは避けています**——`QCMDEXC`経由では一部のCLコマンド(`SNDPGMMSG`)が実行できないという実際の制約(`CPD0031`「Command SNDPGMMSG not allowed in this setting」、`src/qrpglesrc/f0605bs.rpgle`のほか06-05/06-09/07-01などで繰り返し確認済み)がすでに一度見つかっており、`RUNSQL`が同じ制約を受けるかどうかは一次資料で確認できていません。一方、埋め込みSQLは`CRTSQLRPGI OBJTYPE(*MODULE)`という、`*MODULE`出力に対応したパラメーターが一次資料(`cl_commands_75.txt`)にそのまま載っており、`NOMAIN`モジュールを作ってから`CRTSRVPGM`で結合するという、これまでと同じ2段階のビルド手順がそのまま使えます。**確実な方を選んだ結果が`.sqlrpgle`です。**

### 命名について

`TESTKIT`は演習オブジェクトの型(付録E §3.1)にも`TX`接頭辞の教材ツール(付録E §5)にも当てはまらず、`JUCSRV`・`ZAISRV`と同じ、役割を表す機能名の系譜(付録E §3.2)に分類しています——学習者自身がこのレッスンで組み立て、以降も使い続ける資産だからです(付録E §5に追加したこの区別の根拠は下の「実機メモ」参照)。バインディング・ディレクトリー`TESTKITBD`・テスト・プログラム`TSTJUCSRV`/`TSTZAISRV`の命名根拠も同様に「実機メモ」にまとめています。

### `TSTJUCSRV`:10ケース・12アサーション

`solutions/08-04/tstjucsrv.rpgle`は、`db/data/load_v1.sql`の実データに基づく10件のケースを実行します(ケース9・10はそれぞれ2つのアサーションに分かれるため、実際には12件のアサーションになります)。実データはこのとおりです。

| `TOKUIM` | | `JUCHUM`(`JUTOK`ごとの件数) | |
|---|---|---|---|
| `C00001` | `ACME TRADING CO` | `C00001` | 2件(`J00001`・`J00003`) |
| `C00002` | `NORTH STAR LTD` | `C00002` | 1件(`J00002`) |
| | | `C00003` | 2件(`J00004`・`J00008`) |

ケース1〜8は`getCustName`・`countCustOrders`・`pingJucsrv`の素直な呼び出しです。

```rpgle
monitor;
  assertEqualsChar('01-GETNAME-C00001' : 'ACME TRADING CO'
    : getCustName('C00001'));
on-error;
endmon;
```

**ケース9・10が、このレッスンならではの狙いです。**

```rpgle
// --- 9: countCustOrders called TWICE in a row, same activation group -
monitor;
  assertEqualsNum('09-CNT-TWICE-A' : 2 : countCustOrders('C00001'));
on-error;
endmon;

monitor;
  assertEqualsNum('09-CNT-TWICE-B' : 2 : countCustOrders('C00001'));
on-error;
endmon;

// --- 10: call-order swap (getCustName then countCustOrders) ---------
monitor;
  assertEqualsChar('10A-GETNAME-C00002' : 'NORTH STAR LTD'
    : getCustName('C00002'));
on-error;
endmon;

monitor;
  assertEqualsNum('10B-CNT-C00002' : 1 : countCustOrders('C00002'));
on-error;
endmon;
```

ケース9は、まさに上のウォームアップで復習した「`JUCHUM`再位置付け」の修正が効いているかどうかを、自動的に確かめるケースです。修正が無ければ2回目は`0`を返すところを、`2`のままであることを確認します。ケース10は、`getCustName`(`TOKUIM`、`CHAIN`専用)と`countCustOrders`(`JUCHUM`、逐次`READ`)という、アクセス方法の異なる2つのファイルを交互に呼んでも、互いの状態が乱れないことを確認します。

### QTEMP分離設計(演習の`ZAISRV`境界値テストで使います)

`ZAISRV`の境界値テストは、共有の本物の`ZAIKOM`ではなく、**QTEMPに作った複製**を使います。これは`ZAISRV`側のソースを直接書き換えるのではなく、**呼び出し側(このあとの演習手順)が`OVRDBF`でファイルの実体を差し替える**という設計です。`ZAISRV`は`ACTGRP(*CALLER)`なので、呼び出し元(`TSTZAISRV`)の活動化グループへ活動化されます——`OVRDBF`は、`ZAISRV`のモジュールが実際にファイルを開くより前に効いている必要があります。詳しい手順は下の「演習」で扱います。

## 実演

**この実演で作る`TESTKIT`・`TESTKITBD`・`TSTJUCSRV`は、実機コンパイル・実行(V1/V2)まで確認済みです。ただし実際に検証で動いた`TSTJUCSRV`は、下記12件に加えてもう1件、わざと失敗するケースを含む別バージョンでした——詳しくは下の「実機メモ」を必ず読んでください。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にします(`git pull`)。

2. ソースを取り込みます(演習で使う`TSTZAISRV`のソースも、1回の接続でまとめて取り込んでおきます)。`<自分のユーザー名>1/QSRVSRC`は07-03で作成済みのはずです。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/testkit.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/TESTKIT.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qsrvsrc/testkit.bnd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QSRVSRC.FILE/TESTKIT.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/08-04/tstjucsrv.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/TSTJUCSRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/08-04/tstzaisrv.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/TSTZAISRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`TESTKIT`をコンパイルします(埋め込みSQLなので`CRTSQLRPGI`→`CRTSRVPGM`の2段階です)。

   ```text
   CRTSQLRPGI OBJ(<自分のユーザー名>1/TESTKIT) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(TESTKIT) OBJTYPE(*MODULE) COMMIT(*NONE)
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/TESTKIT) MODULE(<自分のユーザー名>1/TESTKIT) EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(TESTKIT) ACTGRP(*CALLER)
   ```

   どちらもHighest Severity 00になることを確認してください。

4. `TESTKITBD`(バインディング・ディレクトリー)を作ります。

   ```text
   CRTBNDDIR BNDDIR(<自分のユーザー名>1/TESTKITBD)
   ADDBNDDIRE BNDDIR(<自分のユーザー名>1/TESTKITBD) OBJ((*LIBL/TESTKIT *SRVPGM))
   ```

5. `TSTJUCSRV`をコンパイルします。`JUCSRVBD`(07-02で作成済み)と`TESTKITBD`の両方を結合します。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/TSTJUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(TSTJUCSRV) DFTACTGRP(*NO) ACTGRP(*NEW) BNDDIR((*LIBL/JUCSRVBD) (*LIBL/TESTKITBD))
   ```

   Highest Severity 00になることを確認してください。

6. 実行します。

   ```text
   CALL PGM(<自分のユーザー名>1/TSTJUCSRV)
   ```

7. `STRSQL`で結果を確認します(`RUNSQL`は結果セットを返せないコマンドなので、`SELECT`の確認には使えません)。

   ```sql
   SELECT SEQ, TESTNM, EXPECTED, ACTUAL, RESULT
     FROM <自分のユーザー名>1/TESTRES
     ORDER BY SEQ;
   ```

   **12行すべて`RESULT`が`PASS`になっているはずです。** `01-GETNAME-C00001`〜`10B-CNT-C00002`まで、「説明」節で挙げた実データどおりの期待値・実際値が並びます(数値の列は`%char`の仕様どおり、小数点以下5桁を伴う形で表示されます——`2.00000`・`0`だけは先頭ゼロ無しの`.00000`のように。実機で確認済みの表示形式です)。

## 演習

### 1. `ZAISRV`の境界値を5件(`TSTZAISRV`)

次の5件の境界値ケース(11アサーション)を実行します。

1. **ちょうど今の在庫数だけ`reserve`する** → 成功(`zaikomRec.zasu < qty`という厳密な不等号なので、等しい場合は成功する境界です)
2. **今の在庫数+1を`reserve`する** → SHORT(`ok=*off`、在庫は変化しません)
3. **存在しない商品コードを`reserve`する** → NOTFOUND(`ok=*off`)。`get`で同じコードを覗くと`-1`が返り、「見つからない」と「在庫不足」を区別できることも確認します
4. **`release`で在庫が戻る** → 在庫がqty分増えることを確認します
5. **`reserve`→`release`の往復が正味ゼロ** → 最初と最後で在庫が同じであることを確認します。**この5件目は`release()`の桁あふれ(`packed(7:0)`の上限`9999999`、`zaisrv.rpgle`自身が明記する既知の限界)をわざと踏まない設計にしてあります。** 桁あふれ自体が実際どんなエラーになるかは、この教材ではまだ実機確認していません。ただし、(桁あふれとは別の原因である)不正な10進数データによる`RPG0907`(10進数データ・エラー)が、非対話のバッチで応答不能な照会メッセージとしてジョブをハングさせることは05-11/05-13で確認済みです。**桁あふれが同種の照会メッセージを伴うかどうかは未検証ですが、同様のリスクを避けるため、境界値テストとはいえここは安全側に振っています。**

まず、ケース1・2(`1-RESERVE-EXACT-OK`/`1B-STOCK-ZERO`・`2-RESERVE-SHORT-OFF`/`2B-STOCK-UNCHANGED`)ぶんのアサーション文を、**紙かエディターの適当な作業用ファイルに、自分で書いてみてください**(下の手順1で`TSTZAISRV`メンバー自体は模範解答からコンパイルするため、ここではまだそのメンバーを編集しません)。上の「説明」で示した`monitor`/`assertTrue`/`assertEqualsNum`の書き方がそのまま使えます。`ZAISRV`の`get`/`reserve`/`release`は`TESTKIT`の4手続きとは違い、`EXTPROC('GET')`/`EXTPROC('RESERVE')`/`EXTPROC('RELEASE')`(大文字・引用符付き、`*DCLCASE`ではありません)というプロトタイプ宣言になります——`solutions/07-05/driver.rpgle`の宣言をそのまま流用できます。**ケース1は`reserve`の直後、確認用アサーションを挟んだあとに`release`で在庫を元へ戻す1行も忘れないでください**(戻さないと、ケース2が計算する「今の在庫数+1」が狂います)。書けたら`solutions/08-04/tstzaisrv.rpgle`の該当箇所と見比べ、差異があれば理由を考えてみてください。

残り(ケース3〜5)を含む`solutions/08-04/tstzaisrv.rpgle`全体を読み、実行してください。本文にはコードを貼りません(`docs/style-guide.md`の方針どおり、模範解答は`solutions/`を参照してください)。`prodCode`は`P00001`、存在しない商品コードには`P99999`を使います(`driver.rpgle`・04-09の演習2と同じ、おなじみの組み合わせです)。

**このテストは共有の本物の`ZAIKOM`を直接触らず、QTEMPに作った複製に対して実行します。** 手順は次のとおりです。**必ず1回の5250セッションの中で、順番どおりに実行してください**(5250とACS・SQLクライアントは別ジョブになるため、QTEMPのオブジェクトを共有できません——05-07で確認済みの、`QTEMP`はジョブ・スコープだという注意点と同じです)。

1. `TSTZAISRV`をコンパイルします(`ZAISRV`は07-05で作成済みの`ZAISRVBD`を使います)。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/TSTZAISRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(TSTZAISRV) DFTACTGRP(*NO) ACTGRP(*NEW) BNDDIR((*LIBL/ZAISRVBD) (*LIBL/TESTKITBD))
   ```

2. `ZAIKOM`をQTEMPへ複製します(05-12で確認済みの`CRTDUPOBJ`です)。

   ```text
   CRTDUPOBJ OBJ(ZAIKOM) FROMLIB(<自分のユーザー名>1) OBJTYPE(*FILE) TOLIB(QTEMP) DATA(*YES)
   ```

3. QTEMPの複製だけを書き換えます。`P00001`の実際の在庫(`db/data/load_v1.sql`の初期値は`45`)ではなく、**わざと別の値(`7`)を注入します**——これが、あとで「本物ではなくQTEMPの複製を見ているか」を見分ける手掛かりになります。

   ```text
   RUNSQL SQL('UPDATE QTEMP/ZAIKOM SET ZASU = 7 WHERE ZASHO = ''P00001''') COMMIT(*NONE)
   ```

4. `ZAIKOM`への参照をQTEMPの複製へ差し替えます。**ここで`OVRSCOPE(*JOB)`を付けます。** 一次資料(`ilerpgprogguide75.txt`)によれば、`OVRDBF`の既定の有効範囲は活動化グループで、ジョブ全体に効かせるには`OVRSCOPE(*JOB)`を明示する必要があります(「The default scope for overrides is the activation group. For job-level scope, specify OVRSCOPE(*JOB)」)。このコマンド自体は対話ジョブの既定の活動化グループで発行しますが、`TSTZAISRV`は`ACTGRP(*NEW)`で呼ばれるたびに別の活動化グループを持つため、**`OVRSCOPE(*JOB)`を指定しておけば活動化グループをまたいでも確実に効きます。既定の(活動化グループ・スコープの)ままでも同じ結果になるかどうかは、このリポジトリでは実際に比較検証していません(未検証)** ——「データを使うテストは同一ジョブ内で完結させる」という中核概念を、確実な形で満たすために`OVRSCOPE(*JOB)`を使っています。

   ```text
   OVRDBF FILE(ZAIKOM) TOFILE(QTEMP/ZAIKOM) OVRSCOPE(*JOB)
   ```

5. 実行します。

   ```text
   CALL PGM(<自分のユーザー名>1/TSTZAISRV)
   ```

6. `TESTRES`を`SELECT`してください。実演のあと`TESTRES`には`TSTJUCSRV`の12行が残っているので、今回の11行が積み重なり、**合計23行**になっているはずです。新しく増えた11行(`1-RESERVE-EXACT-OK`〜`5C-NET-ZERO`)がすべて`PASS`であることを確認してください。

7. **在庫の値そのものが、QTEMP分離が実際に効いたことの証拠になります。** `2B-STOCK-UNCHANGED`・`4B-STOCK-INCREASED`・`5C-NET-ZERO`の3件は、QTEMPの複製(`7`を注入済み)を正しく見ていれば`7`/`10`/`7`という値になります。もし本物の`<自分のユーザー名>1/ZAIKOM`を(`TXRESET`済みの初期状態=`P00001`が`45`と仮定して)見ていたら`45`/`48`/`45`という値になる**はず**ですが、この一例はあくまで「`TXRESET`済みの初期状態」を仮定した場合の参考値です——実際の値は、これより前のレッスン(07-05・06-08等)の演習で`TXRESET`を実行し忘れていないかなど、**学習者自身の`<USER>1`の状態次第で変わります。** **`1-RESERVE-EXACT-OK`・`1B-STOCK-ZERO`はどちらの場合でも同じ結果(成功・`0`)になってしまうため、この2件だけでは分離が効いたかどうかを判定できません**——判定材料になるのは上の3件です。**自分の`TESTRES`で`2B`/`4B`/`5C`が`7`/`10`/`7`以外の値になっていたら(45/48/45系とは限りません)、`OVRDBF`が効いておらず本物の`ZAIKOM`を書き換えてしまっています。ただちに`<自分のユーザー名>1/TXRESET`を実行してください。**

8. 演習が終わったら、`OVRDBF`の効果を消します。**一番確実なのは、このセッションを一度サインオフしてサインオンし直すことです**(ジョブが終われば、ジョブ・スコープのオーバーライドは残らず消えます)。同じセッションのまま続けたい場合は`DLTOVR FILE(ZAIKOM) LVL(*JOB)`を試すという選択肢もありますが、`LVL(*JOB)`というパラメーターの動作はこのリポジトリの一次資料には無く未検証のため(新出の「読解用」参照)、確実なのはサインオフし直すことです。

### 2. (発展)わざと失敗させて、`MONITOR`の効果を自分の目で見る

`TESTKIT`の`*ESCAPE`/`MONITOR`の仕組みが本当に「1件の失敗が残りを巻き込まない」ことを、自分の手で確かめます。**このリポジトリの検証でも、実際にこの方法でMONITORの継続実行を確認しています(下の「実機メモ」参照)。**

1. `TSTJUCSRV`のソース・メンバーを編集し、明らかに間違った期待値を持つアサーションを1つ、一時的に追加してください。たとえば`countCustOrders('C00001')`(正しくは`2`)に対して、`999`のようなありえない期待値をぶつける`monitor`/`assertEqualsNum`/`on-error`/`endmon`のひとかたまりを、既存のケースと同じ書き方で先頭あたりに挟みます。**`**FREE`ソースはSEUでは編集できない可能性があります(06-03の実機メモが指摘するP10、未検証)。** 安全なのは、`~/ibmi-kyozai/solutions/08-04/tstjucsrv.rpgle`(gitで管理されているファイルそのものです)を直接編集するのではなく、**別の作業用パスへコピーしたもの**をSSH経由のエディターで編集し、実演の手順2と同じ`CPYFRMSTMF`(コピー先のパスに差し替えて)でメンバーへ上書きするやり方です。こうしておけば、あとで`git pull`するときにリポジトリ側が汚れません。
2. `CRTBNDRPG`で`TSTJUCSRV`を作り直します(既存オブジェクトを置き換えるので`REPLACE(*YES)`を付けます)。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/TSTJUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(TSTJUCSRV) DFTACTGRP(*NO) ACTGRP(*NEW) BNDDIR((*LIBL/JUCSRVBD) (*LIBL/TESTKITBD)) REPLACE(*YES)
   ```

3. **実行前に`TESTRES`を空にします**(`testInit()`はもうテーブルを空にしません——下の「実機メモ」参照)。**このDELETEは、演習1(`TSTZAISRV`)が積み上げた11行も含め`TESTRES`全体を空にします**——演習1の`2B`/`4B`/`5C`の確認は、この演習へ進む前に済ませておいてください。

   ```text
   RUNSQL SQL('DELETE FROM <自分のユーザー名>1/TESTRES') COMMIT(*NONE)
   ```

4. `CALL PGM(<自分のユーザー名>1/TSTJUCSRV)`を実行し、`TESTRES`を`SELECT`してください。追加した行が`RESULT`=`FAIL`で記録され、**かつそのあとの本来のケースもすべて記録されている**(=`MONITOR`が`*ESCAPE`を捕まえ、処理が次のケースへ進んだ)ことを確認してください。`DSPJOBLOG`も確認してください。`TESTKIT: assertion failed - <ケース名>.`という行が記録されているはずです(この教材の実機検証でも同じ文言のメッセージが確認されています、下の「実機メモ」参照)。
5. **必ず元に戻してください**——実演の手順2にある`tstjucsrv.rpgle`用の`CPYFRMSTMF`を、そのままもう一度実行してメンバーを本来の模範解答で上書きし、`TSTJUCSRV`を`REPLACE(*YES)`で作り直し、`TESTRES`を空にしてから再実行して12件すべてPASSに戻してください。このリポジトリの模範解答(`solutions/08-04/tstjucsrv.rpgle`)には、この「わざと失敗するケース」は含まれていません。

**この演習は必ず5250の対話セッションでそのまま試してください。** `*ESCAPE`を`MONITOR`で捕まえずに放置した場合の挙動(発展でさらに試したくなった場合)は、対話ジョブなら実行者自身がその場でメッセージに応答できますが、**`SBMJOB`でバッチ投入する場合は必ず`INQMSGRPY(*DFT)`・`LOG(4 00 *SECLVL)`を付けてください**(`docs/style-guide.md`のPUB400作法、付録C)。付けずに投入すると、応答できない照会メッセージでジョブがハングする恐れがあります。

## セルフチェック

- [ ] `assertEqualsChar`/`assertEqualsNum`/`assertTrue`が、なぜ戻り値(`ind`)を返さない設計になっているか、`*ESCAPE`の発火タイミングを根拠に説明できる。
- [ ] `raiseFail`の`QMHSNDPM`呼び出しで`callStackCtr`に`2`を渡す理由(`raiseFail`→`assertXxx`→テスト・ケース、という2段の呼び出しを数えている)を説明できる。
- [ ] 各アサーションを`monitor`/`on-error`で包む理由(1件の失敗が残りのケースを止めないようにするため)を説明できる。
- [ ] `TSTJUCSRV`を実行し、12件すべて`PASS`であることを確認した。
- [ ] `TSTZAISRV`を実行し、11件すべて`PASS`であることを確認した(演習1)。
- [ ] `2B-STOCK-UNCHANGED`/`4B-STOCK-INCREASED`/`5C-NET-ZERO`の値が`7`/`10`/`7`であり、それ以外の値(学習者の実際の`ZAIKOM`の状態次第で`45`/`48`/`45`系とは限りません)ではないことを確認した(=QTEMP分離が効いていたことの確認)。
- [ ] (発展)わざと失敗するケースを追加・削除して、`FAIL`後も残りのケースが実行されることを自分の目で確認した(演習2)。
- [ ] `TESTKIT`はRPGUnitではないこと、`ASSERT-T`はこのPUB400では未対応であることを、自分の言葉で説明できる。

## 片付け

`TESTKIT`・`TESTKITBD`・`TSTJUCSRV`・`TSTZAISRV`はそのまま残してください。`TESTKIT`は、第8部のチェックポイント(08-08)で開発用ライブラリー上のまま、`ZAISRV`への機能追加を確かめる道具として再び登場します(`<USER>2`への昇格対象には含みません——テスト用の道具一式は通常本番へは届けないためです)。`TESTRES`もそのまま残してかまいません(次回の実行時、明示的に`DELETE FROM TESTRES`しない限り、行は積み上がっていきます)。

演習1で発行した`OVRDBF FILE(ZAIKOM) ...`は、**必ずセッションをサインオフするか、`DLTOVR FILE(ZAIKOM) LVL(*JOB)`(未検証、上の演習1手順8参照)で取り消してください。** 取り消し忘れたまま同じセッションで別のレッスンの`ZAIKOM`演習を行うと、QTEMPの複製を見続けてしまいます。

`TSTZAISRV`は共有の本物の`ZAIKOM`を書き換えない設計(QTEMP分離)です。**セルフチェックの「7/10/7」を実際に確認できていれば、`TXRESET`は不要です。** もし`7`/`10`/`7`以外の値が出ていた場合(=分離が効かず本物を触ってしまった場合)は、`<自分のユーザー名>1/TXRESET`を実行してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Assertion | アサーション(比較し、ログに書き、違えば例外を投げる手続き) |
| `*ESCAPE` message | 呼び出し元を異常終了させる(が`MONITOR`で捕まえられる)メッセージ種別 |
| `MONITOR`/`ON-ERROR` | 例外を捕まえ、処理を継続させる構文 |
| Characterization test | 特性検定(今の出力を基準にし、変更の影響を機械的に検出するテスト) |
| Job-scoped override | ジョブ全体に効く`OVRDBF`の有効範囲(`OVRSCOPE(*JOB)`) |

次のレッスン(08-05)では、この`TESTKIT`は直接使いませんが、「基準の出力を取ってから変える」という同じ発想(特性検定)を、`JU0300`(制御レベル処理)の作り直しに応用します。

## 実機メモ

- **確認日: 2026-09-28。接続`part08-04-testkit`(2回の接続、CONFIRMED SUCCESS)。** `TESTKIT`(`CRTSQLRPGI OBJTYPE(*MODULE)`→`CRTSRVPGM`)・`TSTJUCSRV`・`TSTZAISRV`の3本とも、Highest Severity 00でコンパイル成功しました。実行結果も確認済みです。
- **1回目の接続で見つかった実バグ(修正済み)**: `testInit()`は、当初`CREATE TABLE`に加えて`DELETE FROM TESTRES`も行う設計でした。`TSTJUCSRV`→`TSTZAISRV`の順に同じ接続内で実行したところ、`TSTZAISRV`自身の`testInit()`が、直前に`TSTJUCSRV`が書き込んだ行をすべて消してしまうことが判明しました。`testInit()`から`DELETE`を削除し(以後はテーブルの存在確認のみ)、2回目の接続で再検証しています。**このレッスンの演習・セルフチェックで「実行前に`TESTRES`を空にする」という手順を挟んでいるのは、この実際に見つかった挙動を踏まえたものです。**
- **`TSTJUCSRV`の12件のアサーションすべてPASS**: `getCustName('C00001')`=`'ACME TRADING CO'`、`getCustName('C00002')`=`'NORTH STAR LTD'`、`getCustName('Z99999')`=`'NOTFOUND'`、`countCustOrders('C00001')`=`2`、`countCustOrders('C00002')`=`1`、`countCustOrders('C00003')`=`2`、`countCustOrders('Z99999')`=`0`、`pingJucsrv()`=`*on`、`countCustOrders('C00001')`の同一活動化グループ内2連続呼び出しが両方とも`2`、`getCustName`→`countCustOrders`の呼び出し順序を入れ替えても影響無し——`db/data/load_v1.sql`の実データに基づく期待値が、すべて実機の値と一致しました。
- **`TSTZAISRV`の11件のアサーションすべてPASS**。**QTEMP分離が実際に効いていたことの直接的な証拠は、`TESTRES`自身が`2B-STOCK-UNCHANGED`・`4B-STOCK-INCREASED`・`5C-NET-ZERO`の3件で`7`/`10`/`7`(QTEMPへ注入した値)を記録し、`45`/`48`/`45`(本物の`P00001`の値から導かれるはずの値)を記録しなかったことです。** 同じ接続の`shared-zaikom-check`(本物の`ZAIKOM`を読む別ステップ)は`45`のまま(初期値のまま)でしたが、これは`TSTZAISRV`自身の5ケースがreserve/releaseの対になった正味ゼロ設計であるため、**QTEMP分離が効いていてもいなくても本物のテーブルは最終的に`45`に戻るはずで、この事実単独では分離が効いたことの証明にはなりません**(接続終了時点で本物のテーブルが初期値のままである、という補助的な確認にとどまります)。上の「7/10/7」の方が、分離が実際に機能したことを示す直接的な証拠です。
- **`MONITOR`による継続実行の直接確認**: 実際にコンパイル・実行されたのは、この模範解答(`solutions/08-04/tstjucsrv.rpgle`)ではなく、これに`00-DELIBERATE-FAIL-DEMO`という、わざと`countCustOrders('C00001')`の期待値を`999`にしたケースを1件追加した検証専用の版(`verify/part08-04-testkit/src/tstjucsrv-faildemo.rpgle`、`TSTJUCSRV`という名前でコンパイル)でした。この`00`番のケースは`TESTRES`に`RESULT`=`FAIL`(期待`999`・実際`2`)として記録され、ジョブ・ログには別途`TESTKIT: assertion failed - 00-DELIBERATE-FAIL-DEMO.`という行が記録されました。**そのあとの12件(01〜10B)はすべて`TESTRES`に`PASS`として記録され続けました**——`MONITOR`が`*ESCAPE`を捕まえ、処理が次のケースへ進んだことの直接的な確認です。この`00`番のケースは検証専用で、学習者向けの模範解答には含まれていません。演習2は、この実機確認と同じことを、学習者自身の手で(規模を1件に絞って)再現する内容です。
- **実際にコンパイル・実行されたライブラリーは`<USER>2`でした**(この教材の検証ハーネス自身の方針、`docs/probes.md`)。学習者向けの本文では、この教材のこれまでの慣例どおり`<USER>1`(開発用)への手順として書いています——オブジェクトの中身・動作自体はどちらのライブラリーでも変わりません。**`CPYFRMSTMF`自体(`FROMSTMF`/`TOMBR`/`MBROPT(*REPLACE)`の基本形)は検証ハーネスの中でも実行され確認されています**(`verify/lib/batch.mjs`、197-202行目付近——ソースをSSHのheredocでIFS上へ書き出したあと、続けてこの同じコマンドでメンバーへ取り込んでおり、実際のジョブ・ログにも`CPCA081: Stream file copied to object.`という完了メッセージが記録されています)。ただし、このハーネスはどの`file`ステップにも`ccsid`を指定していないため、実際に発行された`CPYFRMSTMF`には本文の実演が指定する`STMFCCSID(1208)`が付いていません(heredocで新規作成したファイルは既定でCCSID 273(EBCDIC)としてタグ付けされ、そのままコピーできています)。**未検証なのは、`STMFCCSID(1208)`を付けた形、かつ`git pull`で取得したUTF-8相当のファイルに対してこのコマンドを実行する、上の「実演」が示す学習者自身の経路そのものです。**
- **これは何がV1/V2で、何がまだV3(未検証)か**:
  - V1/V2(実機確認済み): `TESTKIT`・`TSTZAISRV`(コード(実行文)は模範解答と同じ内容でコンパイル・実行)、および`TSTJUCSRV`の12件の本物のケース(01〜10B、これらのアサーション文は`faildemo`版でも模範解答版でも同じです。ただしヘッダー・コメントは両ファイルで異なり、模範解答側のヘッダーはこの接続のあとにも手直しされています)。
  - V3(このリポジトリではまだ個別に確認していない): `STMFCCSID(1208)`付き・`git pull`取得ファイルに対する学習者自身の`CPYFRMSTMF`の経路そのもの、`00`番を含まない現在の`solutions/08-04/tstjucsrv.rpgle`をそのまま単独でコンパイルし直すこと(中身は同じでも、この正確なメンバー構成での再コンパイル自体はまだ行っていません)、演習1・演習2の対話的な実行手順そのもの、`DLTOVR`(または`DLTOVR ... LVL(*JOB)`)だけで`OVRSCOPE(*JOB)`のオーバーライドが確実に消えるかどうか。
- **`CHGCURLIB`について**: 検証ハーネス自身は、著者の私的なライブラリー(`<USER>1`)を検証に使わないという別の方針(`docs/probes.md`)があるため、`CHGCURLIB CURLIB(&LIB)`を挟んでいます。これはハーネス固有の事情であり、学習者が新しく覚える必要のある手順ではありません(`<USER>1`で普段どおり学習していれば、現行ライブラリーは既に`<USER>1`のままのはずです)。
- **命名(付録E)について**: `TESTKIT`を`JUCSRV`・`ZAISRV`と同じ役割ベースの系譜(付録E §3.2)に分類した根拠は、`TX`接頭辞ツール(付録E §5)が「著者があらかじめ用意するもの」という性質を持つのに対し、`TESTKIT`は学習者自身がこのレッスンで組み立て、以降も使い続ける資産だという点です。ただし、この区別を明示するルールは執筆時点で付録Eに無く、このレッスン自身の判断に留まっていたため、`docs/appendix/e-naming.md` §5に「学習者が組み立てて使い続けるツールは、用途がテスト・検証であっても§3.2に属する」という趣旨の一文を追加し、今後同種の判断に使える根拠にしました。バインディング・ディレクトリー`TESTKITBD`は、`JUCSRVBD`・`ZAISRVBD`と同じ「サービス・プログラム名+`BD`」という既存の規則(付録E §3.1.2)にそのまま従います。`TSTJUCSRV`・`TSTZAISRV`(テスト対象のサービス・プログラム名に`TST`を前置した名前)は、付録Eにまだ載っていない新しいパターンですが、`TESTKIT`と同じ「役割で名付ける」という精神の自然な延長です。
- **`src/qrpglesrc/testkit.sqlrpgle`のコメント3箇所を、このレッスンの執筆時に訂正しました(コードの動作・実測値はどちらも無変更です)**: (1) 冒頭ヘッダーの`CPF0031`は`CPD0031`の誤記でした(このリポジトリ全体で一貫して確認・記録されているメッセージIDは`CPD0031`です)。(2) 「WHY VOID, NOT ind」節の`(callStackCtr 1)`という表現も、`raiseFail`自身が実際に渡している値(`2`)と食い違っていたため`2`に修正し、あわせて「呼び出し元に制御が戻ってから発火する」という誤解を招く言い回し(上の「では、なぜ`assertXxx`は戻り値を返す設計にしなかったのでしょうか」の訂正と同じ理由)も、巻き戻し(呼び出し履歴の段が自分の`return;`を実行しないまま取り消される)であることが分かる表現に書き直しました。(3) `raiseFail`直前のコメントも`callStackCtr 1`のままだった(2箇所)のを`2`に統一しました。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
