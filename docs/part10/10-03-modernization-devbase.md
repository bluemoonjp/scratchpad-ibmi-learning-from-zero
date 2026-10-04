# 10-03 近代化と開発基盤: 課題C・課題D

> 所要時間: 240分(**逼迫します**。第10部で最長。240分は、詰まらない場合の最速の目安です。詰まる想定で2回に分けてください(区切りは手順9のあと)。目安の内訳は「なぜ学ぶか」の直後の表。時間は著者の見積もりで、通しで計った値ではありません。未検証(2026-09-30時点)) / 前提レッスン: 10-01・05-13(RPG III を通らないルートでは [04-27](../part04v/04-27-route-preparation.md)。あわせて、旧 `ZA0500` を読むために [04-25](../part04v/04-25-cycle-and-control-levels.md))・07-05・08-02・08-03・08-04(**演習で`TSTZAISRV`まで作ってあること**。無いまま進むと`PASS`は38ではなく27になるはずです。未検証(2026-09-30時点))・08-05b・08-08(部の扉は[第10部](index.md)。10-02は、このレッスンには必須ではありません) / 目標番号: 5・6(ロードマップの目標5=課題C、目標6=課題D。このレッスン内の確認 ID は下の 10-03-1〜3) / 観測方法: `JU0900C`が印字する12行(V2はバッチが取り込んだ印字文。実スプールの一致はV3)・`RUNTEST`が送る1件のメッセージ(ジョブ・ログ)・`TESTRES`の集計(V2はバッチの取り込み。SSHの`db2`の形は未検証(2026-09-30時点))・`TXCHECK`のメッセージ(ジョブ・ログ)・`makei build`の標準出力・`OBJECT_STATISTICS`の`OBJATTRIBUTE`(V2はバッチの取り込み) / 道具: 5250(差し替え・テスト・`TXCHECK`)、SSH(`db2`・`makei`・作業用ディレクトリーの操作)、PC(`rpglint`。V3) / 同時接続数: 5250×1 + SSH×1(PC側の`rpglint`はPUB400に接続しません。**PCからgitで送るときは、PCが3本目のSSH接続を張ります。5250かqshの接続を1本閉じてから行います**。08-01・08-08) / 作る・変えるオブジェクト: `<自分のユーザー名>2`の`ZA0500`(旧プログラムを新プログラムに差し替え、最後に切り戻し)、`TSTZA0500`・`RUNTEST`(新規に作る)、`TESTKIT`一式(`TESTKIT`・`TESTKITBD`・`TSTJUCSRV`・`TSTZAISRV`)・`ZAISRVBD`・`JUCSRVBD`(開発用からの作業用の複製)、`QRPGLESRC`・`QCLSRC`の`TSTZA0500`・`RUNTEST`のメンバー、`TESTRES`、表`W1003A`・`W1003B`。`<自分のユーザー名>B`に`ZA0ORIG`(切り戻し用の控え)と、`makei`の作業用のオブジェクト(最後に名前で消します)。SSH側に作業用ディレクトリー`$HOME/za-work`と`$HOME/mk10`。PC側にREADMEを含む自分のリポジトリー。`TXCKM`に`10-03`の6行(共有の表は消しません)。**本文の`<自分のユーザー名>1`・`2`・`B`は、Part 9と同じ書き方で、それぞれ自分の開発用・本番役・控え(SAVFの置き場)のライブラリーを指します** / DBVER: 1(第10部の課題は`TXSTATE`を更新しません) / 依存するプローブ: バッチ`part10-03-modernize`(2026-09-30、2回の接続。1回目は検証の道具の不具合で一部が失敗し、直した2回目で`makei`以外の全項目を確認。`makei`の出力の中身は1回目の記録で確認し、2回目は実行して終了コード0までで、出力は詳しく見直していません。V2)。前提の再現(チケット1の`JU0900C`と旧`ZA0500`を作り直し、ゴールデン・マスターを取り直した)も、このバッチ自身で行いました(V2) / PTF 依存: 未検証(2026-09-30時点)(確認したのはPUB400の環境だけで、PTFレベルの下限は調べていません) / 容量の目安: わずか(記録していません。未検証(2026-09-30時点))

## ゴール

- 10-03-1(課題C): 旧`ZA0500`を、切り戻し用の控え`ZA0ORIG`を取ってから、SQL自由形式で書いた新`ZA0500`に差し替え、`*TEST`の12行が差し替え前と一致すること(OK 10・SHORT 2・NOTFOUND 0)と、`*LIVE`の在庫が旧プログラムと同じになること(`P00001`〜`P00006`が39・3・235・48・9・20)を確かめ、`ZA0ORIG`から切り戻せる。
- 10-03-2(課題D 前半): 1コマンドの`RUNTEST`で、3本のテスト(38アサーション)を1つのジョブで走らせ、`PASS`と`FAIL`の件数を1件のメッセージで読める。`TSTZA0500`の15件が何を確かめているか、なぜ`E1`が「ロックを漏らさない証明」ではないのかを説明できる。
- 10-03-3(課題D 後半): 作業用ディレクトリーから`makei build`で`ZAISRV`と`ZA0500`を作り直し、`rpglint`の結果を読んで直し、READMEとテスト結果を自分のリポジトリーに成果物として残せる。

## ウォームアップ

<details><summary>前回までの復習(07-05・08-05b・08-08)</summary>

1. (07-05)`reserve()`の`SHORT`の分岐に、どんな修正が入りましたか。なぜその分岐だけでしたか。
2. (08-05b)`Q0805B`は、`SHORT`のときのロックの後始末を、なぜあえて直さず引き継いだのですか。
3. (08-08)控えを取るときに`CRTDUPOBJ`の`NEWOBJ`で別名を付けるのは、なぜですか。

答え: 1. ロック付きの`CHAIN`が成功したあとの`SHORT`の分岐に、`UNLOCK`を1回追加しました。その分岐は確実にロックを持っているからです。`NOTFOUND`の分岐は、失敗した`CHAIN`が何もロックしないので不要でした。 2. `Q0805B`は「特性検定」(旧プログラムの出力を忠実に再現する)のための移植で、機能の改善が目的ではなかったからです。旧`ZA0500`に元からある`UNLOCK`の欠落も再現しました(08-05bは、それを直すと機能改善になるので見送ると書いています)。この課題で、その見送った点を直します。 3. 同じ名前の控えを別のライブラリーに置くと、そのライブラリーがライブラリー・リストに入った瞬間、名前を省いた呼び出しが控えの方を拾う危険があるからです。

</details>

## なぜ学ぶか

**このレッスンは、第10部で「読むだけ」に回せない課題です**([ロードマップ](../roadmap.md)の早回しルートも、10-03だけは省略しないと書いています)。目標5(現代的なRPGを書く)と目標6(開発基盤を整える)を、1本のプログラムの差し替えと、その周りの道具立てで同時に確かめるからです。

現場の近代化は、「新しく書き直す」よりも「**古いものと同じ答えを返すことを、機械的に示しながら、安全に差し替える**」ことの方が、ずっと難しく、ずっと多く求められます。このレッスンでは、次を通しでやります。

- 旧プログラムの出力を**ゴールデン・マスター**として採る(05-08・05-13で使った考え方)。
- 控えを取り(`ZA0ORIG`)、同じ名前の新プログラムに差し替え、出力が一致することを確かめ、戻せることまで確かめる。
- 「動いた」を人の目に頼らず、**1コマンドで再現できるテスト**(`RUNTEST`)にする。
- 別の人が、リポジトリーを取ってきて、ビルドとテストを再現できる**README**を残す。

第10部の残りの課題(10-04)は、ここで整える`ZAISRV`・`JUCSRV`・`TXCHECK`を土台に使います(片付けで消す作業用の複製の束縛ディレクトリーなどを、10-04が必要とするかは、確認していません。未検証(2026-09-30時点))。

時間の目安は次の表です(著者の見積もりで、実測ではありません。未検証(2026-09-30時点))。

| 区間 | 内容 | 目安 |
|---|---|---|
| 手順1〜5 | 状態の確認・ゴールデン・マスター・控え・部品 | 30分 |
| 演習(a) | 骨組みを埋めて新`ZA0500`を書く(コンパイルして直す往復を含む。1往復5〜10分の目安) | 70分 |
| 手順6〜9 | ビルド・`*TEST`の比較・`*LIVE`の比較・切り戻し | 40分 |
| 手順10〜11 | `TSTZA0500`(ソースを読む5分を含む)・`RUNTEST`・`TXCHECK` | 35分 |
| 手順12〜13 | 作業ディレクトリーと`makei` | 25分 |
| 演習(d)(e) | `rpglint`・README・テスト結果 | 30分 |
| 片付け | | 10分 |

**時間が足りなくなったら**: 演習(a)を書き切れないときは、骨組みのヒント1・2を使い、それでも終わらなければ模範解答を読んで手順6以降に進んでください(採点表の「実装」は△になります)。課題D(手順12以降)を最後まで通せないときは、READMEに、できたことと未検証のことを分けて書けば成果物になります。**手順1〜11(課題C・`RUNTEST`)は、削らないでください。**

## 新出

**中核概念は3つです。**

1. **名前を付けた控えを取ってから差し替える(カットオーバーとロールバック)。** 同じ名前(`ZA0500`)で置き換えるので、旧プログラムを別名(`ZA0ORIG`)で取っておかなければ、戻す手段がありません。
2. **1コマンドの回帰テスト(`RUNTEST`)。** 3本のテストを、決まった順序で、1つのジョブで走らせ、結果を1件のメッセージにまとめる。順序そのものに理由があります。
3. **再現できるビルドとREADME。** 「自分の環境で動いた」を、他の人が同じ手順で再現できる形にする。

**コマンド等の新出は3つです**(上限6の内側)。

- `CRTSQLRPGI`の`SRCSTMF`(ソースを、ソース・メンバーではなくIFSのファイルから読む指定。08-01は`SRCSTMF`を別のコマンドで扱いましたが、`CRTSQLRPGI`では初めてです)。
- `CRTSQLRPGI`の`CVTCCSID(*JOB)`(UTF-8のソース・ストリーム・ファイルを、ジョブのCCSIDに変換してコンパイルする指定。`SRCSTMF`と組み合わせます)。
- `DLTBNDDIR`(束縛ディレクトリーの削除。片付けで使います)。

**既習の応用(新出に数えません。各レッスンで既出)**:

- `CRTSQLRPGI ... OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)`(08-04・09の各レッスン)。
- `CRTDUPOBJ ... NEWOBJ(...)`・切り戻し(08-08)。`CRTDUPOBJ`には`REPLACE`が無いので、先に消します。
- 2カーソルのマージ(08-05b)。`get()`・`reserve()`(07-05)。
- `CHGCURLIB`・`DELETE FROM TESTRES`の順序・`OVRDBF ... OVRSCOPE(*JOB)`による`ZAIKOM`の隔離(08-04)。
- `makei`・`iproj.json`・`Rules.mk`(08-02)、`rpglint`(08-03)。
- `TXRESET`・`TXCHECK`(05-13・07-05・08-08・10-01)。`TXLOAD`は、作ってある場合だけの別の形として手順10に載せています(この教材に作る手順は無く、実行していません)。`SBMJOB`(10-01。`INQMSGRPY(*DFT)`と`LOG(4 00 *SECLVL)`を必ず付ける)。
- `EXCEPT`による比較(05-08)。

**読解用(自分で書けなくて構いません。数に入れません)**: `makei`の`COMPILEOPT`と`iproj.json`の`postUsrlibl`(手順12・13)、`RUNTEST`のCLの中身(下の「説明」。中の`RTVMBRD ... NBRCURRCD(&変数)`は、メンバーの現在のレコード数をCLの変数に取り、`PASS`と`FAIL`の件数を数えるのに使っています)、`Rules.mk`の4行。

## 説明

### 差し替える対象の「契約」

`JU0900C`は、`&LIB/ZA0500`を名前で呼びます(`CALL PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)`。10-01で直した`JU0900C`のソースの行)。新しい`ZA0500`が守る契約は、次のとおりです。

| 項目 | 契約 |
|---|---|
| プログラム名 | `ZA0500`(同じ名前でなければ、`JU0900C`は呼びません) |
| 引数 | `RMODE` `CHAR(10)`、`MINQTY` `PACKED(5:0)`(10-01で直した`JU0900C`が渡す型。**読んで確かめます**。手順2) |
| 実行の規則 | 余裕 = 在庫 − 数量。余裕が`MINQTY`未満なら`SHORT`。そうでなければ`OK`で、`RMODE`が`*LIVE`のときだけ在庫を減らす。`ZAIKOM`に行が無ければ`NOTFOUND` |
| ドライ・ラン | `*LIVE`以外の`RMODE`は、`ZAIKOM`に一切触れない |
| 印字 | 1行に、受注番号(1桁目)・商品(9桁目)・数量(17桁目、5桁ゼロ埋め)・状態(30桁目にそろえる)。これは旧プログラムの出力と同じです |

**実行モードに注意してください。** `JU0900C`は、`*LIVE`以外の実行モードをドライ・ランとして扱い、実行モードを省くと`*LIVE`(在庫を実際に減らす)になります(ソースの読み取り)。**このレッスンの`JU0900C`の呼び出しには、必ず`'*TEST'`または`'*LIVE'`と、ライブラリー名を付けます。**

