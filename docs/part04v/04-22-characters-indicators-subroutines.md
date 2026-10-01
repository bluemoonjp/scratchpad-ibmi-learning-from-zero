# 04-22 文字・標識・サブルーチン(固定形式 RPG IV)

> 所要時間: 90分(長め)/ 前提レッスン: 04-21 / 目標番号: 3 / 観測方法: `WRKSPLF` / 道具: 5250(PDM/SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/V0422A`・`V0422B`・`V0422C`(演習の解答用に `V0422D`〜`V0422G`、読解演習用に `V0422P`)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `MOVE`・`MOVEL` の違い(右詰め・左詰め)と、**古いデータが残る罠**を説明し、`CLEAR` と `(P)` の2通りで防げる。
- `COMP` の結果標識(71〜76桁目)と条件標識(9〜11桁目)で、行の実行を切り替えられる。
- `IFxx`/`ELSE`/`DOWxx`/`EXSR`/`BEGSR`/`ENDSR` を固定形式で書ける。`CABxx`・`CASxx` は**読める**(書けなくてかまいません)。

## ウォームアップ

<details><summary>前回の復習(04-21)</summary>

1. 固定形式 RPG IV の C 仕様書で、命令コードは何桁目から書く?
2. ソース物理ファイル `QRPGLESRC` のレコード長はいくつで作る?
3. 固定形式 RPG IV のプログラムを作るコマンドは?

答え: 1. 26桁目から(26〜35桁目) 2. 112 3. `CRTBNDRPG`

</details>

## なぜ学ぶか

現場の固定形式 RPG IV ソースを読むと、`MOVEL` や `MOVE` で文字を詰め替える処理、`COMP` の結果標識を `30`・`31` のような番号で受けて分岐する処理、`IFxx`・`DOWxx`・サブルーチンの組み合わせが、ほぼ必ず出てきます。このレッスンでは、この3種類を**固定形式 RPG IV の桁位置のまま**、実際に動かして身につけます。

特に `MOVE`/`MOVEL` は、**代入のようでいて代入ではありません。** 「結果フィールドの、書き換えなかった部分に古いデータが残る」という罠を、ここで一度体験しておくと、現場のコードでこの罠が原因の不具合を見つけられるようになります。

このレッスンで作る `V0422A` と `V0422C` は、第6部で「古い書き方」の見本として再登場します。`V0422A` は [06-06](../part06/06-06-bifs-strings-and-dates.md)(文字列処理を `%BIF` で書き直すレッスン)の、`V0422C` は [06-03](../part06/06-03-free-form-basics.md)(完全自由形式の入門)の、それぞれ「書き換え前」の比較対象です。

## 新出

- 中核概念(3つ)
  1. `MOVEL`/`MOVE`(転記)と、古いデータが残る罠。`CLEAR` と `(P)` で防ぐ。
  2. 標識(インジケーター)・`COMP` の結果標識・条件標識。
  3. 構造化命令(`IFxx`・`DOWxx`)とサブルーチン(`BEGSR`・`EXSR`・`ENDSR`)。
- 構文(補助)
  - `Z-ADD`・`ADD`(04-21 で学習済み。下で一言だけ復習)、`SETON`・`SETOFF`、`*IN30` のような標識の直接参照。
- 読解用(この上限には数えません): `CABxx`・`TAG`・`CASxx`・`ENDCS`。

## 説明

### RPG III との違いを知らなくてよい

このレッスン(と第4部V全体)は、RPG III を学んでいない読者のためのルートです。**RPG III の知識は一切前提にしていません。** 以降の説明は、すべて固定形式 RPG IV だけで完結しています。

なお、`V0422A`・`V0422B`・`V0422C` は、別ルート(RPG III 版)の `R0403A`・`R0404A`・`R0405A` と**同じ出力**になるように作ってあります。これは第6部の比較を、どちらのルートの読者にも同じ数値で行うためです。RPG III 版を読む必要はありません。

### 固定形式 RPG IV の仕様書と桁位置(このレッスンで使う分)

このレッスンのプログラムは H・F・D・C・O の5種類の仕様書を使います。桁位置の一次資料は、ILE RPG リファレンス(`ilerpgref75.txt` の C 仕様書の桁見出し `CL0N01Factor1+++++++Opcode(E)+Factor2+++++++Result++++++++Len++D+HiLoEq` の行)です。

| 欄(C 仕様書) | 桁 |
|---|---|
| 仕様書の種類 | 6(`C`) |
| 制御レベル | 7〜8 |
| 条件標識 | 9(`N` = 否定)・10〜11(標識番号) |
| Factor 1 | 12〜25 |
| 命令コード(`(P)` のような拡張も、ここ) | 26〜35 |
| Factor 2 | 36〜49 |
| 結果フィールド | 50〜63 |
| 長さ | 64〜68 |
| 小数桁数 | 69〜70 |
| 結果標識(HI / LO / EQ) | 71〜72 / 73〜74 / 75〜76 |

**条件標識は9〜11桁目の1組だけです**(否定の `N` と標識番号2桁)。複数の条件を組み合わせたいときは、後で説明する `IFxx`・`ANDxx` を使います。なお、旧システムのソースには、7〜8桁目に `AN`(または `OR`)と書いた行を重ねて条件標識を増やす書き方(`CAN 92` のような行)もあります。これは**読解用**で、書けなくてかまいません(04-25 で扱います)。

D 仕様書(変数の宣言)の桁位置は、次のとおりです。

| 欄(D 仕様書) | 桁 |
|---|---|
| 仕様書の種類 | 6(`D`) |
| 名前 | 7〜21 |
| 宣言の種類(単独の変数は `S`) | 24〜25 |
| 長さ | 33〜39(右詰め) |
| データ型(`A` 文字、`P` パック10進数) | 40 |
| 小数桁数 | 41〜42(右詰め) |

O 仕様書は、ファイル名・タイプの行(`OQSYSPRT   E`。`E` は17桁目)と、その下に続くフィールド・定数の行からなります。フィールド名は30桁目から、**出力する最後の桁位置(終了位置)は47〜51桁目**(右詰め)、定数は53桁目から書きます。

**ソースの桁位置は、自分で数えずに、エディターの桁ものさしや SEU の `F4` プロンプトで確認してください。** 桁がずれると、次の「実演」のコンパイルエラーになります。

### 使う数値命令を1行ずつ

04-21 で学んだ命令のうち、このレッスンで使う分だけ復習します。

- `Z-ADD`(Zero and Add): 結果フィールドをゼロにしてから Factor 2 を足します。実質的な**代入**です。`Z-ADD 15 STOCK` は `STOCK` に 15 を入れます。
- `ADD`: Factor 1 を省略すると、Factor 2 を結果フィールドに**足し込みます**。`ADD 1 I` は `I` を 1 増やします。

このレッスンでは、結果フィールドは D 仕様書で宣言したフィールドです(04-21 は C 仕様書の結果フィールドで宣言しましたが、このレッスンは D 仕様書を使います。`P` はパック10進数)。

### MOVE と MOVEL は「詰め方」が違う

どちらも Factor 2 の内容を結果フィールドへ転記する命令ですが、**詰める向きが逆**です。

- `MOVEL`(MOVE Left): 結果フィールドの**左(先頭)**から詰めます。Factor 2 が短ければ、**右側の余った部分は変わりません。**
- `MOVE`: 結果フィールドの**右(末尾)**から詰めます。Factor 2 が短ければ、**左側の余った部分は変わりません。**

「変わりません」は「空白になる」ではなく、**その場所に前から入っていた値がそのまま残る**という意味です(一次資料: ILE RPG リファレンスの `MOVE`・`MOVEL` の説明)。

### 罠: 古いデータが残る

結果フィールドを**初めて**使うときは、フィールドの中身は空白(文字)またはゼロ(数値)なので、この罠には気づきません。危険なのは、**同じフィールドに、前より短い値を2回目以降に転記したとき**です。

```text
NAME2 に MOVEL 'JOHNSON'  → NAME2 = 'JOHNSON   '(10桁、右側3つは初期値の空白)
NAME2 に MOVEL 'AL'       → NAME2 = 'ALHNSON   '(左2桁だけ書き換わり、'HNSON' が残る!)
```

防ぎ方は2通りあります。

1. **転記の前に `CLEAR` でフィールドを空にしておく。** 固定形式 RPG IV では、`CLEAR` の対象フィールドは**結果フィールド(50〜63桁目)**に書きます(Factor 1 は `*NOKEY`、Factor 2 は `*ALL` の指定用で、単独の変数をクリアするときは使いません)。文字フィールドなら空白に、数値フィールドならゼロになります。
2. **命令に `(P)` を付ける**(`MOVEL(P)`・`MOVE(P)`)。Factor 2 が短いとき、結果フィールドの余った部分を空白でうめます(`MOVEL(P)` は右側、`MOVE(P)` は左側)。`(P)` は命令コード欄(26〜35桁目)の中に、命令の直後に続けて書きます。

### 標識とは

**標識は、01〜99の番号が付いた、ON か OFF かの1ビットのフラグです。** プログラムのどこからでも参照・設定できる、いわば「グローバルなブール変数」です。`SETON`/`SETOFF` で直接 ON/OFF を切り替えられるほか、`COMP` のような命令の**結果**として自動的に ON になることもあります。`LR`(最終レコード標識)は、標識の中でも特別な意味を持ちます。固定形式 RPG IV の本プログラムでは、`SETON ... LR` でプログラムを終わらせます。

標識は `*IN30` のような名前で、**データとして**参照することもできます。`*ON`・`*OFF` はその値を表す定数です。`C     *IN30         IFEQ      *OFF` は「標識30が OFF なら」という意味になります。

### COMP で比較する

```text
C     STOCK         COMP      THRESH                             303132
```

`STOCK`(Factor 1)と `THRESH`(Factor 2)を比較し、**結果標識**(71〜76桁目、2桁ずつ3つ)に応じた標識を立てます。

| 結果標識の位置 | 意味 | このコードでの例 |
|---|---|---|
| 71〜72桁目(HI) | Factor 1 > Factor 2 のとき ON | `30` |
| 73〜74桁目(LO) | Factor 1 < Factor 2 のとき ON | `31` |
| 75〜76桁目(EQ) | Factor 1 = Factor 2 のとき ON | `32` |

3つのうち、**必ずどれか1つだけが ON になります。**

### 条件標識で行の実行を制御する

C 仕様書の9〜11桁目に標識を書くと、**その行は、標識が ON のときだけ**実行されます。9桁目に `N` を書くと**否定**になり、標識が OFF のときだけ実行されます。

```text
     C   30              MOVEL     'OVER'        MSG
     C  N31              MOVEL     'OK'          FLAG
```

1行目は標識30が ON のとき、2行目は標識31が **OFF** のときだけ実行されます。`COMP` の結果を受けて、3つの標識(30/31/32)それぞれで条件付けした3行を用意すれば、「もし〜なら」を、標識を介して表現できます。

### IFxx / ELSE / ENDIF と ANDxx / ORxx

```text
     C     SCORE         IFGE      80
     C     SCORE         ANDLE     100
     C                   MOVEL     'A'           GRADE
     C                   ELSE
     C                   MOVEL     'B'           GRADE
     C                   ENDIF
```

`IFxx` は Factor 1 と Factor 2 を比較し、真なら `ELSE`(または `ENDIF`)までの行を実行します。`xx` には `EQ`(等しい)・`NE`(等しくない)・`GT`(より大きい)・`LT`(より小さい)・`GE`(以上)・`LE`(以下)のいずれかを書きます。標識の番号を意識せずに書けるので、**自分で書くときは、標識で分岐するより `IFxx` を使うほうが読みやすいコードになります。**

`IFxx` の直後に `ANDxx`/`ORxx` の行を続けると、条件を組み合わせられます。上のコードは「`SCORE` が80以上、**かつ**100以下」の意味です。

### DOWxx / ENDDO

```text
     C     I             DOWLE     5
     C                   ADD       I             SUM
     C                   ADD       1             I
     C                   ENDDO
```

`DOWxx`(Do While)は、条件が真である**間**、`ENDDO` までを繰り返します。`DOWLE`(以下である間)なら、`I` が5以下である間繰り返します。**繰り返しの中で `I` 自身を変化させないと、無限ループになります**(このコードでは `ADD 1 I` で1ずつ増やしています)。

### サブルーチン: EXSR / BEGSR / ENDSR

```text
     C                   EXSR      PRTOUT
     ...
     C     PRTOUT        BEGSR
     C                   EXCEPT
     C                   ENDSR
```

サブルーチンは、プログラムの中の「小さな別プログラム」のようなものです。`BEGSR`(Factor 1 にサブルーチン名)から `ENDSR` までが本体で、`EXSR`(Factor 2 にサブルーチン名)で呼び出します。パラメーターは受け取らず、変数はプログラム全体で共有します。**サブルーチンの本体は、メインの計算(`SETON LR` を含む)の後ろにまとめて書きます。**

### 読解用: CABxx・TAG・CASxx

古いコードには、`IFxx` が無かった時代の分岐命令が残っています。**書く必要はありません。見て意味が分かれば十分です。**

- `TAG`(Factor 1 にラベル名): 飛び先の目印です。
- `CABxx`(Compare and Branch): Factor 1 と Factor 2 を比較し、条件が真なら**結果フィールドのラベルへ飛びます**(`CABLT` なら「Factor 1 が Factor 2 より小さければ」)。条件が偽なら次の行へ進みます。
- `CASxx`(Conditionally invoke Subroutine): 比較が真なら、**結果フィールドのサブルーチン**を実行します。`CASxx` を並べた最後に、比較の無い `CAS` を置くと「どれにも当てはまらないとき」の指定になります。並びは必ず `ENDCS` で閉じます。

`CABxx` で飛ぶと、処理の流れが追いにくくなります(自分で書くときは `DOWxx` と `IFxx` を使います)。

## 実演

事前に、04-21 で作った `<USER>1/QRPGLESRC`(レコード長 112)があることを確認してください。以下の3本を、04-21 の手順で作ります(ソースの種類は `RPGLE`)。ソースは配布しているファイルと同じ内容です。

### 1. V0422A: MOVE/MOVEL の罠(`src/qrpglesrc/v0422s.rpgle`)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0422A - MOVE/MOVEL leave old data behind; CLEAR first to avoid it.
      * Fixed-form RPG IV port of R0403A (04-03). Same print line.
      * Expected: A=JOHNSON     B=ALHNSON     C=123456  D=1234AB  E=BOB
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DNAME1            S             10A
     DNAME2            S             10A
     DNAME3            S             10A
     DCODE1            S              6A
     DCODE2            S              6A
     C                   MOVEL     'JOHNSON'     NAME1
     C                   MOVEL     'JOHNSON'     NAME2
     C                   MOVEL     'AL'          NAME2
     C                   MOVE      '123456'      CODE1
     C                   MOVE      '123456'      CODE2
     C                   MOVE      'AB'          CODE2
     C                   MOVEL     'XX'          NAME3
     C                   CLEAR                   NAME3
     C                   MOVEL     'BOB'         NAME3
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            2 'A='
     O                       NAME1               12
     O                                           16 '  B='
     O                       NAME2               26
     O                                           30 '  C='
     O                       CODE1               36
     O                                           40 '  D='
     O                       CODE2               46
     O                                           50 '  E='
     O                       NAME3               60
```

`A`=`NAME1`(`MOVEL` で初めて使用)、`B`=`NAME2`(`MOVEL` を2回。罠が起きる)、`C`=`CODE1`(`MOVE` で初めて使用)、`D`=`CODE2`(`MOVE` を2回。罠が起きる)、`E`=`NAME3`(`CLEAR` してから `MOVEL`。罠が起きない)です。

**O 仕様書の最初の行(`OQSYSPRT   E`)には、ファイル名とタイプだけを書き、出力するフィールドや定数は次の行以降に1つずつ書きます。** 命令コードの `EXCEPT` は、この `E` の行(出力レコード)を印刷します。

コンパイルして実行します。

```text
CRTBNDRPG PGM(<USER>1/V0422A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(V0422A)
CALL PGM(<USER>1/V0422A)
```

`WRKSPLF` で、次のように印刷されることを確認します(`R0403A` で実機確認済みの出力と同じになるよう作ってあります)。

```text
A=JOHNSON     B=ALHNSON     C=123456  D=1234AB  E=BOB
```

**`B` が `ALHNSON`**(`MOVEL 'AL'` で先頭2桁だけ書き換わり、`HNSON` が残った)、**`D` が `1234AB`**(`MOVE 'AB'` で末尾2桁だけ書き換わり、`1234` が残った)、これが「古いデータが残る罠」です。**`E` は `BOB` だけで正しく埋まっています**(`CLEAR` してから `MOVEL` したため)。

### 2. V0422B: 標識と COMP(`src/qrpglesrc/v0422bs.rpgle`)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0422B - indicators and COMP: is stock below the reorder point?
      * Fixed-form RPG IV port of R0404A (04-04). Prints REORDER.
      * COMP result indicators are in columns 71-76 here (54-59 in RPG III).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSTOCK            S              5P 0
     DTHRESH           S              5P 0
     DMSG              S             10A
     C                   Z-ADD     15            STOCK
     C                   Z-ADD     20            THRESH
     C     STOCK         COMP      THRESH                             303132
     C   30              MOVEL     'OVER'        MSG
     C   31              MOVEL     'REORDER'     MSG
     C   32              MOVEL     'EQUAL'       MSG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       MSG                 40
```

在庫数(`STOCK`=15)が発注点(`THRESH`=20)を下回っているかを判定する、という想定です。コンパイル・実行(`CRTBNDRPG PGM(<USER>1/V0422B) ...`、`CALL PGM(<USER>1/V0422B)`)し、`WRKSPLF` で `REORDER` とだけ印刷されること(31桁目から。行頭の30桁は空白)を確認します。`STOCK` が `THRESH` を下回るので標識31(LO)だけが ON になり、その行の `MOVEL` だけが実行されます。出力は `R0404A` と同じです。

D 仕様書の `5P 0` は「5桁・小数0桁のパック10進数」です。

### 3. V0422C: 構造化命令とサブルーチン(`src/qrpglesrc/v0422cs.rpgle`)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0422C - structured opcodes (IFxx/ANDxx/DOWxx) and a subroutine.
      * Fixed-form RPG IV port of R0405A (04-05).
      * Expected: A             SUM= 00015
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSCORE            S              3P 0
     DSUM              S              5P 0
     DI                S              3P 0
     DGRADE            S             10A
     C                   Z-ADD     82            SCORE
     C                   Z-ADD     0             SUM
     C                   Z-ADD     1             I
     C     SCORE         IFGE      80
     C     SCORE         ANDLE     100
     C                   MOVEL     'A'           GRADE
     C                   ELSE
     C                   MOVEL     'B'           GRADE
     C                   ENDIF
     C     I             DOWLE     5
     C                   ADD       I             SUM
     C                   ADD       1             I
     C                   ENDDO
     C                   EXSR      PRTOUT
     C                   SETON                                        LR
     C     PRTOUT        BEGSR
     C                   EXCEPT
     C                   ENDSR
     OQSYSPRT   E
     O                       GRADE               10
     O                                           18 '  SUM='
     O                       SUM                 24
```

`SCORE`(82点)を成績(`GRADE`)に変換し、`1` から `5` までの合計を `SUM` に求め、印刷はサブルーチン `PRTOUT` にまとめています。コンパイル・実行(`V0422C`)し、`WRKSPLF` で次のように印刷されることを確認します(82点は「80以上100以下」なので `A`。`1+2+3+4+5=15`。`R0405A` と同じ出力です)。

```text
A             SUM= 00015
```

### コンパイルに失敗したとき

桁位置の書き間違いは、コンパイル時のエラーメッセージ(`RNF`・`RNS` で始まる ID)で分かります。**ILE RPG のメッセージ ID は `RNF`・`RNS`(コンパイル時)・`RNQ`・`RNX`(実行時)で始まります**([付録B](../appendix/b-message-ids.md)参照)。コンパイルの詳しい一覧は、`CRTBNDRPG` が出力するコンパイル・リスト(スプール・ファイル)で見ます。

## 演習

1. `V0422A` の `NAME2`・`CODE2` への**2回目**の `MOVEL`/`MOVE` の前に `CLEAR` を1行ずつ追加して、罠が起きなくなることを確認してください。期待する印刷は、`B` が `AL` だけ(右は空白)、`D` の `AB` の左に空白が4つ付いた行です。`CLEAR` の対象を書く桁に注意してください(ヒント: 結果フィールドです)。
2. 演習1の `CLEAR` を使わずに、`MOVEL(P)`・`MOVE(P)` で同じ結果にしてください(ヒント: `(P)` は命令の直後です)。
3. `V0422B` の `STOCK` を `25` に変えて `OVER` が、`20` に変えて `EQUAL` が印刷されることを確認してください。
4. `V0422B` に、**標識31が OFF のとき**(9桁目に `N`、10〜11桁目に `31`)だけ別のフィールド `FLAG`(2桁)へ `'OK'` を入れる行を追加し、`SETOFF` で標識30を OFF にしたあと、`*IN30` が `*OFF` であることを `IFEQ` で調べて、結果を `ST30`(3桁)に `'OFF'` と入れてください。`STOCK` は `25` にします。`MSG`・`FLAG`・`ST30` を同じ行に印刷してください。
5. `V0422C` の `SCORE` を `55` に変えて `B` が、`DOWLE 5` を `DOWLE 10` に変えて合計 `00055` が印刷されることを確認してください。
6. `V0422C` に、`SCORE` が `0` 未満**または** `100` を超える場合に `GRADE` を `'X'`(不正な値)にする分岐を、`IFxx`/`ORxx` を使って追加してください。`SCORE` は `120` にします。
7. (読解)次のプログラム `V0422P` を実行する**前に**、印刷される内容を紙に書いて予想してください。ヒント: `CABLT` の行で何回ループするか、`CASGT`・`CASEQ`・`CAS` のうち実行されるのはどれか。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0422P - reading sample for CASxx/CABxx/TAG (04-22, read only).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DN                S              3P 0
     DI                S              3P 0
     DSUM              S              5P 0
     DOUT              S             10A
     C                   Z-ADD     7             N
     C                   Z-ADD     0             I
     C                   Z-ADD     0             SUM
     C     LOOP          TAG
     C                   ADD       1             I
     C                   ADD       I             SUM
     C     I             CABLT     5             LOOP
     C     N             CASGT     5             BIG
     C     N             CASEQ     5             FIVE
     C                   CAS                     SMALL
     C                   ENDCS
     C                   EXCEPT
     C                   SETON                                        LR
     C     BIG           BEGSR
     C                   MOVEL     'BIG'         OUT
     C                   ENDSR
     C     FIVE          BEGSR
     C                   MOVEL     'FIVE'        OUT
     C                   ENDSR
     C     SMALL         BEGSR
     C                   MOVEL     'SMALL'       OUT
     C                   ENDSR
     OQSYSPRT   E
     O                       OUT                 10
     O                       SUM                 16
```

答えと模範解答は `solutions/04-22/` にあります(演習1は `v0422d.rpgle`、演習2は `v0422e.rpgle`、演習4は `v0422f.rpgle`、演習6は `v0422g.rpgle`、演習7は `v0422p.rpgle`。演習3と5は値を書き換えるだけです)。

## セルフチェック

- [ ] `MOVE`/`MOVEL` の詰める向きの違いを説明できる。
- [ ] 「古いデータが残る罠」を再現し、`CLEAR`(対象は結果フィールド)と `(P)` の2通りで防げた。
- [ ] `COMP` の結果標識が71〜76桁目で、HI/LO/EQ の順であることを言える。
- [ ] 条件標識(9〜11桁目)の `N`(否定)の意味を説明できる。
- [ ] `IFxx`・`ANDxx`・`ORxx`・`DOWxx`・サブルーチンを固定形式で書けた。
- [ ] `CABxx`・`CASxx` が出てきたとき、どこへ飛ぶ・何を実行するかを読み取れる。

## 片付け

作成したプログラムは、第6部の比較で使うので、そのまま残してください。演習の解答用に作った分は、次のコマンドで消せます。

```text
DLTPGM PGM(<USER>1/V0422D)
DLTPGM PGM(<USER>1/V0422E)
DLTPGM PGM(<USER>1/V0422F)
DLTPGM PGM(<USER>1/V0422G)
DLTPGM PGM(<USER>1/V0422P)
```

## まとめ

| 英語 | 日本語 |
|---|---|
| Figurative constant | 図形定数(`*ON`・`*OFF` など) |
| Pad | 空白でうめる |
| Indicator | 標識(インジケーター) |
| Resulting indicator | 結果標識 |
| Conditioning indicator | 条件標識 |
| Structured opcode | 構造化命令 |
| Subroutine | サブルーチン |
| Compare and branch | 比較して分岐(`CABxx`) |

次のレッスン(04-23)では、外部記述ファイルの読み書きを、固定形式 RPG IV で書きます([04-23](04-23-external-files.md))。

## 実機メモ

- 確認日: **未検証(2026-10-01時点)**。`V0422A`〜`V0422G`・`V0422P` はいずれも、まだ PUB400 でコンパイル・実行していません。検証用のバッチは `verify/part04v-22cmp/` にあり、実機で確認したあと、このメモを実測値で書き直します。
- 確認済みの事実は、このレッスンの元になった別ルートの結果だけです。`R0403A`・`R0404A`・`R0405A` が実機で `A=JOHNSON     B=ALHNSON     C=123456  D=1234AB  E=BOB`・`REORDER`・`A             SUM= 00015` を印刷したことは、別の機会に確認されています。**`V0422A`〜`V0422C` が同じ出力になることは、本レッスンの設計上の狙いであり、未検証です。**
- 桁位置の根拠: ILE RPG リファレンス(`ilerpgref75.txt`)の、条件標識(9〜11桁目)・C 仕様書の見出し行・Table 125(結果標識 71〜76)・`CABxx`/`CASxx`・`CLEAR`(結果フィールドに対象を書く)・`MOVE`/`MOVEL`(`(P)` の説明)の各節、および実機で動作確認済みの `v0601s.rpgle`・`v0601bs.rpgle` の F・O・D・C 仕様書の形です。
- 未検証の事項(2026-10-01時点):
  - 制御仕様書 `H DFTACTGRP(*YES)`(`CRTBNDRPG` の既定と同じ指定)がそのままコンパイルできること。
  - D 仕様書で宣言した `P`(パック10進数)のフィールドが、編集コードなしの O 仕様書で `00015` のように前ゼロつきの数字で印刷されること。
  - `MOVEL(P)`・`MOVE(P)` の拡張が、命令の直後(スペース無し)の形で受け付けられること。
  - 演習の解答(`V0422D`〜`V0422G`)・読解用 `V0422P` の出力。いずれも手計算した値です。
  - 次の RPG III の癖をそのまま持ち込んだときのメッセージ ID と重大度(コンパイルエラーの一覧):

    | 持ち込んだもの | 原因 | メッセージ ID |
    |---|---|---|
    | `EXCPT`(命令名を略した綴り) | 固定形式 RPG IV の命令名は `EXCEPT` | (実機で確認後に記入) |
    | `COMP` の結果標識を54〜59桁目に書く | RPG IV では71〜76桁目 | (実機で確認後に記入) |
    | `CLEAR` の対象を Factor 2 に書く | RPG IV では結果フィールド | (実機で確認後に記入) |
    | RPG III のソースを、そのまま `QRPGLESRC` に貼る | F・C・O のすべての桁位置がずれる | (実機で確認後に記入) |

- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
