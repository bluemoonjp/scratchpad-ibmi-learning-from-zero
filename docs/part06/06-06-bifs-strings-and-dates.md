# 06-06 組み込み関数(文字列)と日付

> 所要時間: 75分(長め)/ 前提レッスン: 06-05 / 目標番号: 5 / 観測方法: `DSPJOBLOG` / 道具: 5250、SSH / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/F0606A` / DBVER: 1 / 依存するプローブ: P24 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 文字列操作(名前の整形・検索)を`%TRIM`・`%SUBST`・`%SCAN`で書ける。
- 数値⇔文字の変換(`%CHAR`・`%DEC`)と、日付の計算(`%DATE`・`%DIFF`・`%DAYS`)ができる。
- RPG IIIのMOVE系の命令が、RPG IVでは`%BIF`呼び出しに置き換わることを、実際に手を動かして確認する。

## ウォームアップ

<details><summary>前回の復習</summary>

1. サブプロシージャーを`dcl-proc`で定義するとき、`ctl-opt dftactgrp(*no) actgrp(*new);`を書き忘れると何が起きる?
2. `value`・`const`は、RPG IIIのパラメーター渡し(`*ENTRY PLIST`)には無かった、何を守るためのキーワード?

答え: 1. コンパイル・エラーになる(`RNF1520`: "The procedure cannot be defined with DFTACTGRP(*YES)." サブプロシージャーは既定の活動グループでは定義できない)。 2. 呼び出し元の変数を、プロシージャー側で誤って書き換えてしまわない安全性(`value`は値のコピーを渡す、`const`は書き換え不可の制約を付ける)。

</details>

## なぜ学ぶか

**RPG IIIの命令コード(`MOVE`・`MOVEL`・`SUBST`・`SCAN`・`CAT`・`XLATE`)や、O仕様書38桁目の編集コード欄は、RPG IVでは式の中の`%`で始まる組み込み関数(BIF)呼び出しに置き換わります。** これは06-01bで対応表として先に見た内容ですが、ここで実際にコードを書いて確かめます。文字列の整形・検索、数値と文字列の変換、日付の計算は、業務プログラムのほぼどこにでも登場する基本操作なので、ここでまとめて身につけておくと、この先のレッスンで何度も使い回せます。

## 新出

- 桁あふれ(オーバーフロー)は、式(拡張Factor 2)の中では、RPG IIIのように暗黙に無視されるのではなく、必ず実行時エラーになる(捕まえ方は06-09で扱います。式の外の既定動作は下の「説明」を参照)。
- `%TRIM`(`%TRIML`・`%TRIMR`込みで1項目。前後の空白を取り除く)
- `%SUBST`(部分文字列の取得。代入先としても使える)
- `%SCAN`(文字列検索)
- `%CHAR`(数値・日付 → 文字列)
- `%DEC`(文字列 → パック10進数)
- `%DATE`・`%DIFF`・`%DAYS`(日付の生成と差分計算。日付BIFファミリーとして1項目で数えます)

**読解用(新出には数えません)**: `%SCANRPL`(文字列の置換検索)・`TEST(DE)`(日付の妥当性検査)は、一次資料(ILE RPG言語リファレンス)にこういうものがあると知っておけば十分です(付録Fの表にはまだこの2つの行がありません)。`%EDITC`/`%EDITW`(数値の編集。桁位置指定だったRPG IIIのO仕様書編集コード欄が関数呼び出しになったものです)は、[付録F](../appendix/f-bif-reference.md)の表を見て「こういうものがある」と知っておけば十分です。演習では扱いません。

**RPG IIIのオペコード→`%BIF`という対応そのもの**(06-01bで既に見た内容)は、このレッスンの新出には数えません。以下の説明・実演で、実際に手を動かして復習します。

## 説明

**注記**: 以下の各節のコードは`%BIF`のトピックごとにまとめて示しており、`F0606A`本体を上から順に実行したときの並び(実演の手順5でジョブ・ログに現れる順)とは一致しません。実際の実行順は実演の手順5を参照してください。

### 06-01bの復習: オペコード欄・桁位置が式の中の`%BIF`になる

[付録F](../appendix/f-bif-reference.md)がまとめているとおり、*RPG/400 Reference*を検索しても`%`で始まるBIFは1件も見つからず、RPG IIIでは文字列操作・数値変換・日付計算のすべてが命令コード(オペコード)や仕様書の桁位置で行われていました。

| RPG III(命令コード・桁位置) | RPG IV(`%BIF`) |
|---|---|
| `SUBST`命令 | `%SUBST` |
| `SCAN`命令 | `%SCAN` |
| `MOVE`/`MOVEL`・`Z-ADD`(数値⇔文字の変換) | `%CHAR`・`%DEC` |
| O仕様書38桁目の編集コード欄 | `%EDITC`(読解用。演習では使いません) |

06-01bで見たとおり、この対応自体は復習です。ここから先は、実際にRPG IVのコードでこれを確かめます。

### 文字列を整える: `%TRIM`・`%TRIML`・`%TRIMR`

```text
dcl-s firstName char(10) inz('Taro');
dcl-s lastName  char(10) inz('Yamada');
dcl-s fullName  char(21);
dcl-s padded    char(20) inz('  Taro  ');