Windows・Linuxの言葉で言えば、同名の差し替えは、動いているサービスの実行ファイルを入れ替える(旧版を`.bak`で取っておく)作業に近いものです(一般的なたとえで、実機の確認ではありません)。IBM iでは、旧版を**別名で別のライブラリーに**置くのがこの教材の作法です(08-08)。

### 新`ZA0500`の設計判断

新しい`ZA0500`は、08-05bの`Q0805B`(2カーソル・マージ)に、07-05の`ZAISRV`(`get()`・`reserve()`)を組み合わせて作ります。旧プログラムと違う点は、次のとおりです。

1. **余裕の判定は、ロックしない覗き見(`get()`。07-05)の値で行う。** `SHORT`の行は、ロックを一切持ちません。`Q0805B`が引き継いだ「`SHORT`のときのロックの後始末の欠落」は、ここでは起きない作りにします(08-05bが見送った点を、この課題で直します)。
2. **`reserve()`は、判定が通り、かつ`RMODE`が`*LIVE`のときだけ呼ぶ。** `reserve()`はロックし、もう一度確かめ、更新し、`SHORT`の分岐では自分でロックを外します(07-05)。`ZA0500`自身は`ZAIKOM`を`dcl-f`せず、`ZAISRV`だけを通して触るので、`ZA0500`が抱えるロックがそもそもありません。
3. **`reserve()`が`*off`を返した場合の扱いは、演習(a)のTODO 6で自分で決めます。** 決めた理由は、採点表の「ロックの扱い」で説明します。**この「`*off`が返る」経路は、検証では通っていません**(未検証(2026-09-30時点))。

### `JU0900C`の`OVRDBF`・`OPNQRYF`と、埋め込みSQLのカーソル

`JU0900C`は、`JUCHUD`を`OVRDBF ... SHARE(*YES)`と`OPNQRYF`で開いてから`ZA0500`を呼びます。旧`ZA0500`は、その開いたものを、そのまま読みます。新`ZA0500`は、埋め込みSQLのカーソル(`SELECT ... FROM JUCHUD ORDER BY JUNO, JULINE`)で読みます。

**検証では、このカーソルは開けて、出力は旧プログラムと同じでした(V2)。** ただし、SQLのカーソルがその上書きを尊重したのか、共有の開いた状態を再利用したのかは、切り分けていません(上書きの先が同じライブラリーだったため)。設計上は、`ORDER BY`を付けてあるので、どちらでも行の順序は変わりません(設計の意図で、これも確かめていません)。付随する観察が1つあります。旧プログラムの実行では、ジョブ・ログに`CPF4123`(メッセージ本文は、共有の開きで、開きのオプションが無視された、という意味)が2回出ました(切り戻し後の旧の実行でも出ました)。新プログラムの実行では出ませんでした。**なぜ旧だけで出るのかは確かめていません**(未検証(2026-09-30時点))。

### ゴールデン・マスターと、`*LIVE`で違うところ

`*TEST`の12行は、次のとおりです(旧`ZA0500`の出力で、新プログラムの出力もこれと一致しました)。

```text
 J00001  P00001  00002       OK
 J00001  P00003  00005       OK
 J00002  P00002  00001    SHORT
 J00003  P00004  00010       OK
 J00003  P00005  00003       OK
 J00004  P00001  00001       OK
 J00005  P00006  00002       OK
 J00005  P00003  00010       OK
 J00006  P00002  00002    SHORT
 J00007  P00005  00005       OK
 J00008  P00001  00003       OK
 J00008  P00004  00002       OK
```

先頭の空白1つは、検証で取り込んだ印字文にあった形です。**実際のスプール・ファイルにも同じ空白があるかは、確かめていません**(未検証(2026-09-30時点))。旧と新を同じ画面・同じ見方で比べれば、あってもなくても比較はできます。件数は、`OK`が10、`SHORT`が2、`NOTFOUND`が0です。

`*LIVE`では、ちょうど1行だけ違います。`J00007`の`P00005`が`SHORT`になります。

```text
 J00007  P00005  00005    SHORT
```

`*TEST`は在庫を減らさないので、`J00003`の3個を引いても在庫は12のままで、12 − 5 = 7 ≥ 5 で`OK`です。`*LIVE`では`J00003`で3個減って9になるので、9 − 5 = 4 < 5 で`SHORT`です。**旧プログラムも新プログラムも、同じ12行(この1行だけ違う)を印字しました(V2)。** 「差分が出た」ことではなく、「差分の理由を説明できる」ことが、特性検定の目的です。

### `RUNTEST`の作りと、順序の理由

`RUNTEST`(`solutions/10-03/runtest.clp`)は、次の順序で動きます。**順序を変えると壊れます。**

1. `CHGCURLIB`が最初。`TESTKIT`は`TESTRES`を、ライブラリーを付けない`CREATE TABLE`で作るので、`TESTRES`は現行ライブラリーにできます(08-04)。
2. `DELETE FROM TESTRES`が次。`testInit()`は表が無ければ作るだけで、中身は消しません。消さなければ、前の実行の行まで数えてしまいます。
3. `ZAIKOM`を`QTEMP`に複製し、`OVRDBF ... OVRSCOPE(*JOB)`で向ける。テストが共有の`ZAIKOM`を変えないためです。`QTEMP`も上書きも、このジョブの中だけのものなので、3本のテストは同じジョブから呼びます。
4. `TSTJUCSRV`・`TSTZAISRV`・`TSTZA0500`を呼ぶ。
5. 上書きと複製を消し、`TESTRES`の`PASS`と`FAIL`を数え、次の1件のメッセージを送る。

```text
RUNTEST: PASS=0000000038 FAIL=0000000000
```

数は10桁のゼロ埋めです。**エスケープ・メッセージは送りません**(失敗しても呼び出し側を止めない)ので、`FAIL`の数を読んでください。

検証の1回目で、`DELETE`の文が、`'DELETE FROM ' *TCAT %TRIM(&LIB)`の形で組んであり、`*TCAT`が左のリテラルの末尾の空白を削ったため、`FROM`とライブラリー名がくっついて`SQL0104`・`SQL0204`になりました(V2で再現)。`*CAT`に直して、2回目で通りました(`solutions/10-03/runtest.clp`は直した形です)。**文字列の連結で末尾の空白を残したいときは`*CAT`です。**

### `TSTZA0500`の15件

`TSTZA0500`は、本物の`JUCHUD`・`JUCHUM`に対して本物の`ZA0500`を呼び、残った在庫を確かめます(`RUNTEST`が`QTEMP`の複製に向けたあとで呼びます。**単独で呼ぶと共有の`ZAIKOM`を書き換えるので、必ず`RUNTEST`経由にしてください**)。どのケースも、最初に6商品の在庫を初期値(45・3・250・60・12・22)に戻します。

| ケース | 確かめること | 期待値 |
|---|---|---|
| A1・A2 | `*TEST`の実行のあと、`P00001`と`P00005`が変わらない | 45・12 |
| B1〜B6 | `*LIVE`の実行のあとの`P00001`〜`P00006` | 39・3・235・48・9・20 |
| C1・C2 | 余裕がちょうど`MINQTY`になる境界。`P00002`の在庫が6なら`OK`で5になり、5なら`SHORT`で5のまま | 5・5 |
| D1〜D3 | `QTEMP`の複製から`P00006`の行を消すと、`get()`が`-1`を返し(D1)、実行は最後まで終わり(D2)、他の商品は正しい(D3。`P00001`が39) | -1・Y・39 |
| E0・E1 | E0は確認用に開いたファイルが開けたこと。E1は、`SHORT`の商品を更新用に読んでも「レコード使用中」にならないこと | Y・Y |

**E1は「ロックを漏らさない証明」ではありません(見張り役です)。** `ZA0500`は`ACTGRP(*NEW)`で動くので、戻った時点で活動化グループごと消え、ロックが残りようがないからです。漏らさないという主張の根拠は、作り(`SHORT`の経路は覗き見だけで、`reserve()`は自分の`SHORT`の分岐でロックを外す)と、**同じジョブで`JU0900C`を2回呼んで、2回目も正常だったこと**です(V2)。

### 確認の範囲(先に全体像)

| 項目 | 確認の程度 |
|---|---|
| `CRTSQLRPGI`(メンバーから)で新`ZA0500`が`00`で作れる。`SRCSTMF`と`CVTCCSID(*JOB)`でも`00`で作れる(作業用の別名のプログラムで。実行はしていない) | V2(バッチ`part10-03-modernize`、2026-09-30) |
| `*TEST`の12行が、旧・新・新の2回目の呼び出し・切り戻し後の4回とも同じ。`*LIVE`は旧・新とも同じ12行 | V2(ハーネスが取り込んだ印字文。**実際のスプール・ファイルの一致は未確認**) |
| `*LIVE`のあとの在庫が旧・新とも39・3・235・48・9・20。`EXCEPT`の差が両方向とも0行 | V2 |
| `RUNTEST`が`PASS=0000000038 FAIL=0000000000`を送る。`TESTRES`が38行すべて`PASS` | V2(CLラッパーの中の1つのジョブ) |
| `TXCHECK LESSON('10-03')`が6件`PASS`・0件`FAIL` | V2(専用のヘルパー経由) |
| `makei build`が成功し、`ZAISRV`と`ZA0500`が作れる | V2(1回目の出力を確認。2回目も実行して終了コード0で、出力は詳しく見直していません。`ctl-opt`の2つのキーワードを外したコピーで。下の手順13) |
| 5250の画面から打つ形、`SBMJOB`で流してスプールを読む形、`TXSNAP`・`CMPPFM`、`TXLOAD`の`RUNTEST`、`rpglint`、README | **V3または未検証**(下の実機メモ) |

## 実演

**前提となる状態**: 10-01の手順4〜6(`TXLEGACY`・`TXRESET`・チケット1の修正)が済んでいて、`<自分のユーザー名>2`の`JU0900C`が05-13のチケット1の修正版、`ZA0500`が旧プログラム(`TXLEGACY`で再構築したもの。チケット3の`*PSSR`は入れない)であること。10-01の障害の行(`J00000`・`C05119`)が消えていること。自信がなければ、[10-01](10-01-preparation-incident.md)の手順4〜6と片付けをやり直してください。`(5250)`は5250、`(SSH)`はSSH(接続後に`qsh`を入力して、qshの中で実行します。`db2`はqshのコマンドです)、`(PC)`はPC側の操作です。

**警告(共有データ)**: 手順の`*LIVE`の実行は、`<自分のユーザー名>2`の`ZAIKOM`を書き換えます。必ず`TXRESET`で戻してから次に進みます。`JU0900C`を、実行モードなしで呼ばないでください。

**検証の範囲**: 以下の結果は、バッチ`part10-03-modernize`(CLラッパーの1つのジョブの中で、`JU0900C`を直接`CALL`し、印字文を取り込んだ)によるものです。**5250から`SBMJOB`で流してスプールを読む形は、確かめていません**(V3)。

<details><summary>RPG III を通らないルートの人へ(旧 <code>ZA0500</code> も <code>RPGLE</code> になります)</summary>

このルートでは、旧システムの `ZA0500` は固定形式 RPG IV(`CRTBNDRPG`)版です(ソースは `src/legacy/qrpgle112/za0500.rpgle`、`<自分のユーザー名>2` の `QRPGLE112` のメンバー。[04-27](../part04v/04-27-route-preparation.md))。前提は [10-01](10-01-preparation-incident.md) の囲みのとおりで、`<自分のユーザー名>2` の `TXLEGLNG` が `*RPGLE` であることを、先に確かめてください。

**困ること: 本文は、新旧を `OBJATTRIBUTE` で見分けています。** 旧が `RPG`、新が `RPGLE` だからです(手順1・6・9・9b と片付け)。ルートでは、旧も新も `RPGLE` なので、この印では見分けられません。`OBJATTRIBUTE` の問い合わせは、ルートでは「RPG III のプログラムが残っていない(すべて `RPGLE`)」ことの確認として使います([04-27](../part04v/04-27-route-preparation.md) の A5)。

**ルート版の印: `BOUND_SRVPGM_INFO` の `ZAISRV` の行を使います。** 実機で確認(part10-03-rpgle、2026-10-04)。`OBJECT_STATISTICS` の `OBJATTRIBUTE` は、新旧とも `RPGLE` で、見分けに使えません。`OBJTEXT` も、見分けの印には使いません(下の表のとおり、新でテキストを付けなかっただけの差とみられます。付ければ消えるかは確かめていません(未検証(2026-10-04時点)))。

実機で、旧(`QRPGLE112` のメンバーから `CRTBNDRPG` で作ったもの)・新(手順6の `CRTSQLRPGI`。`ZAISRV` を束縛)・切り戻し後の3つを比べました。

| 見る場所 | 旧 | 新 | 切り戻し後 |
|---|---|---|---|
| `OBJECT_STATISTICS` の `OBJATTRIBUTE` | `RPGLE` | `RPGLE` | `RPGLE` |
| 同じく `OBJTEXT` | `Stock allocation` | 空(バッチの `CRTSQLRPGI` に `TEXT` を付けなかったため) | `Stock allocation` |
| `BOUND_SRVPGM_INFO` の行数 | 4(いずれも `QSYS` の `QRNXIE`・`QRNXIO`・`QRNXUTIL`・`QLEAWI`) | **5(上の4つ + `ZAISRV`。`BOUND_SERVICE_PROGRAM_LIBRARY` は `*LIBL`)** | 4 |
| `BOUND_MODULE_INFO` の行数 | 1(`ZA0500`。`BOUND_MODULE_LIBRARY` は `QTEMP`、`MODULE_ATTRIBUTE` は `RPGLE`) | 1(同じ値) | 1 |
| 同じく `SOURCE_FILE`・`SOURCE_FILE_MEMBER` | `QRPGLE112`・`ZA0500` | `QRPGLESRC`・`ZA0500`(バッチはソース・メンバーから作った) | `QRPGLE112`・`ZA0500` |
| 同じく `SQL_STATEMENT_COUNT` | 0 | 10 | 0 |
| 同じく `NUMBER_PROCEDURES` | 4 | 9 | 4 |
| `PROGRAM_INFO` の `ACTIVATION_GROUP` | `*DFTACTGRP` | `*NEW` | `*DFTACTGRP` |
| 同じく `SERVICE_PROGRAMS`・`MODULES` | 4・1 | 5・1 | 4・1 |

`BOUND_MODULE_INFO` の `MODULE_ATTRIBUTE` は、新旧とも `RPGLE` で、印になりません。`BOUND_SRVPGM_INFO`・`BOUND_MODULE_INFO`・`PROGRAM_INFO` の `WHERE` に使う列は、実機で `PROGRAM_LIBRARY` と `PROGRAM_NAME` で正しいことを確認しました(バッチはどれも `RUNSQL` の `INSERT ... SELECT * ... WHERE PROGRAM_LIBRARY = ... AND PROGRAM_NAME = 'ZA0500'` で取り込みました)。**切り戻し後は、3つの見る場所とも旧と同じ値に戻りました。**

```sh
db2 "SELECT BOUND_SERVICE_PROGRAM_LIBRARY, BOUND_SERVICE_PROGRAM FROM QSYS2.BOUND_SRVPGM_INFO WHERE PROGRAM_LIBRARY = '<自分のユーザー名>2' AND PROGRAM_NAME = 'ZA0500' AND BOUND_SERVICE_PROGRAM = 'ZAISRV'"
```

期待される結果: 新は `*LIBL`・`ZAISRV` の1行、旧と切り戻し後は `0 RECORD(S) SELECTED`。補助に、`SQL_STATEMENT_COUNT`(`BOUND_MODULE_INFO`。0 なら埋め込みSQLなし、新は 10)も使えます。(ライブラリー名は大文字で書きます。**この `db2` の形をSSHで打った実行は確認していません。実機で確認したのは、同じ `WHERE` の問い合わせをバッチの SQL として実行した結果です。未検証(2026-10-04時点)**。**`makei` で作った新 `ZA0500`、`SRCSTMF` の形で作った新 `ZA0500` で、この印が同じに出るか、`SOURCE_STREAM_FILE_PATH` に何が入るかは、確かめていません(バッチはソース・メンバーから `CRTSQLRPGI` で作りました)。未検証(2026-10-04時点)**。`ZAISRV` を束縛するのは、ソースの `ctl-opt bnddir` による設計なので、`makei` の形でも出るはずです。)

補助にならないもの: 手順3・7の `*TEST` の12行は新旧で一致する設計で、旧の ILE 版も RPG III 版と同じ12行でした(下のとおり)。`TSTZA0500` の `B`・`C` のケースも、旧で通りうる(手順9b)ので、決め手になりません。

**手順ごとの読み替え**:

- 手順1: `ZA0500` の `OBJATTRIBUTE` は `RPGLE` です(旧。実機で確認(part10-03-rpgle、2026-10-04))。上の印で、この時点の `ZA0500` に `ZAISRV` の行が**無い**ことを控えておきます(あとの比較の基準になります)。
- 手順6・9b: 新に差し替わったことは、`OBJATTRIBUTE` ではなく、上の印(`BOUND_SRVPGM_INFO` に `ZAISRV` の行が出る)で確かめます。`RNS9304` と最高重大度 `00` は、そのまま使えます(バッチでも `Program ZA0500 placed in library ... 00 highest severity` が出ました)。
- 手順9(切り戻し)と片付け1・8: `OBJATTRIBUTE` は `RPGLE` のまま変わりません。**旧に戻ったことは、`ZAISRV` の行が消えたことと、12行の一致で確かめます。** バッチでは、切り戻し後に `ZAISRV` の行が消え(4行)、12行も旧と同じでした。
- 演習(a)の旧 `ZA0500` の規則(05-03 の読み方)は、ルートでは [04-25](../part04v/04-25-cycle-and-control-levels.md) で `za0500.rpgle` を読んで確かめます。

旧 RPG IV 版 `ZA0500` の `*TEST` の出力は、RPG III 版と同じ12行(`OK` 10・`SHORT` 2。`SHORT` は `J00002`・`J00006`)でした。実機で確認(part05-lggold、2026-10-04)。

**旧 ILE 版 `ZA0500` の確認(実機で確認(part10-03-rpgle、2026-10-04))**:

- `*TEST` の12行は、このレッスンの12行(ゴールデン・マスター)と、空白を除いて一致しました。新(手順6)も、切り戻し後も同じです。
- `*LIVE` の在庫は、旧・新とも `P00001`〜`P00006` が 39・3・235・48・9・20で、RPG III 版の実測と同じでした。旧と新の `EXCEPT` の差は0行です。`*LIVE` の12行は、旧と新で同一で、`J00007` が `SHORT` になります(`*TEST` では `OK`)。
- **`CPF4123`**(`Open options ignored for shared open of member JUCHUD.`)は、旧 ILE 版でも出ました。**ジョブ・ログに1回**(`*TEST` のジョブ、`*LIVE` のジョブ、切り戻し後の `*TEST` のジョブのそれぞれ。メッセージの宛先は `ZA0500` で、送り元はシステムの `QDBSOPEN`。診断・重大度40)。新では、`*TEST`・`*LIVE` のどちらでも出ませんでした。本文(RPG III 版)の「2回」とは回数が違いますが、「旧で出て、新で出ない」ことは同じです。なぜ旧だけで出るかは、確かめていません(未検証(2026-10-04時点))。

</details>

1. **(5250) 状態を揃えます。** 現行ライブラリーを`<自分のユーザー名>2`にし、データを初期状態に戻します。

   ```text
   CHGCURLIB CURLIB(<自分のユーザー名>2)
   TXRESET LIB(<自分のユーザー名>2)
   ```

   (SSH)件数と、`ZA0500`が旧プログラムであることを確かめます。

   ```sh
   db2 "SELECT (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUM) AS M, (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUD) AS D, (SELECT COUNT(*) FROM <自分のユーザー名>2.ZAIKOM) AS Z FROM SYSIBM.SYSDUMMY1"
   db2 "SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*PGM')) X WHERE OBJNAME IN ('JU0900C', 'ZA0500')"
   ```

   `TESTRES`が`<自分のユーザー名>2`に**既にあるか**も、ここで確かめて、控えておきます(片付け4で使います)。

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*FILE')) X WHERE OBJNAME = 'TESTRES'"
   ```

   0行なら、`TESTRES`はこのレッスンで初めてできます。1行出たら、以前から使っている表です(08-04など)。この問い合わせも、SSHでは実行していません(未検証(2026-09-30時点))。

   期待される結果: 1つ目は`8`・`12`・`6`。2つ目は、`ZA0500`の`OBJATTRIBUTE`が`RPG`(旧プログラムの印)。(RPG III を通らないルートでは、旧も`RPGLE`です。実機で確認(part10-03-rpgle、2026-10-04)。新旧の見分けは、上の「RPG III を通らないルートの人へ」の囲みの印を使います)`TXRESET`のあとの件数(8・12・6)と、初期の在庫(45・3・250・60・12・22)は、バッチで確認しました(V2)。`ZA0500`の`RPG`も、バッチの`OBJECT_STATISTICS`で確認した値です。ここに書いた`db2`の形の問い合わせそのものは、SSHでは実行していません(未検証(2026-09-30時点))。

2. **(SSH) `JU0900C`が渡す`MINQTY`の型を、読んで確かめます。** 新しい`ZA0500`の引数は、これに合わせます。

   ```sh
   cd $HOME/ibmi-kyozai && git sparse-checkout add solutions templates && git pull
   grep -n "MINQTY" $HOME/ibmi-kyozai/solutions/05-13/ju0900c-ticket1.clp
   ```

   (1行目は、Part 9の扉の形に`templates`を足したものです。`solutions/`が既にあれば、`templates/`だけが増えます。手順12と演習(d)が`templates/`を使います。実機では未検証(2026-09-30時点))。期待される結果は、`MINQTY`を含む数行のうち、44行目あたりに`DCL VAR(&MINQTY) TYPE(*DEC) LEN(5 0)`の行が見えることです。**これは、05-13の模範解答のファイル(10-01で当てた修正版と同じ内容)を読んでいます。`<自分のユーザー名>2`に入っている`JU0900C`そのものの宣言を読んだわけではありません**(その方法は確かめていません)。自分で直したソースを読むなら、自分のソース・メンバーを開きます。`LEN(5 0)`なら、新しい`ZA0500`は`packed(5:0)`です。**3桁と5桁が食い違ったまま、新`ZA0500`を差し替えると、05-13のチケット1と同じ食い違いになるはずです**(新プログラムで再現するかは、確かめていません。未検証(2026-09-30時点))。

3. **(5250) ゴールデン・マスターを採ります。** 旧`ZA0500`で、`*TEST`を流します(`*TEST`は在庫を減らしません)。

   ```text
   SBMJOB CMD(CALL PGM(<自分のユーザー名>2/JU0900C) PARM('*TEST' '<自分のユーザー名>2')) JOB(T1003A) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)
   ```

   `WRKSPLF`で、そのジョブの`QSYSPRT`を`5`で開きます。期待される結果は、「ゴールデン・マスターと、`*LIVE`で違うところ」の12行(`OK`10・`SHORT`2)です。**この12行のスプールを、あとで新プログラムと見比べるので、消さずに残してください。** 05-08で覚えた`TXSNAP`で採る場合(RPG III を通らないルートでは、[08-05](../part08/08-05-control-level-refactor.md) の「05-08 の比較の方法」の囲みを読んでください。05-08 は読みません)は、`SPLF`のパラメーターに気を付けます(`TXSNAP`とその比較は、このレッスンでは実行していません。V3)。

4. **(5250) 控えを取ります。** 旧プログラムを`<自分のユーザー名>B`に`ZA0ORIG`の名前で複製します(名前が衝突しない別名です。08-08)。控えが既にあれば、先に消します。

   ```text
   DLTPGM PGM(<自分のユーザー名>B/ZA0ORIG)
   CRTDUPOBJ OBJ(ZA0500) FROMLIB(<自分のユーザー名>2) OBJTYPE(*PGM) TOLIB(<自分のユーザー名>B) NEWOBJ(ZA0ORIG)
   ```

   最初の`DLTPGM`は、控えが無ければ「見つからない」というメッセージで止まりますが、そのまま次に進んでかまいません(検証は、この部分を`MONMSG`で流しました)。`CRTDUPOBJ`が成功する形は、検証で確認しました(V2)。

5. **(5250と SSH) 作業用の部品を`<自分のユーザー名>2`にそろえます。** 新`ZA0500`は`ZAISRV`を、テストは`TESTKIT`・`JUCSRV`・`ZAISRV`を使い、いずれも同じライブラリーにある必要があります(`RUNTEST`が1つのライブラリーを指すため)。まず、あるものを確かめます。

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*ALL')) X WHERE OBJNAME IN ('JUCSRV', 'JUCSRVBD', 'ZAISRV', 'ZAISRVBD', 'TESTKIT', 'TESTKITBD', 'TSTJUCSRV', 'TSTZAISRV') ORDER BY OBJNAME"
   ```

   期待される結果は、8つすべて(`*SRVPGM`は`JUCSRV`・`ZAISRV`・`TESTKIT`、`*BNDDIR`は`JUCSRVBD`・`ZAISRVBD`・`TESTKITBD`、`*PGM`は`TSTJUCSRV`・`TSTZAISRV`)です。08-08で昇格したのは`JUCSRV`と`ZAISRV`だけなので、残りは無いはずです。無いものを、開発用から複製します(08-08と同じ形。`CRTDUPOBJ`は上書きしないので、あれば先に消します)。

   ```text
   CRTDUPOBJ OBJ(ZAISRVBD) FROMLIB(<自分のユーザー名>1) OBJTYPE(*BNDDIR) TOLIB(<自分のユーザー名>2)
   CRTDUPOBJ OBJ(JUCSRVBD) FROMLIB(<自分のユーザー名>1) OBJTYPE(*BNDDIR) TOLIB(<自分のユーザー名>2)
   CRTDUPOBJ OBJ(TESTKIT) FROMLIB(<自分のユーザー名>1) OBJTYPE(*SRVPGM) TOLIB(<自分のユーザー名>2)
   CRTDUPOBJ OBJ(TESTKITBD) FROMLIB(<自分のユーザー名>1) OBJTYPE(*BNDDIR) TOLIB(<自分のユーザー名>2)
   CRTDUPOBJ OBJ(TSTJUCSRV) FROMLIB(<自分のユーザー名>1) OBJTYPE(*PGM) TOLIB(<自分のユーザー名>2)
   CRTDUPOBJ OBJ(TSTZAISRV) FROMLIB(<自分のユーザー名>1) OBJTYPE(*PGM) TOLIB(<自分のユーザー名>2)
   ```

   **確認の範囲**: この複製の手順を、実機で通してはいません(未検証(2026-09-30時点))。バッチは、同じ部品を`<自分のユーザー名>2`に相当するライブラリーに、ソースからビルドしました(バッチが開発用のライブラリーに触れないようにするため)。複製後の`OBJECT_STATISTICS`の問い合わせで、8つそろったことを確かめてください。開発用に`TESTKIT`などが無ければ、08-04・07-05の手順で先に作ります。

   **ここで、演習(a)に進みます。** 新しい`ZA0500`を書いてから、手順6に戻ってください。