fullName = %trim(firstName) + ' ' + %trim(lastName);
sendMsg('F0606A: fullName = ' + %trim(fullName));

sendMsg('F0606A: trim  <' + %trim(padded)  + '>');
sendMsg('F0606A: triml <' + %triml(padded) + '>');
sendMsg('F0606A: trimr <' + %trimr(padded) + '>');
```

`%TRIM`は前後両方、`%TRIML`は左側だけ、`%TRIMR`は右側だけの空白を取り除きます。`firstName`/`lastName`はいずれも`char(10)`(固定長、右側は空白で埋まっている)なので、`%TRIM`を挟まずに`+`で連結すると、余分な空白がそのまま挟まってしまいます。[付録F](../appendix/f-bif-reference.md)の`%TRIM`行が述べているとおり、RPG IIIにはこれに代わる決まった1つの命令はありません(要確認事項として付録F自身が明記しています)。近い効果を狙うなら、`CHECK`/`CHEKR`命令(Factor 2の各文字がFactor 1の文字集合に含まれるかを左から/右から検証し、含まれない文字の位置を返す)を使い、空白以外の文字の境界を自分で計算するような書き方が考えられます。なお、`MOVE`/`MOVEL`のオペレーション拡張子`P`(結果フィールドの残りを空白で埋める)は、境界計算そのものではなく、演習1で見る「古いデータが残る罠」を避けるための別の対策です。

### 部分文字列と検索: `%SUBST`・`%SCAN`

```text
dcl-s spacePos zoned(3:0);
dcl-s lastPart char(10);
dcl-s initial  char(1);

spacePos = %scan(' ' : fullName);
sendMsg('F0606A: spacePos = ' + %char(spacePos));

lastPart = %subst(fullName : spacePos + 1);
sendMsg('F0606A: lastPart = ' + %trim(lastPart));

initial = %subst(%trim(lastName) : 1 : 1);
sendMsg('F0606A: initial = ' + initial);
```

`%SCAN(検索文字列 : 対象)`は、見つかった位置(見つからなければ`0`)を返します。RPG IIIの`SCAN`命令と同じ働きですが、結果を直接式の中で使える点が違います。`%SUBST(対象 : 開始位置 [: 長さ])`は部分文字列を取り出します。[付録F](../appendix/f-bif-reference.md)の`%SUBST`の行にあるとおり、`%SUBST`は**代入先としても**使えます(演習で使います)。

### 数値⇔文字の変換: `%CHAR`・`%DEC`

```text
dcl-s totalPacked packed(9:2) inz(1738.00);
dcl-s totalText   char(15);
dcl-s totalBack   packed(9:2);

totalText = %trim(%char(totalPacked));
sendMsg('F0606A: totalText = ' + totalText);

totalBack = %dec(totalText : 9 : 2);
sendMsg('F0606A: totalBack = ' + %char(totalBack));
```

[04-02](../part04/04-02-c-spec-arithmetic.md)の`R0402A`(`1580 × 1.10 = 1738.00`、実機確認済み)と同じ数値を使い、パック10進数→文字列→パック10進数という往復変換をしています。RPG III時代なら`MOVE`/`MOVEL`(転記)・`Z-ADD`(ゼロ加算、実質的な代入)の組み合わせで行っていた変換です([付録F](../appendix/f-bif-reference.md)の`%CHAR`/`%DEC`行を参照)。

### 日付の計算: `%DATE`・`%DIFF`・`%DAYS`

```text
dcl-s orderDate date;
dcl-s dueDays   zoned(3:0) inz(30);
dcl-s dueDate   date;
dcl-s todayDate date;
dcl-s daysLeft  int(10);