6. **(5250) 新`ZA0500`をビルドします。** 演習(a)で書いたソースを、SSHの作業用ディレクトリー`$HOME/za-work/za0500s.sqlrpgle`(演習(a)の最初に作ります)から、そのままコンパイルします。ライブラリー・リストの先頭に`<自分のユーザー名>2`があること(手順1の`CHGCURLIB`)を確かめてから、実行します。

   ```text
   CRTSQLRPGI OBJ(<自分のユーザー名>2/ZA0500) SRCSTMF('/home/<自分のユーザー名>/za-work/za0500s.sqlrpgle') OBJTYPE(*PGM) COMMIT(*NONE) CVTCCSID(*JOB) REPLACE(*YES)
   ```

   ホーム・ディレクトリーの名前は、SSHで`echo $HOME`で確かめて書き換えてください。コマンドが1行に入らなければ、`CRTSQLRPGI`とだけ打って`F4`でプロンプトし、値を1つずつ埋めます(一般知識。未検証(2026-09-30時点))。**`COMMIT(*NONE)`を省くと失敗します**(既定の`*CHG`は`SQL7008`・`CPF4328`になる。08-04)。**`CRTSQLRPGI`には`TGTCCSID`も`BNDDIR`もありません**(下のメッセージ表)。束縛ディレクトリーは、ソースの`ctl-opt bnddir('ZAISRVBD')`に書いてあります。

   期待される結果(ジョブ・ログ): `Program ZA0500 placed in library ...`(`RNS9304`)と、最高重大度`00`。**確認の範囲**: 検証は、この`CRTSQLRPGI`を、ソース・メンバーから(`SRCFILE`・`SRCMBR`の形)行い、そのプログラムを実行しました(V2)。`SRCSTMF`・`CVTCCSID(*JOB)`の形は、作業用の別名のプログラムを`00`で作れたところまでです(そのプログラムは実行していません)。また、`SRCSTMF`の形の検証には`REPLACE(*YES)`を付けていません(付けた形は未検証(2026-09-30時点))。上のコマンドをそのまま5250で打った実行は、確認していません(未検証(2026-09-30時点))。メンバーから作る形は、`CRTSQLRPGI OBJ(<自分のユーザー名>2/ZA0500) SRCFILE(<自分のユーザー名>2/QRPGLESRC) SRCMBR(ZA0500) OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)`です(ソースをメンバーに取り込む手順は08-04と同じ)。

   **コンパイルが失敗したとき**: `DSPJOBLOG`の最後のほうにある`SQL`・`RNF`・`RNS`で始まるメッセージと、`WRKSPLF`に出るコンパイル・リストの`*RNF`・`*SQL`の行を読みます。**最初のエラーだけを直して、もう一度コンパイルします**(あとのエラーは、最初のエラーから連鎖することが多いためです。一般知識。この教材の検証では、学習者が書いたソースのコンパイルは通していません。未検証(2026-09-30時点))。直すのは`$HOME/za-work/za0500s.sqlrpgle`です。

   (SSH)属性を確かめます。

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*PGM')) X WHERE OBJNAME = 'ZA0500'"
   ```

   期待される結果: `OBJATTRIBUTE`が`RPGLE`(**`SQLRPGLE`ではありません**。埋め込みSQLの`*PGM`も`RPGLE`と出ました。V2)。旧プログラムの`RPG`から変わったことが、差し替えの目印です。(RPG III を通らないルートでは、この印は使えません。実機で確認(part10-03-rpgle、2026-10-04)。上の「RPG III を通らないルートの人へ」の囲みの `ZAISRV` の行で確かめます)

7. **(5250) `*TEST`で比べます(特性検定)。**

   ```text
   SBMJOB CMD(CALL PGM(<自分のユーザー名>2/JU0900C) PARM('*TEST' '<自分のユーザー名>2')) JOB(T1003B) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)
   ```

   `WRKSPLF`で、新しいジョブの`QSYSPRT`を開き、手順3の12行と、1行ずつ見比べます。期待される結果: 12行が同じ(`OK`10・`SHORT`2・`NOTFOUND`0)。**同じジョブで`JU0900C`を続けて2回呼んでも、2回目が正常に終わりました**(V2。ロックや開いたままの残りの症状は出なかった)。これは、`SHORT`の経路がロックを持たない、という主張の根拠の1つです。**実際のスプール・ファイルの一致は、確かめていません**(ハーネスが取り込んだ印字文の一致がV2)。

8. **(5250と SSH) `*LIVE`で、旧と新の在庫を比べます。** 同じ操作を、旧と新で繰り返し、`ZAIKOM`の在庫を2つの表に取って`EXCEPT`で比べます。旧`ZA0500`は`ZA0ORIG`にあり、今動いているのは新`ZA0500`なので、まず切り戻して旧を動かします(手順9の形)。

   1. 旧を動かします(切り戻し)。

      ```text
      DLTPGM PGM(<自分のユーザー名>2/ZA0500)
      CRTDUPOBJ OBJ(ZA0ORIG) FROMLIB(<自分のユーザー名>B) OBJTYPE(*PGM) TOLIB(<自分のユーザー名>2) NEWOBJ(ZA0500)
      TXRESET LIB(<自分のユーザー名>2)
      SBMJOB CMD(CALL PGM(<自分のユーザー名>2/JU0900C) PARM('*LIVE' '<自分のユーザー名>2')) JOB(T1003C) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)
      ```

   2. ジョブが終わってから、在庫を表`W1003A`に取ります(表が無いと最初の`DROP`は失敗しますが、そのまま進みます)。

      ```text
      RUNSQL SQL('DROP TABLE <自分のユーザー名>2/W1003A') COMMIT(*NONE)
      RUNSQL SQL('CREATE TABLE <自分のユーザー名>2/W1003A AS (SELECT ZASHO, ZASU FROM <自分のユーザー名>2/ZAIKOM) WITH DATA') COMMIT(*NONE)
      ```

      **`CREATE OR REPLACE TABLE ... AS (...) WITH DATA`は使えません**(`SQ20038`。検証で確認)。`DROP`してから`CREATE`します。

   3. 新に差し替えて、同じことを繰り返します。`TXRESET`で在庫を戻すのを忘れないでください。

      ```text
      TXRESET LIB(<自分のユーザー名>2)
      DLTPGM PGM(<自分のユーザー名>2/ZA0500)
      CRTSQLRPGI OBJ(<自分のユーザー名>2/ZA0500) SRCSTMF('/home/<自分のユーザー名>/za-work/za0500s.sqlrpgle') OBJTYPE(*PGM) COMMIT(*NONE) CVTCCSID(*JOB) REPLACE(*YES)
      SBMJOB CMD(CALL PGM(<自分のユーザー名>2/JU0900C) PARM('*LIVE' '<自分のユーザー名>2')) JOB(T1003D) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)
      ```

      ジョブが終わってから、在庫を表`W1003B`に取ります。

      ```text
      RUNSQL SQL('DROP TABLE <自分のユーザー名>2/W1003B') COMMIT(*NONE)
      RUNSQL SQL('CREATE TABLE <自分のユーザー名>2/W1003B AS (SELECT ZASHO, ZASU FROM <自分のユーザー名>2/ZAIKOM) WITH DATA') COMMIT(*NONE)
      TXRESET LIB(<自分のユーザー名>2)
      ```

   4. (SSH) 両方向の`EXCEPT`で比べ、在庫を見ます。

      ```sh
      db2 "SELECT ZASHO, ZASU FROM <自分のユーザー名>2.W1003A EXCEPT SELECT ZASHO, ZASU FROM <自分のユーザー名>2.W1003B"
      db2 "SELECT ZASHO, ZASU FROM <自分のユーザー名>2.W1003B EXCEPT SELECT ZASHO, ZASU FROM <自分のユーザー名>2.W1003A"
      db2 "SELECT ZASHO, ZASU FROM <自分のユーザー名>2.W1003B ORDER BY ZASHO"
      ```

      期待される結果: 1つ目・2つ目とも0行(`0 RECORD(S) SELECTED`)。3つ目は`P00001`〜`P00006`が39・3・235・48・9・20。**この値と、両方向の`EXCEPT`が0行であることは、旧・新の両方でバッチが確認しました(V2)。** 2つの`*LIVE`の12行の印字も、旧・新で同じでした(V2)。ここで打つ`RUNSQL`は5250から、`db2`はSSHから打った形では、確認していません(未検証(2026-09-30時点))。`SBMJOB`のジョブが終わる前に`RUNSQL`を打つと、途中の在庫を取ってしまいます。自分が投入したジョブが終わったことを、`WRKSPLF`にそのジョブ(`T1003C`・`T1003D`)の`QSYSPRT`が出たことで確かめてから進めてください(`WRKSUBMJOB`でも確かめられます。どちらも一般知識で、この教材の検証では使っていません)。

9. **(5250) 切り戻しを確かめます。** 手順8の最後で新`ZA0500`が動いています。ここから`ZA0ORIG`で戻し、旧に戻ったことを、属性と`*TEST`の12行で確かめます。

   ```text
   DLTPGM PGM(<自分のユーザー名>2/ZA0500)
   CRTDUPOBJ OBJ(ZA0ORIG) FROMLIB(<自分のユーザー名>B) OBJTYPE(*PGM) TOLIB(<自分のユーザー名>2) NEWOBJ(ZA0500)
   SBMJOB CMD(CALL PGM(<自分のユーザー名>2/JU0900C) PARM('*TEST' '<自分のユーザー名>2')) JOB(T1003E) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)
   ```

   期待される結果: `OBJECT_STATISTICS`の`OBJATTRIBUTE`が`RPG`に戻り(RPG III を通らないルートでは、`RPGLE` のままです。実機で確認(part10-03-rpgle、2026-10-04)。旧に戻ったことは、上の囲みの印(`ZAISRV` の行が消える)で確かめます)、12行が手順3と同じ(V2。バッチが、同じ形の切り戻しのあとで確認しました)。**切り戻しは、`DLTPGM`のあとの`CRTDUPOBJ`です。`CRTDUPOBJ`には`REPLACE`がありません。**

   このあと、演習(b)を行い、続けて、手順9bで新`ZA0500`を戻します。

   **手順9b (5250と SSH) 新`ZA0500`を、もう一度差し替えます。** **この手順を飛ばすと、手順10・11は旧`ZA0500`に対して走ります。`TSTZA0500`のB・Cのケースは旧でも通りうるので、`PASS=0000000038`が出ても、新を試したことになりません**(予想。実行していません)。

   ```text
   DLTPGM PGM(<自分のユーザー名>2/ZA0500)
   CRTSQLRPGI OBJ(<自分のユーザー名>2/ZA0500) SRCSTMF('/home/<自分のユーザー名>/za-work/za0500s.sqlrpgle') OBJTYPE(*PGM) COMMIT(*NONE) CVTCCSID(*JOB) REPLACE(*YES)
   ```

   (SSH)手順6と同じ`OBJECT_STATISTICS`の問い合わせで、`OBJATTRIBUTE`が`RPGLE`であることを確かめます。`RPG`のままなら、差し替えが済んでいません。(RPG III を通らないルートでは、この確認は使えません。実機で確認(part10-03-rpgle、2026-10-04)。上の囲みの `BOUND_SRVPGM_INFO` に `ZAISRV` の行が出ることで確かめます)

10. **(5250と SSH) `TSTZA0500`・`RUNTEST`を用意します。** 演習(b)と手順9bのあと、テストとラッパーを`<自分のユーザー名>2`に作ります。まず`TSTZA0500`です。

    ```text
    ADDPFM FILE(<自分のユーザー名>2/QRPGLESRC) MBR(TSTZA0500) SRCTYPE(RPGLE)
    CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/10-03/tstza0500.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>2.LIB/QRPGLESRC.FILE/TSTZA0500.MBR') MBROPT(*REPLACE) STMFCCSID(1208)
    CRTBNDRPG PGM(<自分のユーザー名>2/TSTZA0500) SRCFILE(<自分のユーザー名>2/QRPGLESRC) SRCMBR(TSTZA0500) DFTACTGRP(*NO) ACTGRP(*NEW) BNDDIR((*LIBL/ZAISRVBD) (*LIBL/TESTKITBD)) REPLACE(*YES)
    ```

    `ADDPFM`は5250、`CPYFRMSTMF`は1行に入らなければ、SSHから`system "CPYFRMSTMF ..."`の形(02-05・08-04と同じ)で打ちます。`QRPGLESRC`が`<自分のユーザー名>2`に無ければ、08-04で自分の`QRPGLESRC`を作った形で先に作ります。**`CRTBNDRPG`の指定は、検証で使った形です(V2。メンバーの形)。`ADDPFM`・`CPYFRMSTMF`でメンバーを作る部分は、実機では通していません**(未検証(2026-09-30時点)。バッチは、ハーネスのファイル転送でメンバーを作りました)。

    **読むだけの5分**: `solutions/10-03/tstza0500.rpgle`を開き、`A1`〜`E1`のラベルを探して、「説明」の`TSTZA0500`の表と、1件ずつ照らします。これが目標10-03-2の後半(15件が何を確かめているかの説明)の準備です。

    次に`RUNTEST`(CL)です。`QCLSRC`が`<自分のユーザー名>2`に無ければ、02-05の形で先に作ります。

    ```text
    ADDPFM FILE(<自分のユーザー名>2/QCLSRC) MBR(RUNTEST) SRCTYPE(CLP)
    CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/10-03/runtest.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>2.LIB/QCLSRC.FILE/RUNTEST.MBR') MBROPT(*REPLACE) STMFCCSID(1208)
    CRTCLPGM PGM(<自分のユーザー名>2/RUNTEST) SRCFILE(<自分のユーザー名>2/QCLSRC) SRCMBR(RUNTEST) REPLACE(*YES)
    ```

    **確認の範囲**: バッチは`RUNTEST`を`CRTCLPGM`で作りました(V2。メンバーは、ハーネスが直接入れました)。上の`ADDPFM`・`CPYFRMSTMF`は、実機では通していません(未検証(2026-09-30時点))。`RUNTEST`のソースを読んで、上の「説明」の順序と照らしてください(読解用です)。

    <details><summary>別の形: <code>TXLOAD</code>で取り込む(<code>TXLOAD</code>を自分で作ってある場合だけ。未検証)</summary>

    `TXLOAD`は、この教材のどのレッスンも、まだ作る手順を書いていません([付録E](../appendix/e-naming.md))。すでに自分で作ってある場合は、次の1行が、上の3行と同じ働きをするはずです(`TXLOAD`は`solutions/`のCLとRPG IIIだけを扱います)。

    ```text
    TXLOAD SOL('10-03') FILE('runtest') OBJ('RUNTEST') TYPE('CLP') LIB(<自分のユーザー名>2)
    ```

    この1行は、実行していません(未検証(2026-09-30時点))。

    </details>

11. **(5250) `RUNTEST`を1コマンドで走らせます。** `TXCHECK`より先に実行します(`RUNTEST`は、`QTEMP`の複製と上書きをそのジョブの中で使い、最後に消します)。

    ```text
    CALL PGM(<自分のユーザー名>2/RUNTEST) PARM('<自分のユーザー名>2')
    ```

    `PARM`には、ライブラリー名をそのまま書きます。`CALL`の文字リテラルは、32バイト未満なら32バイトまで空白で埋められて渡るので、10桁の`LIB`には足ります(03-08で実機確認済みの規則。付録Eの「32バイト・リテラル」と同じ話です。この10-03でも、バッチは文字リテラルのライブラリー名をそのまま渡して動きました)。

    ジョブ・ログ(`DSPJOBLOG`)で、次のメッセージを探します。

    ```text
    RUNTEST: PASS=0000000038 FAIL=0000000000
    ```

    期待される結果: `PASS`が38(`TSTJUCSRV`と`TSTZAISRV`の23件と、`TSTZA0500`の15件)、`FAIL`が0(V2。CLラッパーの中の1つのジョブで、2回目の接続で確認)。`TESTRES`の中身を見ます。

    ```sh
    db2 "SELECT RESULT, COUNT(*) AS N FROM <自分のユーザー名>2.TESTRES GROUP BY RESULT"
    ```

    期待される結果: `PASS`が38行の1行だけ、のはずです(検証では、バッチの集計が`TOTAL` 38・`PASS` 38・`FAIL` 0でした。この`GROUP BY`の形の問い合わせそのものは実行していません。未検証(2026-09-30時点))。**`TESTRES`の`SEQ`(自動採番の行番号)は、`DELETE`のあとも1に戻りません。** 行の順番や番号ではなく、件数と`RESULT`を読んでください。5250から打つ形は、確認していません(未検証(2026-09-30時点))。

    続けて、`TXCKM`に6行を入れ、`TXCHECK`を**1ジョブに1回だけ**実行します(同じジョブで2回目は`CPF4174`。08-08・09-07。前に`TXCHECK`を打ったジョブなら、サインオンし直します)。

    ```sh
    db2 "DELETE FROM <自分のユーザー名>2.TXCKM WHERE LESSON = '10-03'"
    db2 "INSERT INTO <自分のユーザー名>2.TXCKM (LESSON, SEQNBR, OBJNAME, OBJTYPE, OBJATTR, CKDESC) VALUES ('10-03', 10, 'ZA0500', '*PGM', ' ', 'ZA0500 modernized program exists'), ('10-03', 20, 'RUNTEST', '*PGM', ' ', 'RUNTEST wrapper exists'), ('10-03', 30, 'TSTZA0500', '*PGM', ' ', 'TSTZA0500 test case exists'), ('10-03', 40, 'TESTKIT', '*SRVPGM', ' ', 'TESTKIT service program exists'), ('10-03', 50, 'ZAISRV', '*SRVPGM', ' ', 'ZAISRV service program exists'), ('10-03', 60, 'TESTRES', '*FILE', ' ', 'TESTRES result table exists')"
    ```

    ```text
    TXCHECK LESSON('10-03') LIB(<自分のユーザー名>2)
    ```

    期待される結果: 6件`PASS`、要約が`0000000006 passed,`・`0000000000 failed.`(10桁のゼロ埋め、2行。V2。バッチでは`TXCHKRUN`というヘルパー経由。件数の6と0を確認し、文言の細部は09-07と同じ形です)。`INSERT`の文は09-07の形で、バッチは同じ6行をCLの中の`RUNSQL`で入れました。`db2`から打った形と、5250に直接打った`TXCHECK`は、確認していません(未検証(2026-09-30時点))。`TESTRES`は、`RUNTEST`を走らせたライブラリー(現行ライブラリー)にできます。

12. **(SSH) `makei`用のディレクトリーを整えます。** `makei`が読む、平らな(サブ・ディレクトリーのない)ディレクトリーを作ります。手順6のソースが、既に`$HOME/za-work/za0500s.sqlrpgle`にあります(`$HOME/za-work`はgitのクローンではなく、ただの作業用ディレクトリーです)。

    ```sh
    mkdir -p $HOME/mk10/z
    cp $HOME/ibmi-kyozai/solutions/07-05/zaisrv.rpgle $HOME/mk10/z/zaisrv.rpgle
    cp $HOME/ibmi-kyozai/solutions/07-05/zaisrv.bnd $HOME/mk10/z/zaisrv.bnd
    cp $HOME/za-work/za0500s.sqlrpgle $HOME/mk10/z/za0500s.sqlrpgle
    cp $HOME/ibmi-kyozai/templates/part08-zaisrv/iproj.json $HOME/mk10/z/iproj.json
    ```

    `Rules.mk`は、[`solutions/10-03/Rules.mk`](../../solutions/10-03/Rules.mk)をそのままコピーします(コメントは、ビルドに影響しません。08-02)。

    ```sh
    cp $HOME/ibmi-kyozai/solutions/10-03/Rules.mk $HOME/mk10/z/Rules.mk
    ```

    中身の実質は、次の4行です(検証は、コメントを除いたこの4行だけのファイルで成功しました)。

    ```text
    ZAISRV.MODULE: zaisrv.rpgle
    ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd
    ZA0500.MODULE: za0500s.sqlrpgle
    ZA0500.PGM: ZA0500.MODULE ZAISRV.SRVPGM
    ```

    `iproj.json`は、08-02のとおり書き換えます。検証では、**ビルド先を`<自分のユーザー名>B`にし、`ZA0500`のSQLの前処理が`JUCHUD`などを見つけられるよう、`postUsrlibl`に`<自分のユーザー名>2`を入れました**(V2で確認したのは、`objlib`・`curlib`・`postUsrlibl`の3項目だけです。ほかの項目は08-02のテンプレートのままで、未検証(2026-09-30時点))。コピーしたテンプレートは`YOURUSER1`と空の`postUsrlibl`を含むので、次の`sed`で書き換えられます(未検証(2026-09-30時点)。名前は大文字で書きます)。

    ```sh
    sed -i 's/YOURUSER1/<自分のユーザー名>B/g; s/"postUsrlibl": \[\]/"postUsrlibl": ["<自分のユーザー名>2"]/' $HOME/mk10/z/iproj.json
    cat $HOME/mk10/z/iproj.json
    ```

    `cat`の結果を、次の形と見比べます。

    ```json
    {
      "version": "0.0.1",
      "description": "ZAISRV and ZA0500 flat clone (lesson 10-03)",
      "objlib": "<自分のユーザー名>B",
      "curlib": "<自分のユーザー名>B",
      "includePath": [],
      "preUsrlibl": [],
      "postUsrlibl": ["<自分のユーザー名>2"]
    }
    ```

    **`makei`用のコピー`$HOME/mk10/z/za0500s.sqlrpgle`だけから、`ctl-opt`の`dftactgrp(*no) actgrp(*new)`の2つのキーワードを消します**(`bnddir('ZAISRVBD')`は残します。`$HOME/za-work/`側は触りません)。`makei`は、まず`*MODULE`を作り、`ACTGRP`・`DFTACTGRP`は`CRTBNDRPG`にしかないからです(ILE RPGリファレンスの記載。検証では、この2つを外したコピーで成功しました)。**外さないまま`makei`を通したことは、ありません**(未検証(2026-09-30時点))。手順6の`CRTSQLRPGI`に渡す`$HOME/za-work`の元のソースは、書き換えないでください(`OBJTYPE(*PGM)`では、この2つがあっても`00`で作れました)。消す例です(未検証(2026-09-30時点)。自分のソースの書き方に合わせて直します)。

    ```sh
    sed -i 's/dftactgrp(\*no) actgrp(\*new) //' $HOME/mk10/z/za0500s.sqlrpgle
    grep -n ctl-opt $HOME/mk10/z/za0500s.sqlrpgle
    ```

    `grep`の結果に、`dftactgrp`と`actgrp`が残っていなければ、消せています。

13. **(SSH) `makei build`を実行します。**

    ```sh
    /QOpenSys/pkgs/bin/bash -c 'cd $HOME/mk10/z && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
    ```

    期待される結果: `Build Successful!`と、4つのステップの成功(`ZAISRV`のモジュールと`*SRVPGM`、`ZA0500`のモジュールと`*PGM`)。検証では、`ZA0500`のモジュールは`crtsqlrpgi ... OBJTYPE(*MODULE)`で、`COMPILEOPT('TGTCCSID(*JOB) OPTIMIZE() INCDIR(*NONE)')`が付いて作られ、`*PGM`は`crtpgm ZA0500 bndsrvpgm(ZAISRV)`で作られました(V2)。`.sqlrpgle`も、`*PGM`が`*SRVPGM`を束縛することも、`Rules.mk`の依存の書き方で通りました。作られた属性は、`ZAISRV`の`*MODULE`・`*SRVPGM`が`RPGLE`、`ZA0500`の`*MODULE`・`*PGM`が`RPGLE`です(`*PGM`は`SQLRPGLE`ではありません)。

    **`makei`が作った4つのオブジェクトは、`<自分のユーザー名>B`にできます。** 使い終わったら、名前で消します(片付け)。`<自分のユーザー名>B`に、自分で作った`ZAISRV`が既にあるなら、先に別名の控えを取ってください(名前で消すと、それも消えます)。

14. **(PC) `rpglint`を回し、READMEを書きます。** 演習(d)・(e)で行います。`rpglint`は、PC側で動く道具です(08-03)。この教材のリポジトリーの自動検査(CI)は、`rpglint`を実行しません。

## 出会うメッセージID

このレッスンの検証(`part10-03-modernize`)で出会ったものは、「検証で確認」と付けました。それ以外は、前のレッスンや一般的な推測です。

| ID | 原因 | 対処 |
|---|---|---|
| `RNS9304`「Program ZA0500 placed in library ...」 | `CRTSQLRPGI`が、プログラムを作った(最高重大度`00`) | 作れた印。何もしない(検証で確認) |
| `CPD0043`「Keyword TGTCCSID not valid for this command」「Keyword BNDDIR not valid for this command」 | `CRTSQLRPGI`に、`TGTCCSID`も`BNDDIR`も無い | 変換は`CVTCCSID(*JOB)`(または`COMPILEOPT`)、束縛ディレクトリーはソースの`ctl-opt bnddir(...)`(検証で確認。`ACTGRP`も同じ理由) |
| `SQL7008`・`CPF4328` | `CRTSQLRPGI`に`COMMIT(*NONE)`が無い | `COMMIT(*NONE)`を付ける(08-04) |
| `SQ20038` | `CREATE OR REPLACE TABLE ... AS (...) WITH DATA`を使った | `DROP TABLE`してから`CREATE TABLE ... AS (...) WITH DATA`(検証で確認) |
| `SQL0104`・`SQL0204`(`RUNTEST`の`DELETE`) | `*TCAT`が左のリテラルの末尾の空白を削り、`FROM`と名前がくっついた | `*CAT`を使う(検証の1回目で確認。`runtest.clp`は直した形) |
| `SQL0601`「TESTRES already exists」 | `testInit()`が、3つのテストのたびに`CREATE TABLE`を試す | 何もしない。表は残り、`RUNTEST`が先に`DELETE`する(検証で、3回出た。設計どおり) |
| `CPF4123`「Open options ignored for shared open of member JUCHUD」 | 共有の開きで、開きのオプションが無視された、という通知(メッセージ本文の意味)。旧`ZA0500`の実行のジョブ・ログにだけ出た(なぜ旧だけかは未確認) | 何もしない。旧プログラムの実行で2回出て(切り戻し後の旧の実行でも出て)、新プログラムでは出なかった(検証で確認。原因は未確認) |
| `CPF4174`「OPNID(TXCKM) for file TXCKM already exists」 | 同じジョブで2回目の`TXCHECK`(08-08・09-07の既知の不具合) | 新しいジョブで1回だけ実行する(バッチでは`TXCHKRUN`をラッパー1つにつき1回) |
| `CPD5D09`・`CPC5D05`「already exists in binding directory」 | 束縛ディレクトリーに、同じ項目を2回足した | 何もしない(検証の繰り返しのビルドで出た) |
| `SQL7905` | 表を、ジャーナルなしで作った警告 | 無視してよい(第9部までと同じ。検証で出た) |
| `CPC2191` | 名前を指定したオブジェクトの削除が成功した | 片付けの想定どおり(検証で確認) |
| `RPG0907`(`ZA0500`) | `JU0900C`と`ZA0500`の`MINQTY`の型の食い違い(05-13のチケット1) | 手順2の宣言と、`ZA0500`の`packed(5:0)`を照らす(05-13で確認。RPG III を通らないルートでは、04-27 の B と 08-05b で扱った内容です。新`ZA0500`で起きるかは未検証(2026-09-30時点)) |

メッセージ全般は[付録B](../appendix/b-message-ids.md)・[付録C](../appendix/c-troubleshooting.md)も参照してください。

## 出力が違うとき

- **12行のうち、行が減っている、または全部`SHORT`・`NOTFOUND`になる。** `ZAIKOM`が初期状態ではありません(前の`*LIVE`の実行のあとに`TXRESET`を忘れた)。`TXRESET LIB(<自分のユーザー名>2)`で戻し、手順1の`8`・`12`・`6`を確かめてから、もう一度実行します。
- **`*TEST`の12行なのに、`J00007`の`P00005`が`SHORT`になっている。** 直前の`*LIVE`の実行の在庫が残っています(`*TEST`なら`OK`のはず)。`TXRESET`で戻します。
- **`*LIVE`の12行で、`J00007`の`P00005`が`OK`のまま。** 新`ZA0500`が、`reserve()`を呼んでいない、または`RMODE`の比較が合っていません(`*LIVE`は10桁の`CHAR`で、`'*LIVE'`と比べます)。`ZAIKOM`の`P00005`が9になっているかを、`db2`で見ます。
- **印字が全く出ない。または`RPG0907`。** `MINQTY`の型の食い違いを疑います(手順2)。(RPG III を通らないルートでは、ILE の実行時メッセージは `RNQ`・`RNX` などで始まるはずで、`RPG0907` とは限りません。[04-24](../part04v/04-24-call-parm-debugging.md)。未検証(2026-10-01時点))
- **`OBJATTRIBUTE`が`RPG`のまま。** 差し替えが済んでいません。(RPG III を通らないルートでは、旧も`RPGLE`なので、この症状は出ません。実機で確認(part10-03-rpgle、2026-10-04)。差し替えは、上の囲みの印(`ZAISRV` の行)で確かめます)`CRTSQLRPGI`のジョブ・ログの`RNS9304`と、`DLTPGM`の順を確かめます。
- **`CRTSQLRPGI`が`CPD0043`。** `TGTCCSID`または`BNDDIR`を書いています。消します。
- **`makei`で`ACTGRP`・`DFTACTGRP`まわりの失敗。** `$HOME/mk10/z/za0500s.sqlrpgle`に、`dftactgrp(*no) actgrp(*new)`が残っています。`makei`用のコピー側だけで消します(手順12。未検証)。
- **`CRTSQLRPGI`が失敗した。** 手順6の「コンパイルが失敗したとき」のとおり、`DSPJOBLOG`の最後の`SQL`・`RNF`・`RNS`のメッセージと、`WRKSPLF`のコンパイル・リストを読み、最初のエラーだけを直して再実行します。
- **`RUNTEST`の`PASS`が38ではなく27。** `TSTZAISRV`の分(11件)が無いはずです(08-04の演習を先に行います。未検証(2026-09-30時点))。
- **`RUNTEST`が「no rows in TESTRES」。** テストが走っていないか、`TESTRES`が別のライブラリーにあります。`CHGCURLIB`の効き方と、`PARM`のライブラリー名の綴りを確かめます。
- **`RUNTEST`の`PASS`が38より多い。** 古い行が消えていません。`DELETE`の文が失敗していないか(`SQL0104`・`SQL0204`)、ジョブ・ログを見ます。
- **`TXCHECK`が「could not query the manifest」。** 同じジョブで2回呼んでいます。新しいジョブで1回だけ。
- **`rpglint`の件数が、この教材の記述と違う。** `rpglint`は、このレッスンで実行していません(V3)。件数は、あなたの環境の値を正としてください。

## 演習

例題を読む → 穴埋め(ヒント) → 独力 → 応用、の順で難度を上げます。解答は下の`<details>`に、模範解答のファイルは`solutions/10-03/`にあります。**模範解答は、先に開かないでください**(このレッスンでは、自分で書くことが目的です。強制はできません。取得のしかたは、Part 9の扉と同じ`git sparse-checkout add solutions`です)。

### 演習(a): 骨組みを埋めて、新`ZA0500`を書く

[`solutions/10-03/za0500s-skeleton.sqlrpgle`](../../solutions/10-03/za0500s-skeleton.sqlrpgle)を、`$HOME/za-work/za0500s.sqlrpgle`にコピーし、6か所の`TODO`を埋めます(未検証(2026-09-30時点))。

```sh
mkdir -p $HOME/za-work
cp $HOME/ibmi-kyozai/solutions/10-03/za0500s-skeleton.sqlrpgle $HOME/za-work/za0500s.sqlrpgle
```

編集は、qshの中でできる形で行うか、PCの自分のリポジトリー(08-01・08-02)で編集してgitで`$HOME/za-work/za0500s.sqlrpgle`に届ける形でもかまいません(後者は、PCが3本目のSSH接続を張ります。5250かqshの接続を1本閉じてから)。宣言・プロトタイプ・2つのカーソルの`DECLARE`・印字の道具(`printLine`・`zeroPad`)は、与えられています。**ソースの中は、ASCIIの文字だけで、英語のコメントにします。ライブラリー名を書き込みません。**

| TODO | 書くこと | 前に習った場所 |
|---|---|---|
| 1 | 引数が、手順2で読んだ`JU0900C`の型と一致しているか確かめる | 05-13(RPG III を通らないルートでは 04-24・04-27 の B) |
| 2 | 2カーソルのマージ(`JUCHUD`が主導、`JUCHUM`が追従)。一致する行だけ`processLine()`を呼ぶ | 08-05b |
| 3 | 2つのカーソルを閉じる | 06-14 |
| 4 | ロックしない覗き見(`get()`)。`-1`なら`NOTFOUND`を印字して戻る | 07-05 |
| 5 | 余裕の判定。`MINQTY`未満なら`SHORT`(ロックも更新もしない) | 05-03(旧`ZA0500`の規則。RPG III を通らないルートでは 04-25) |
| 6 | 判定が通ったら`OK`。`*LIVE`のときだけ`reserve()`。`*off`が返ったら何を印字するか | 07-05 |

**マージの言葉は、08-05bで習いました。`avail >= minqty >= 0`なら在庫は数量以上になる、という不等式は、どのレッスンにも出てきません。TODO 6の問いの中で自分で考えてください。**

<details><summary>ヒント1(TODO 4〜6の考え方。答えの文章ではありません)</summary>

- 覗き見は、更新しません。`get()`は、商品が無ければ`-1`を返します。在庫の型は`packed(7:0)`です。
- 余裕は「在庫 − 受注数量」です。判定は、覗き見の値だけで決め、その時点では、ロックを持っていません。
- 状態を表す文字列を決めてから、最後に1回だけ印字する形にすると、印字の道具を1か所で呼べます。
- `reserve()`を呼ぶ条件は2つです(判定が通っている、かつ、`RMODE`が`*LIVE`)。

</details>

<details><summary>ヒント2(TODO 2 のマージの考え方)</summary>

`Q0805B`(08-05b)と同じ2カーソルのマージです。手順は、次のとおりです。

1. 主導のカーソルと追従のカーソルを、1回ずつ`FETCH`する。主導(`C1`)は骨組みの`lJuno`・`lJuline`・`lJusho`・`lJusu`に、追従(`C2`)は`hJuno`に、`INTO`で受ける。それぞれ、終端(`SQLSTATE`が`'02000'`)かどうかを覚える。
2. 主導の行を1つずつ処理するループに入る。ループの中で、追従の`JUNO`が主導の行の`JUNO`より小さい間だけ、追従を進める(追従が終端になったら、以降は一致しないと覚える)。
3. 追従の`JUNO`と主導の`JUNO`が等しければ、その行を処理する。等しくなければ(ヘッダーが無い明細)、処理せずに読み飛ばす(旧`ZA0500`のマッチング・レコードの門と同じ)。
4. 主導を次の行に進めて、繰り返す。

**追従を「毎回進める」書き方にすると、同じヘッダーに複数の明細がある行で、2行目以降を取りこぼします**(08-05b演習5)。

</details>

<details><summary>ヒント3(模範解答を開く)</summary>

[`solutions/10-03/za0500s.sqlrpgle`](../../solutions/10-03/za0500s.sqlrpgle)が模範解答です。自分の書いたものと、判定の順序と、`reserve()`が`*off`を返したときの印字の扱いを、見比べてください。**書き上げてから開く**のが目的です(強制はできません。採点表の「実装」は、ヒント3を使った場合は△を上限にしてください)。

</details>

### 演習(b): 予想してから試す(手順9のあと、手順9bの前に行う、紙の上)

`TSTZA0500`のケースCを、実行する前に予想してください。`P00002`に、数量1の行と数量2の行が、その順であります。`MINQTY`は5です。

1. `P00002`の在庫が6のとき、`*LIVE`の実行のあと、在庫はいくつですか。各行は`OK`ですか、`SHORT`ですか。
2. 在庫が5のときは、どうなりますか。
3. 1と2で、`reserve()`は何回呼ばれますか。

<details><summary>解答例</summary>

1. 1行目は、6 − 1 = 5で、5 ≥ 5なので`OK`。`reserve()`で在庫は5になります。2行目は、5 − 2 = 3で、3 < 5なので`SHORT`。在庫は5のままです。最終は5(C1の期待値)。
2. 1行目が、5 − 1 = 4 < 5で`SHORT`。2行目も`SHORT`(5 − 2 = 3)。在庫は5のままです(C2の期待値)。
3. 1では1回(1行目だけ)。2では0回。`SHORT`の行では`reserve()`を呼びません。これが、`SHORT`の経路がロックを持たない、という作りです。

</details>

### 演習(c): `RUNTEST`の順序を、崩したときの結果を予想する(紙の上)

次の変更を`RUNTEST`にしたとき、何が起きると考えますか。

1. `DELETE FROM TESTRES`の行を消して、続けて2回`RUNTEST`を実行する。
2. 最初の`CHGCURLIB`の行を消して、現行ライブラリーが`<自分のユーザー名>1`のまま`RUNTEST`を実行する。
3. `OVRDBF`の行を消す。

<details><summary>解答例(予想です。実行していません。未検証(2026-09-30時点))</summary>

1. 手順11のあとで、`TESTRES`には前回の38行が残っています。表は残り、`testInit()`は消さないので、実行のたびに38行が加わり、2回続けると114行になり、`PASS`は38より多くなる、と予想します(検証の1回目の接続で、`TESTRES`に前の行が消えずに残ったことを観察しました)。
2. 現行ライブラリーが`<自分のユーザー名>1`の新しいジョブで実行すると、テストの行は`<自分のユーザー名>1`の`TESTRES`に入り、`RUNTEST`が数える`<自分のユーザー名>2`の`TESTRES`とは別になります。`<自分のユーザー名>2`に`TESTRES`がまだ無い初回なら「no rows in TESTRES」に、手順11のあとなら古い38行が数えられて、テストの結果とは関係のない数になる、と予想します。
3. テストが共有の`ZAIKOM`(`<自分のユーザー名>2`)を書き換えます。ケースBの`*LIVE`の実行で、実際の在庫が変わります。ケースDの`QTEMP`の行の削除も、隔離されなくなります。最後に`TXRESET`で戻す必要が出ます。

</details>

### 演習(d): `rpglint`を回す(PC。V3。任意ではありません)

`rpglint`はPC側で動く道具です(08-03)。IBM i上のファイルではなく、PC側の自分のプロジェクトのコピーに実行します。`solutions/07-05/zaisrv.rpgle`を、PC側のプロジェクトの`src/`にコピーし、08-03の手順で実行します。設定は、`templates/part08-project/.vscode/rpglint.json`(08-03で使ったもの)です。**この教材の`solutions/07-05/zaisrv.rpgle`は、`//====`という罫線コメントを使っています**(`grep`で数えると、`//`の直後が空白でも`/`でもない行が8行)。`PrettyComments`は、これに指摘を出す想定です(件数は実行していないので、未検証(2026-09-30時点))。

1. `rpglint`を実行し、指摘の内容を読む。
2. 罫線コメントを`// ===`(スラッシュ2つのあとに空白1つ)に直す。
3. もう一度実行し、`PrettyComments`の指摘が消えたことを確かめる。直したあと、直したファイルを`$HOME/mk10/z/zaisrv.rpgle`に送り(gitか`scp`。3本目の接続に注意)、`makei build`をもう一度実行して、ビルドが通ることを確かめる(ソースが変わっているので、作り直しになります)。

`za0500s.sqlrpgle`(自分の書いたもの)にも、`//`の直後に空白が無いコメントがあれば、同じ直しをします。このレッスンの`tstza0500.rpgle`と骨組み・模範解答は、`//`の直後に半角の空白を1つ付けて書いてあります。**`rpglint`が0件になることは、コンパイルが通ることも、規約に沿った動作も保証しません**(08-03。構文の層の検査です)。

<details><summary>解答例</summary>

PC側のGit Bashで、`sed`などで、行頭の`//====`を`// ====`に置き換えるだけです(例は`sed -i 's#^//=#// =#' src/zaisrv.rpgle`)。文字列の中の`//`(URLなど)を巻き込まないように、行頭の`//`だけを対象にしてください。コメントだけの変更なので、コンパイルの結果は変わりません(設計上の性質)。**この置き換えとビルドの通し実行は、していません**(未検証(2026-09-30時点))。