orderDate = %date(20260901 : *iso);
todayDate = %date(20260926 : *iso);

dueDate = orderDate + %days(dueDays);
sendMsg('F0606A: dueDate = ' + %char(dueDate));

daysLeft = %diff(dueDate : todayDate : *days);
sendMsg('F0606A: daysLeft = ' + %char(daysLeft));
```

`%DATE(数値 : *iso)`は、`YYYYMMDD`形式の8桁数値(RPG IIIの`ZAUPD`のような数値の日付フィールドと同じ形)を`date`型に変換します。`日付 + %DAYS(n)`でn日後の日付が、`%DIFF(a : b : *days)`で2つの日付の差(日数)が求められます。RPG IIIには`date`型自体が無く、日付は単なる8桁の数値フィールドとして扱われ、日数計算は独自のロジックを書く必要がありました。

### 式の中の桁あふれ(オーバーフロー)は実行時エラーになる

RPG IIIでは結果フィールドの桁数を超えた部分は**警告なく消えます**(一次資料・教科書的な一般知識)。[04-02](../part04/04-02-c-spec-arithmetic.md)で実機確認したのは`1580 × 1.10 = 1738.00`という、桁あふれを起こさない基本計算の実行結果までです。桁あふれそのものの挙動(04-02の演習部分)は、04-02自身の実機メモが明記するとおり未確認のままなので、ここでは検証済みの事実としてではなく、一般知識として扱います。一次資料(ILE RPG言語リファレンス)によれば、RPG IVには`TRUNCNBR`という制御仕様書キーワードがあり、`*YES`なら桁あふれを無視して切り詰めた値を結果フィールドに入れ(RPG IIIと同じ挙動)、`*NO`なら実行時エラーにします。この`TRUNCNBR`の既定値が`*YES`であることは、`F0606A`自身のコンパイル・リスト(`part06-0509-procs-files`の実測、Control Specificationsの`Truncate numeric . . . . . . . . : *YES`という行)で実機確認しています。**ただし、この`TRUNCNBR`は式(拡張Factor 2)の中の計算には適用されません。式の中で桁あふれが起きた場合は、`TRUNCNBR`の設定に関係なく常に実行時エラーになる、と一次資料は明記しています。** `F0606A`のようにすべて`**FREE`(=すべて式)で書かれたプログラムでは、この「式の中は常にエラー」という規則がそのまま当てはまります。この例外の捕まえ方(`monitor`/`on-error`)は06-09で詳しく扱います。**`F0606A`自体は桁あふれを起こす場面を含まないため、この記述はこのレッスンでは実機確認していません**(一次資料に基づく記述、未検証)。

### `sendMsg`について(前方参照)

上のコードの`sendMsg(...)`は、06-05で使ったのと同じ`sendMsg`(ソースも同一の実装)を、この`F0606A`でも再利用しているものです。内部では`QMHSNDPM`(メッセージをジョブ・ログに書き込むAPI)を直接呼んでいますが、その`qualified`なデータ構造・`likeds`の意味は06-07で、`QMHSNDPM`自体の詳しい扱いは06-09で説明します。ここでは「`sendMsg`に文字列を渡すと、ジョブ・ログに残る」とだけ知っておいてください。

## 実演

1. SSHで接続し、`~/ibmi-kyozai`が最新であることを確認します(`git pull`)。`exit`で5250に戻ります。
2. 5250のコマンド行で、`<自分のユーザー名>1/QRPGLESRC`にメンバーを用意します。`QRPGLESRC`自体は06-01bで新規作成済みのはずです。まだ無ければ`CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')`を先に実行してください。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0606A) SRCTYPE(RPGLE) TEXT('BIFs: strings and dates')
   ```

3. SSHでもう一度接続し、`src/qrpglesrc/f0606s.rpgle`を取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0606s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0606A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

4. 5250に戻り、コンパイルして実行します。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0606A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0606A)
   CALL PGM(<自分のユーザー名>1/F0606A)
   ```