</details>

### 演習(e): 成果物 — READMEとテスト結果(独力)

課題Dの成果物は、「リポジトリーのREADME」と「テスト結果」の2つです。PC側の自分のリポジトリー(08-01・08-02の`zaiproject`など)に置きます。

READMEの見出しの骨組みは、次のとおりです。

```text
# ZA0500 modernization (ZAISRV + ZA0500)

## Purpose
## Requirements (IBM i, PUB400 profile, makei, git)
## Get the source (clone steps)
## Build (iproj.json, Rules.mk, makei build)
## Test (RUNTEST, expected message, how to read TESTRES)
## Rollback (ZA0ORIG)
## Known limits and unverified items
```

**テスト結果(1ファイル)**: 実行した日付、実行したコマンド、`RUNTEST`が送ったメッセージ、`TESTRES`の集計(`RESULT`と件数)、`*TEST`の12行の一致を見た方法、`*LIVE`の在庫(6商品)と`EXCEPT`の結果、`TXCHECK`の件数を書きます。**確かめていないことは、空欄にせず「未検証(日付時点)」と書き、確かめた日に書き換えます。**

次の点を守ります。

- 自分が書いた`za0500s.sqlrpgle`、`Rules.mk`、`iproj.json`、テスト結果を、自分のリポジトリー(08-01・08-02のもの)にコミットして送る。**片付けで`$HOME/za-work`を消す前に行う**(書いたソースの唯一のコピーが、そこにあるためです)。READMEの手順は、そのリポジトリーから始まる形にする。
- 実在のユーザー名・ライブラリー名・メール・アドレスを書かない(`<自分のユーザー名>2`のような表記にする)。
- READMEの手順だけで、別の人が、クローン→ビルド→`RUNTEST`を再現できるようにする。
- ジョブ番号などの、その時だけの識別子を書かない。

模範解答は置きません。下の採点表で、自分で採点してください。

### 採点表

自分で採点してください。「◯」の数ではなく、理由を説明できるかを重視してください。

| 観点 | 基準 | 自己採点(◯・△・×) |
|---|---|---|
| 差し替えの前 | `ZA0ORIG`を取り、旧`ZA0500`で`*TEST`の12行を採った(`OK`10・`SHORT`2・`NOTFOUND`0) | |
| 契約 | `JU0900C`の`MINQTY`の宣言を、ソースの行で読んで確かめ、`packed(5:0)`にした | |
| 実装 | 骨組みの6つの`TODO`を、ヒント3を使わずに埋めた(使った場合は△まで) | |
| ロックの扱い | `SHORT`の行が`reserve()`もロックも使わないこと、`reserve()`が`*LIVE`のときだけ呼ばれること、`*off`のときの扱いを説明できる | |
| 特性検定 | 新`ZA0500`の`*TEST`の12行が、旧と1行ずつ一致した | |
| `*LIVE`の差 | 両方向の`EXCEPT`が0行で、在庫が39・3・235・48・9・20。`J00007`の`P00005`が`*LIVE`で`SHORT`になる理由を説明できる | |
| 切り戻し | `DLTPGM`と`CRTDUPOBJ`で戻し、`OBJATTRIBUTE`が`RPG`、12行が採ったものと同じ(RPG III を通らないルートでは、囲みの印が手順1のときと同じに戻り、12行が同じ) | |
| `RUNTEST` | 1コマンドで`PASS=0000000038 FAIL=0000000000`を読んだ。順序の理由を3つ言える | |
| `TSTZA0500` | 15件が何を確かめるか説明でき、`E1`が「証明」ではなく「見張り役」である理由(`ACTGRP(*NEW)`)を言える | |
| ビルドの再現 | `makei build`で成功し、`ZAISRV`と`ZA0500`が作れた。`Rules.mk`の4行の意味を説明できる。`makei`用のコピー側でだけ`ctl-opt`の2つのキーワードを外した理由を言える | |
| `rpglint` | 指摘を読み、罫線コメントを直し、再度の実行と`makei`の再ビルドを確かめた。0件が保証することの範囲を言える | |
| 成果物 | READMEとテスト結果があり、確かめていない項目に「未検証」と日付がある | |
| `TXCHECK` | 1ジョブに1回だけ実行し、`6 passed`・`0 failed`を確かめた | |
| 必須の3点 | (1)ソースにライブラリー名が書かれていない。(2)ASCIIの文字だけ。(3)片付けが済んでいる。**`TXCHECK`はこの3点を確かめられません**(`grep`などで自分で確かめる) | |

必須の3点の確かめ方の例です(未検証(2026-09-30時点))。PC側のGit Bash(またはIBM iのqsh)で、自分のリポジトリーのソースに対して行います(Windows PowerShellには`LC_ALL=C grep`がありません)。

```sh
grep -n "自分の実際のユーザー名" za0500s.sqlrpgle
LC_ALL=C grep -n '[^ -~]' za0500s.sqlrpgle
```

期待される結果は、どちらも何も出ないこと(1つ目の`自分の実際のユーザー名`は、実際のユーザー名の文字列に置き換えます。見つかったら、ライブラリー名が書き込まれています。2つ目は、ASCII以外の文字を探します)。

## セルフチェック

- [ ] 手順1で、`8`・`12`・`6`と、`ZA0500`が旧プログラム(`RPG`)であることを確かめてから始めた(RPG III を通らないルートでは、旧も`RPGLE`なので、上の囲みの印を控えた)。
- [ ] `JU0900C`の`MINQTY`の宣言を読み、新`ZA0500`の`packed(5:0)`と合っていることを確かめた。
- [ ] `ZA0ORIG`を`<自分のユーザー名>B`に取り、旧`ZA0500`の12行を控えた。
- [ ] 新`ZA0500`を書き、`RNS9304`と`OBJATTRIBUTE`が`RPGLE`であることを確かめた(`SQLRPGLE`ではない)(RPG III を通らないルートでは、新になったことを、上の囲みの印の変化で確かめた)。
- [ ] `*TEST`の12行が、旧・新で一致した。`*LIVE`の比較で、`EXCEPT`が両方向とも0行で、在庫が39・3・235・48・9・20になった。`J00007`の`P00005`の違いの理由を言える。
- [ ] 切り戻しを行い、`OBJATTRIBUTE`が`RPG`に戻り、12行が一致した(RPG III を通らないルートでは、上の囲みの印が手順1のときと同じに戻った)。`CRTDUPOBJ`に`REPLACE`が無いので、先に`DLTPGM`することを言える。
- [ ] `RUNTEST`を実行し、`PASS=0000000038 FAIL=0000000000`を読んだ。順序(`CHGCURLIB`・`DELETE`・`OVRDBF`)の理由を言える。
- [ ] `TXCKM`に`10-03`の6行を入れ、`TXCHECK`を1ジョブに1回だけ実行して、6・0を確かめた。
- [ ] `makei build`で、`ZAISRV`と`ZA0500`を作り直した。`makei`用のコピー側でだけ`ctl-opt`の2つのキーワードを外した理由を言える。
- [ ] `rpglint`を回し、直した(V3)。READMEとテスト結果を書き、未検証の項目に「未検証」と日付を付けた。
- [ ] 片付けで、作ったものを消し、確認の問い合わせで意図した結果になった。

## 片付け

このレッスンで作ったものを、次の順で削除します。**`TXCKM`・`TXCHECK`・`ZAISRV`・`JUCSRV`のような共有の道具は消しません**(10-04が使います)。`<自分のユーザー名>1`(開発用)は、何も変えていません。総称名は、自分で作ったものだけに当たるものだけを使います。

1. **(5250) `ZA0500`を旧プログラムに戻します。** 新が動いている状態なら、手順9の`DLTPGM`と`CRTDUPOBJ`で戻します。属性が`RPG`であることを確かめます(RPG III を通らないルートでは、`RPGLE` のままで、上の囲みの印が手順1のときと同じであることを確かめます)。

2. **(5250) 控えを消します。** 名前を指定して、1つだけ消します(`*ALL`や総称名は使いません)。

   ```text
   DLTPGM PGM(<自分のユーザー名>B/ZA0ORIG)
   ```

3. **(5250) 在庫を初期状態に戻します。** 手順の`*LIVE`の実行で書き換えた分です。

   ```text
   TXRESET LIB(<自分のユーザー名>2)
   ```

4. **(5250) このレッスンで作った表・行を消します。** `TESTRES`は、08-04など以前のレッスンで作った表を使い回していることがあります。**手順1で、`TESTRES`が無かったことを確かめてあるときだけ、`DROP`してください。** 以前からあるなら、`DROP`の代わりに`RUNSQL SQL('DELETE FROM <自分のユーザー名>2/TESTRES') COMMIT(*NONE)`で行だけ消します(一般知識。片付けの手順は未検証(2026-09-30時点))。

   ```text
   RUNSQL SQL('DROP TABLE <自分のユーザー名>2/W1003A') COMMIT(*NONE)
   RUNSQL SQL('DROP TABLE <自分のユーザー名>2/W1003B') COMMIT(*NONE)
   RUNSQL SQL('DROP TABLE <自分のユーザー名>2/TESTRES') COMMIT(*NONE)
   RUNSQL SQL('DELETE FROM <自分のユーザー名>2/TXCKM WHERE LESSON = ''10-03''') COMMIT(*NONE)
   ```

   `TXCKM`の`10-03`の行だけを消し、表は残します。

5. **(5250) `makei`が作った4つのオブジェクトを、名前で消します。** `<自分のユーザー名>B`に、自分で作った同じ名前のオブジェクトが無いことを、先に確かめてください。

   ```text
   DLTPGM PGM(<自分のユーザー名>B/ZA0500)
   DLTMOD MODULE(<自分のユーザー名>B/ZA0500)
   DLTSRVPGM SRVPGM(<自分のユーザー名>B/ZAISRV)
   DLTMOD MODULE(<自分のユーザー名>B/ZAISRV)
   ```

   期待される結果: `CPC2191`が4回(検証で確認。バッチは名前を指定した同じ形で消した)。

6. **(5250) このレッスンで作業用に`<自分のユーザー名>2`に置いたものを消します。** `TSTJUCSRV`・`TSTZAISRV`・`TSTZA0500`・`RUNTEST`・`TESTKIT`・`TESTKITBD`・`ZAISRVBD`・`JUCSRVBD`です。**手順5で、自分が複製したものだけです。** 以前から`<自分のユーザー名>2`にあったもの(手順5の確認の問い合わせに、最初から出たもの)は消しません。`ZAISRV`・`JUCSRV`は、08-08で昇格したものなので、消しません。

   ```text
   DLTPGM PGM(<自分のユーザー名>2/TSTJUCSRV)
   DLTPGM PGM(<自分のユーザー名>2/TSTZAISRV)
   DLTPGM PGM(<自分のユーザー名>2/TSTZA0500)
   DLTPGM PGM(<自分のユーザー名>2/RUNTEST)
   DLTSRVPGM SRVPGM(<自分のユーザー名>2/TESTKIT)
   DLTBNDDIR BNDDIR(<自分のユーザー名>2/TESTKITBD)
   DLTBNDDIR BNDDIR(<自分のユーザー名>2/ZAISRVBD)
   DLTBNDDIR BNDDIR(<自分のユーザー名>2/JUCSRVBD)
   ```

   `QRPGLESRC`に`TSTZA0500`のメンバーを入れた場合は、`RMVM FILE(<自分のユーザー名>2/QRPGLESRC) MBR(TSTZA0500)`で、そのメンバーだけを消します(**`QRPGLESRC`そのものは、10-04が使うので消しません**)。**`JU0900C`は、チケット1の修正版のまま残ります**(10-01の準備の状態。元の未修正版に戻すのは`TXLEGACY LIB(<自分のユーザー名>2) FORCE(*YES)`)。