5. `DSPJOBLOG`で、`F0606A`が送ったメッセージ(メッセージID`CPF9898`)を確認します。次の11行が、この順で記録されているはずです(テキスト自体は著者の検証ライブラリーでの実測結果、V2。詳細は実機メモ参照)。

   ```text
   F0606A: fullName = Taro Yamada.
   F0606A: spacePos = 5.
   F0606A: lastPart = Yamada.
   F0606A: initial = Y.
   F0606A: trim  <Taro>.
   F0606A: triml <Taro              >.
   F0606A: trimr <  Taro>.
   F0606A: dueDate = 2026-10-01.
   F0606A: daysLeft = 5.
   F0606A: totalText = 1738.00.
   F0606A: totalBack = 1738.00.
   ```

   `triml`の行は右側の空白が、`trimr`の行は左側の空白が、それぞれ`>`の直前まで残っている点に注目してください。これが`%TRIML`(左だけ詰める)と`%TRIMR`(右だけ詰める)の違いです。**このメッセージ・テキストの内容そのものは、このハーネスの非対話SSH接続がジョブ・ログを直接読み取って確認済み(V2)です。5250で実際に`DSPJOBLOG`の画面を操作してこれを見る部分(表示のされ方、`F10`での詳細表示の要否など)は対話操作(V3)であり、このレッスンでは実機確認していません。**

## 演習

1. [04-03](../part04/04-03-character-ops.md)の`R0403A`を読み直してください。次の2行が「古いデータが残る罠」を起こしていました。

   ```text
   MOVEL'JOHNSON' NAME2  10
   MOVEL'AL'      NAME2
   ```

   結果は`NAME2 = 'ALHNSON'`(`MOVEL 'AL'`で先頭2桁だけ書き換わり、`'JOHNSON'`の3〜7桁目`'HNSON'`が残った)でした。

2. これを`%BIF`だけで書き直します。まず、単純な代入(`name2 = 'AL';`)にした場合、この罠は起きるでしょうか。実際に短いテスト・プログラムで確認し、なぜそうなるかを自分の言葉で説明してください。

3. 次に、`'ALHNSON'`という**同じ見た目の結果**を、今度は罠としてではなく**意図的に**作ってみてください。`%SUBST`を代入先に使うと、対象の一部分だけを明示的に書き換えられます(`%subst(name2 : 1 : 2) = 'AL';`のような形)。`MOVEL`の暗黙の挙動(結果フィールドの左から詰め、残りはそのまま)と、`%SUBST`を代入先に使う明示的な書き方の違いを説明してください。

4. (発展)`R0403A`にはもう1組、`CODE1`/`CODE2`(`MOVE`版、右から詰めて`'1234AB'`が残る罠)があります。同じ考え方で書き直してみてください。

## セルフチェック

- [ ] `%TRIM`/`%TRIML`/`%TRIMR`の違いを、実際の出力(`<`と`>`の間の空白の位置)から説明できる。
- [ ] `%SUBST`を式の中と、代入先の両方で使える(演習)。
- [ ] `%SCAN`で文字列中の位置を検索できる。
- [ ] `%CHAR`/`%DEC`で数値⇔文字列を変換できる。
- [ ] `%DATE`/`%DIFF`/`%DAYS`で日付の差を計算できる。
- [ ] RPG IIIの`MOVE`系の処理を、実際に`%BIF`で書き直せた(演習)。
- [ ] 式の中の桁あふれが実行時エラーになる(詳しくは06-09)ことを知っている。

## 片付け

作成したプログラム(`F0606A`)はそのまま残してください。ファイルの読み書きを行わないため、`TXRESET`は不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Built-in function (BIF) | 組み込み関数 |
| Trim | (前後の)空白除去 |
| Substring | 部分文字列 |
| Scan | 文字列検索 |
| Overflow | 桁あふれ |

次のレッスン(06-07)では、データ構造(DS)と配列を扱います。`qualified`なDSの意味も、そこで初めて詳しく説明します。

## 実機メモ