7. **(SSH) 作業用のディレクトリーを消します。** **`$HOME/za-work`には、あなたが書いた`za0500s.sqlrpgle`の唯一のコピーがあります。** 演習(e)で、自分のリポジトリーにコミットして送ってあることを確かめてから消してください(まだなら、消さずに残します)。自分のリポジトリー(PC側)は消しません。

   ```sh
   rm -rf $HOME/mk10
   rm -rf $HOME/za-work
   ```

8. **(SSH) 確認します。**

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*PGM')) X WHERE OBJNAME IN ('ZA0500', 'RUNTEST', 'TSTZA0500')"
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>B', '*ALL')) X WHERE OBJNAME IN ('ZA0ORIG', 'ZA0500', 'ZAISRV')"
   db2 "SELECT COUNT(*) AS TXCKM_1003_LEFT FROM <自分のユーザー名>2.TXCKM WHERE LESSON = '10-03'"
   ```

   期待される結果: 1つ目は`ZA0500`が`RPG`の1行だけ(RPG III を通らないルートでは`RPGLE`)。2つ目は0行。3つ目は`0`。バッチの後始末は、名前を指定した削除と、`ZA0500`が`RPG`(旧プログラム)、`<自分のユーザー名>B`に`ZA0ORIG`・`ZA0500`・`ZAISRV`が無い(0行)ことを確認しました(V2)。この片付けの手順そのもの(5250から打った形、SSHの`rm`、`DLTBNDDIR`)は、通していません(未検証(2026-09-30時点))。

9. **スプール・ファイルと現行ライブラリー。** `SBMJOB`の5本のジョブ(`T1003A`〜`T1003E`)の`QSYSPRT`と`QPJOBLOG`を、`WRKSPLF`で見て、不要なら`4`で削除します。`CHGCURLIB`の変更は、サインオフで元に戻ります。同じジョブで続けるなら、`CHGCURLIB CURLIB(<自分のユーザー名>1)`で戻します。

## まとめ

| 英語 | 日本語 |
|---|---|
| Cutover | カットオーバー(旧を新に切り替えること) |
| Rollback | ロールバック・切り戻し(旧に戻すこと。`ZA0ORIG`から) |
| Golden master | ゴールデン・マスター(旧プログラムの出力を、比較の基準として保存したもの) |
| Characterization test | 特性検定(旧の振る舞いを、そのまま再現できているかを確かめる検査) |
| Regression test | 回帰テスト(直したあとに、他が壊れていないことを確かめるテスト) |
| Unlocked peek | ロックしない覗き見(`get()`) |
| Reproducible build | 再現できるビルド(他の人が同じ手順で同じ結果を得られる) |
| Lint | リント(規約違反の機械的な検査。`rpglint`) |

- 新しいメッセージ ID: `RNS9304`・`CPD0043`(`CRTSQLRPGI`)、`SQ20038`(`CREATE OR REPLACE TABLE ... AS`)。
- 決まり: 差し替えの前に、名前を付けた控えと、旧の出力を採る。`JU0900C`は必ず実行モードとライブラリーを付けて呼ぶ。`CRTDUPOBJ`には`REPLACE`が無いので、先に消す。`RUNTEST`は`CHGCURLIB`・`DELETE`・`OVRDBF`の順。`*CAT`と`*TCAT`の違い。`TXCHECK`は1ジョブに1回だけ。確かめていないことは「未検証」と書く。
- 次は、[10-04 API・振り返り](10-04-api-retrospective.md)です。部全体の位置づけは[第10部の扉](index.md)を参照してください。前のレッスンは[10-02 保守](10-02-maintenance-tokyusn.md)です。

## 実機メモ

- **確認日: 2026-09-30。バッチ`part10-03-modernize`(2回の接続。1回目は検証の道具の側の不具合で一部が失敗し、直したあとの2回目で`makei`以外の全項目を確認。`makei`の出力の中身は1回目の記録で確認し、2回目は実行して終了コード0までで、出力は詳しく見直していません)、PUB400。** 版と適用済みPTFは、このバッチの記録では確認していません(第9部の検証はV7R5M0)。検証は、著者の検証用ライブラリーで、CLラッパーの1つのジョブの中から行いました(`JU0900C`は`CALL`で直接呼び、印字文をハーネスが取り込みました)。学習者の`<自分のユーザー名>2`そのものでの再現は、個別には確認していません(未検証(2026-09-30時点))。検証の記録は、[プローブ記録](../probes.md)の「第10部」の節にあります(著者の非公開の実機記録(匿名化したバッチ結果)から書き起こしています)。
- **V2で確認できたこと**:
  - 新`ZA0500`が、ソース・メンバーから`CRTSQLRPGI ... OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)`(`ctl-opt bnddir('ZAISRVBD')`入り)で、`RNS9304`・最高重大度`00`で作れた。`OBJECT_STATISTICS`の`OBJATTRIBUTE`は`RPGLE`(`SQLRPGLE`ではない)。旧は`RPG`、切り戻し後も`RPG`。
  - `CRTSQLRPGI`は、`TGTCCSID`・`BNDDIR`を受け付けず(`CPD0043`)、`CVTCCSID(*JOB)`、および`CVTCCSID(*JOB)`と`COMPILEOPT('TGTCCSID(*JOB)')`の組み合わせは、`SRCSTMF`で`00`のまま作れた(作業用の別名のプログラム。実行はしていない)。
  - `*TEST`の印字文が、旧・新・新の2回目の呼び出し(同じジョブで`JU0900C`を続けて2回)・切り戻し後の4つとも、ゴールデン・マスターの12行(`OK`10・`SHORT`2)と一致した(空白を末尾から除いたあとのバイト単位の一致)。`*LIVE`は旧・新とも同じ12行(`J00007`の`P00005`だけ`SHORT`)。
  - `*LIVE`のあとの在庫が旧・新とも`P00001`〜`P00006`で39・3・235・48・9・20。旧・新の`EXCEPT`が両方向とも0行。`TXRESET`で45・3・250・60・12・22に戻った(`JUCHUM`8・`JUCHUD`12・`ZAIKOM`6)。
  - `RUNTEST`が`RUNTEST: PASS=0000000038 FAIL=0000000000`を送った(`TSTJUCSRV`・`TSTZAISRV`の23件と`TSTZA0500`の15件がすべて`PASS`。`TESTRES`の集計も38・38・0)。`TSTZA0500`の15件の値(A1 45・A2 12・B1〜B6 39・3・235・48・9・20・C1 5・C2 5・E0 Y・E1 Y・D1 -1・D2 Y・D3 39)。1回目の接続では、`DELETE`の`*TCAT`の不具合で`TESTRES`に古い行が残り、`PASS`・`FAIL`の件数のメッセージが出なかった。`*CAT`に直して通った。
  - `TXCHECK LESSON('10-03')`が6件`PASS`・0件`FAIL`(専用のヘルパー経由で1回)。
  - `makei build`が成功(4つのステップ)。`.sqlrpgle`のモジュールと、`*SRVPGM`を束縛する`*PGM`が、`Rules.mk`の4行で通った。属性は`RPGLE`。作ったオブジェクトを名前で削除した(`CPC2191`が4回)。
  - 埋め込みSQLのカーソルが、`JU0900C`の`OVRDBF JUCHUD SHARE(*YES)`と`OPNQRYF`の連鎖の下で開けて、出力が同じだった。旧の実行で`CPF4123`が2回、新の実行では出なかった。
- **確認の範囲に関する注意**:
  - **上の実行は、CLラッパーの中の、1つのバッチ・ジョブです。5250の対話式ジョブ、SSHからの`db2`の形の問い合わせ、`SBMJOB`で流してスプールを読む形は、確認していません。**
  - **印字の一致は、ハーネスが取り込んだ印字文の一致です。実際のスプール・ファイルの一致、`TXSNAP`、`CMPPFM`は、確認していません(V3)。**
  - `*TEST`の12行の比較の空白(先頭の1桁)が、実際のスプールにもあるかは、確かめていません。
  - 新`ZA0500`の`SRCSTMF`・`CVTCCSID(*JOB)`の形で作ったプログラムを、実行してはいません(実行したのは、ソース・メンバーから作ったプログラムです)。
  - `makei`は、`ZA0500`のソースのコピーから`dftactgrp(*no) actgrp(*new)`を外して成功しました。外さない形は、通していません。
  - 検証は、ビルド先を`<自分のユーザー名>B`に相当するライブラリーにして、`postUsrlibl`に作業用のライブラリーを入れました。ビルド先を開発用のライブラリーにする形は、通していません。
  - 部品(`TESTKIT`など)は、バッチではソースから作業用のライブラリーにビルドしました。開発用のライブラリーからの`CRTDUPOBJ`(手順5)は、通していません。
  - `RUNTEST`は、バッチでは`CRTCLPGM`で作りました(メンバーはハーネスが直接入れました)。手順10の`ADDPFM`・`CPYFRMSTMF`でメンバーを作る形と、`TXLOAD`で取り込む形は、実行していません。
  - `iproj.json`は、V2で確認したのは`objlib`・`curlib`・`postUsrlibl`の3項目の最小の形です。手順12の`sed`、`SRCSTMF`の形に`REPLACE(*YES)`を付けた実行も、通していません。`RUNTEST`には、ライブラリー名をそのまま渡しました(バッチも同じ)。
  - `E1`(ロックを漏らさないことの見張り)は、証明ではありません(`ACTGRP(*NEW)`)。ロックを漏らさない、という主張の根拠は、作りと、`JU0900C`の2回目の呼び出しが正常だったことです。
- **RPG III を通らないルート(2026-10-01追記)**: この本文の実測(`OBJATTRIBUTE` の `RPG`・`RPGLE`、12行、`*LIVE` の在庫、`RUNTEST` の38件)は、すべて RPG III 版の旧 `ZA0500` に対するものです。旧が固定形式 RPG IV 版のときの新旧を見分ける印、12行・在庫・`CPF4123` は、検証バッチ `part10-03-rpgle` で確かめました(下の追記)。
- **RPG III を通らないルートの結果(2026-10-04追記。バッチ`part10-03-rpgle`、2026-10-04、PUB400、V7R5M0)**: `<自分のユーザー名>2` で、`TXLEGACY` を `LANG(*RPGLE)` で読み込み(旧 `ZA0500` が `OBJATTRIBUTE` = `RPGLE`)、チケット1の修正後に、旧・新(`CRTSQLRPGI`、`ZAISRV` を束縛)・切り戻し後の順に、`*TEST` と `*LIVE` を`SBMJOB`で流しました(V2。5250の画面からではありません)。最後に `LANG(*RPG)` で RPG III 版へ戻し、`ZA0500`・`JU0300`・`TK0100` が `RPG`、行数が 8・12・6、在庫の合計が392に戻ったことを確かめました。
  - **印**: `BOUND_SRVPGM_INFO` に `ZAISRV` の行があるのは新だけ(旧・切り戻し後は `QSYS` の4行)。ほかに `SQL_STATEMENT_COUNT`(0 と 10)、`ACTIVATION_GROUP`(`*DFTACTGRP` と `*NEW`)、`SOURCE_FILE`(`QRPGLE112` と `QRPGLESRC`)も違います。`OBJATTRIBUTE`・`MODULE_ATTRIBUTE`・`PROGRAM_ATTRIBUTE` は、新旧とも `RPGLE` です。`OBJTEXT` は、旧が `Stock allocation`、新が空(`TEXT` を付けなかったため)でしたが、印にはしません。列名 `PROGRAM_LIBRARY`・`PROGRAM_NAME` は正しいことを確認しました。
  - **出力**: 旧 ILE 版の `*TEST` の12行は、RPG III 版のゴールデン・マスターと空白を除いて一致。`*LIVE` の在庫は 39・3・235・48・9・20(旧・新で `EXCEPT` が0行)。`CPF4123` は、旧(切り戻し後を含む)で各ジョブに1回出て、新では出ませんでした(RPG III 版は2回)。
  - **未確認**: `db2` をSSHから打った形、`makei`・`SRCSTMF` で作った新 `ZA0500` での印の値、旧だけ `CPF4123` が出る理由。バッチは `TXLEGACY` の控え(`LG261004`)の上書き確認に取り消しで答えており(`CPA4067`)、控えは更新していません。
- **未検証(2026-09-30時点。ルートの項目は上の追記のとおり 2026-10-04時点)**:
  - 骨組み(`za0500s-skeleton.sqlrpgle`)から学習者が書いた`ZA0500`の動き(実機で動かしたのは、模範解答です)。骨組みがそのままコンパイルできるかも、確認していません。
  - `reserve()`が`*off`を返す経路(別のジョブとの競合、`MINQTY`が負の場合)。`DBVER`が2の環境での動き。
  - SQLのカーソルが`OVRDBF`・共有の開きを尊重するか、`CPF4123`が新の実行で出なかった原因。
  - `rpglint`の実行と件数(`solutions/07-05/zaisrv.rpgle`の罫線コメント8行は`grep`で数えた値です)、`rpglint`が0件になること。READMEとテスト結果の成果物(書式の骨組みは設計であり、学習者が書いたものの評価は未実施)。
  - 手順1〜11の5250での通し実行、`WRKSPLF`・`DSPJOBLOG`の画面、`TXCHECK`の5250での実行、`DLTBNDDIR`・`rm`などの片付けの操作。時間の目安(240分の内訳)。
  - PTFレベルの下限。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