- 確認日: 2026-09-27。**`F0606A`を著者の検証ライブラリー`<USER>2`で実際に`CRTBNDRPG`でコンパイル(Highest Severity 00)し、`CALL`で実行して、上記11行がジョブ・ログに`CPF9898`として記録されることを確認した(`part06-0509-procs-files`、CONFIRMED SUCCESS、1回の接続)。V2まで確認済み。** 観測はスプール・ファイルではなく、接続の生ログ(runセクション)に直接現れたテキストを読んで確認したものである。このハーネスの非対話SSHジョブは、プログラム記述のプリンター・ファイル(`QSYSPRT`等。`dcl-f qsysprt printer(132) usage(*output);`のように`printer(132)`でレコード長を指定した、外部記述に頼らない形。04-01の`QSYSPRT`と同じ扱い)の実スプールを作らない(`CPYSPLF`/`WRKSPLF`は`CPF3303`で失敗する)。`F0606A`は最初から印刷を使わず`sendMsg`(ジョブ・ログ経由)だけで結果を出すため、この制約の影響を受けていない。**なお、この検証はハーネスが`CPYFRMSTMF`でソースを直接`<USER>2/QRPGLESRC`のメンバーへ取り込む経路(`ADDPFM`を介さず`MBROPT(*REPLACE)`で直接取り込み、`STMFCCSID`は指定しない——heredocで書き出した時点のCCSIDタグをそのまま使う)によるものであり、上の「実演」節が示す、読者自身が`<USER>1`へ`ADDPFM`してから、`git clone`済みツリーを`STMFCCSID(1208)`付きで`CPYFRMSTMF`する手順そのものを実行して確認したわけではない。ソース・ファイルの内容自体は同一だが、経路(`ADDPFM`の有無)・対象ライブラリー・CCSIDの扱いが異なるため、実演の手順そのものをたどった場合の結果は未検証である。**
- **`src/qrpglesrc/f0606s.rpgle`自身のヘッダー・コメントは、今も「STATUS: hardware-UNTESTED (Part 6 draft).」という記述のままだが(この接続=`part06-0509-procs-files`はまだこれから、という趣旨のコメントである)、上記のとおりこれは古い記述で、実際にはV2まで確認済みである**(`04-08`が自分自身の実機メモを後から訂正したのと同じ状況)。ソース自身のヘッダー・コメントの書き換えは本レッスンの担当範囲外なので、ここでは食い違いの指摘のみ残す(次回このソースを触る際に直してほしい)。
- ソース中に残っていた2件のTODOコメント(`%triml`/`%trimr`が実際にどちら側の空白を残すか未確認、`%date`/`%diff`/`%char(date)`の`*ISO`表示形式が未確認、としていた部分)は、上記の実測結果(`triml <Taro              >.`/`trimr <  Taro>.`/`dueDate = 2026-10-01.`)によってどちらも解消済みである。
- ウォームアップの問1(`dftactgrp(*no)`を書き忘れた場合の挙動)は、`part06-gen-probe`(5回の接続、確認日2026-09-26、5回目でCONFIRMED SUCCESS)の1回目の接続が実機で発見した`RNF1520`("The procedure cannot be defined with DFTACTGRP(*YES).")を根拠にしている(実機で確認したコンパイル時エラーそのものであり、スタイル・ガイドの`V1`——コンパイルが通り重大度が許容範囲であることの確認——とは性質が異なるため、ここでは`V1`表記を使わない)。同じ`part06-gen-probe`は、`%DATE`(このレッスンが使う`*ISO`形式ではなく`*YYMD`形式で試された)を含む12段階の機能梯子のうち、12段目の`ASSERT-T`(`CRTBNDRPG`と`CRTSQLRPGI`の両方で試験、このリポジトリーでは使用しない、PTF未到達)を除く11段階すべてが、現在のPUB400のPTFレベルで実機確認済みであることも示している(`%date`系BIF全般がこのPTFレベルで動くことの傍証として引用する)。
- 演習3の`%subst(name2 : 1 : 2) = 'AL';`という、代入先としての`%SUBST`の書き方自体は、[付録F](../appendix/f-bif-reference.md)の一次資料の記述に基づく一般知識であり、`F0606A`自身はこの書き方を実演していない(未検証)。実際に試して、自分の実行結果で確認してください。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
