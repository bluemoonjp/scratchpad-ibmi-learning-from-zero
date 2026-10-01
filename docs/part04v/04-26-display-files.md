# 04-26 表示装置ファイルと画面の入出力(固定形式 RPG IV)

> 所要時間: 90分(長め)/ 前提レッスン: 04-25(あわせて 04-22・04-23)/ 目標番号: 3 / 観測方法: 画面そのもの / 道具: 5250(PDM/SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/D0426A`・`<USER>1/D0426B`(DSPF)、`<USER>1/V0426A`・`<USER>1/V0426B`(RPGLE)。演習で `V0426C`〜`V0426E`・`D0426D`・`D0426E` / DBVER: 1 / 依存するプローブ: なし(DDS の桁位置は [04-11](../part04/04-11-display-file-inquiry.md) の実機確認に依拠)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- `04-26-1`: 表示装置ファイル(DSPF)の DDS で照会画面を書き、固定形式 RPG IV の F 仕様書・C 仕様書で `EXFMT` を使って動かせる。RPG III 版 `R0411A` と**同じ画面・同じ動き**になることを確かめられる。
- `04-26-2`: 固定形式 RPG IV の F 仕様書(17・18・22・36・44桁目)・C 仕様書(12・26・36・50桁目)の桁位置と、結果標識の位置(`CHAIN` は71桁目、`READ` は75桁目)、条件標識が1個だけであることを言える。
- `04-26-3`: サブファイルの DDS(`SFL`・`SFLCTL`・`SFLDSP`・`SFLDSPCTL`・`SFLSIZ`・`SFLPAG`)の役割と、RPG 側の `SFILE` キーワード・RRN(相対レコード番号)の関係を説明できる。`SFLCLR`・`SFLEND` は「読めれば十分」のものとして区別できる。

## ウォームアップ

<details><summary>前回までの復習</summary>

1. 固定形式 RPG IV の C 仕様書で、命令コードは何桁目から書きますか? Factor 1 は何桁目からですか?
2. RPG IV のソースを入れるソース物理ファイルの名前とレコード長、メンバーのソース・タイプは何ですか(04-21)?
3. RPG IV の `CHAIN` で「見つからなかった」ことを受け取る標識は、結果標識欄のどこに書きますか?

答え: 1. 命令コードは26桁目から、Factor 1 は12桁目からです。 2. `QRPGLESRC`・レコード長112・ソース・タイプ `RPGLE` です。 3. 71〜72桁目です。

</details>

## なぜ学ぶか

**業務の RPG は、帳票だけでなく画面(5250)も必ず扱います。** 得意先コードを入力して名前を確認する照会画面、一覧を `Page Down` でめくる一覧画面は、固定形式の RPG IV を使う現場でも最もよく目にする、画面プログラムの基本形です。

このレッスンは、**RPG III の経路(第4部・第5部)を通らずに**第6部へ進む読者のために、`R0411A`(04-11)の画面を固定形式 RPG IV でそのまま作り直します。RPG III の学習は前提にしません。ここで作る `D0426A`・`V0426A` は、第6部の 06-04・06-10・06-11 で自由形式(`**FREE`)へ書き換えるときの「書き換え前」として再び登場します。

**画面は非対話では動かせません。** `EXFMT` は5250の画面でキーが押されるまで待つので、この教材の検証ハーネスでは、コンパイルが通ることまでしか確かめられません。**画面の動きそのものは、読者が自分で5250から試して確認します**(実機メモを参照)。

## 新出

### 中核(3つ)

- **WORKSTN ファイルの F 仕様書**: ファイル型 `C`・指定 `F`・様式 `E`・装置 `WORKSTN`。サブファイルを使うときは、44桁目からのキーワード `SFILE(様式名:RRN)` を加える。
- **`EXFMT` と応答標識**: 画面を書いてから、キーが押されるまで待って読む。DDS の `CF03(03)` が、F3 を押したときに `*IN03` を ON にする。
- **サブファイル**: 画面の中に複数行を保持する仕組み。明細行の様式(`SFL`)と制御用の様式(`SFLCTL`)の2枚組で、行の番号が RRN。

### キーワード等(6つまで)

- `SFLSIZ`・`SFLPAG`: サブファイルが保持する行数と、1画面に出す行数。
- `SFLDSP`・`SFLDSPCTL`: 明細(行)と制御様式を表示してよいことを示す。
- `OVERLAY`: 画面を消さずに、上から重ねて書く。

### 読解用(書けなくても読めればよい)

`SFLCLR`・`SFLEND`・`READC`・`SFLNXTCHG`・メッセージ・サブファイル。このレッスンでは書きません。`SFLCLR`・`SFLEND` は説明の節で、一次資料の形を読みます。

## 説明

### RPG III との違い(早見表)

DDS は RPG のバージョンに依存しないので、**画面の DDS は RPG III の `R0411A` と全く同じ書き方**です。違うのは RPG のソースの桁位置です。左の列は、RPG III(第4部)を通ってきた読者が見比べるための参考です。RPG III を学んでいない読者は、右の列だけを読めば足ります。

| 項目 | RPG III(04-11) | 固定形式 RPG IV(このレッスン) |
|---|---|---|
| ファイル型(組み合わせ) | F仕様書 15桁目 `C` | F仕様書 17桁目 `C` |
| 完全手続き型 | 16桁目 `F` | 18桁目 `F` |
| 外部記述 | 19桁目 `E` | 22桁目 `E` |
| 装置 | 40〜46桁目 `WORKSTN` | 36〜42桁目 `WORKSTN` |
| キーワード | なし(サブファイルは継続行で指定) | 44桁目から(`SFILE(SFL1:RRN)`) |
| C 仕様書の Factor 1 | 18〜27桁目 | 12〜25桁目 |
| 命令コード | 28〜32桁目 | 26〜35桁目 |
| Factor 2 | 33〜42桁目 | 36〜49桁目 |
| 結果フィールド | 43〜48桁目 | 50〜63桁目 |
| `CHAIN` の「見つからない」標識 | 54〜55桁目 | 71〜72桁目 |
| `READ` の「ファイル終わり」標識 | 58〜59桁目 | 75〜76桁目 |
| 条件標識(C 仕様書) | 3個(9〜11・12〜14・15〜17桁目) | **1個だけ**(9〜11桁目) |

最後の行が、このレッスンで一番つまずきやすい点です。RPG III の `R0411A` には `C  N03 50` のように条件標識を2個並べた行がありましたが、**RPG IV の固定形式では条件標識は9〜11桁目の1個だけ**です(一次資料: ILE RPG リファレンス「Positions 9-11 (Indicators)」)。2個以上を条件にしたいときは、次のどちらかにします。

- `IFEQ`〜`ENDIF` で囲む(このレッスンの `V0426A` の方法)。
- `AN`(7〜8桁目)の行を使う。この書き方は読解用として知っておけば十分です(一次資料: ILE RPG リファレンス「AND/OR Lines Identifier」。このレッスンでは書かず、実機でも試していません)。

### 照会画面の DDS(`D0426A`)

`src/qddssrc/d0426s.dspf` は、04-11 の `src/qddssrc/r0411s.dspf` と**1文字も違わない**同じ内容です(レコード様式名も `INQFMT` のままです)。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     A                                      DSPSIZ(24 80 *DS3)
     A          R INQFMT
     A                                      CF03(03)
     A                                  1  2'Customer code:'
     A            TOKCD          6A  I  1 17
     A                                  3  2'Name:'
     A            TOKNM         30A  O  3  8
     A                                  5  2'F3=Exit'
```

38桁目が使用法(`I`=入力、`O`=出力、`B`=入出力)、39〜41桁目が行、42〜44桁目が桁です。`CF03(03)` は「F3 が押されたら標識03を ON にする」という宣言で、RPG 側では `*IN03` として読みます。出力フィールドの長さは、ファイル側の同名フィールドと一致させます(`TOKNM` は30)。

### F 仕様書(`V0426A`)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     FD0426A    CF   E             WORKSTN
     FTOKUIM    IF   E           K DISK
```

| 桁 | 内容 | `D0426A` の行 |
|---|---|---|
| 6 | 仕様書の種類 | `F` |
| 7〜16 | ファイル名 | `D0426A` |
| 17 | ファイル型 | `C`(組み合わせ。入力も出力もする) |
| 18 | 指定 | `F`(完全手続き型) |
| 22 | 様式 | `E`(外部記述) |
| 36〜42 | 装置 | `WORKSTN` |

18桁目が `F` でなければならない理由は、一次資料(ILE RPG リファレンス、`EXFMT`)に書かれています。「`EXFMT` は、完全手続き型の組み合わせファイルとして定義された、外部記述の WORKSTN ファイルにだけ使える」。RPG III で16桁目の `F` が必須だったのと同じ決まりが、RPG IV では18桁目になっただけです。同じ一次資料に「`EXFMT` では結果標識欄の71・72・75・76桁目を空欄にする」ともあります。

### H 仕様書と活動化グループ

`V0426A` の H 仕様書は、キーワードを書かない空の `H` 行だけです。`CRTBNDRPG` は、`DFTACTGRP`(既定の活動化グループ)の既定値が `*YES` です。つまり何も書かなくても、`H DFTACTGRP(*YES)` と書いたのと同じ扱いになります(06-01b の `V0601B` も、空の `H` 行でコンパイル・実行できています)。

### C 仕様書(`V0426A`)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     C     *IN03         DOWEQ     *OFF
     C                   EXFMT     INQFMT
     C     *IN03         IFEQ      *OFF
     C     TOKCD         CHAIN     TOKUIM                             50
     C   50              MOVEL     'NOTFOUND'    TOKNM
     C                   ENDIF
     C                   ENDDO
     C                   SETON                                        LR
```

`R0411A` との対応は次のとおりです。

| `R0411A`(RPG III) | `V0426A`(RPG IV) | 違い |
|---|---|---|
| `*IN03 DOWEQ *OFF` | 同じ(Factor 1 が12桁目、命令コードが26桁目) | 桁だけ |
| `EXFMT INQFMT` | 同じ | 桁だけ |
| `C  N03 TOKCD CHAIN TOKUIM 50` | `*IN03 IFEQ *OFF` で囲み、`CHAIN` の標識は71桁目 | 条件標識は1個だけなので、`N03` を `IF` に移した |
| `C  N03 50 MOVEL 'NOTFOUND' TOKNM` | `C   50` の1個だけの条件標識 | `N03` は外側の `IF` が受け持つ |
| `SETON LR` | 同じ(標識 `LR` は71〜72桁目) | 桁だけ |

外側の `IF` に入れ替えても動きは同じです。F3 が押されたとき(`*IN03` が ON)は、`CHAIN` も `MOVEL` も実行されずにループを抜けます。

**`MOVEL 'NOTFOUND' TOKNM` について。** `TOKNM` は30文字ですが、`'NOTFOUND'` は8文字です。`MOVEL` は左づめで8文字だけを書き換えるので、直前に見つかった得意先の名前の続き(9文字目以降)が残るはずです。`R0411A` の `MOVEL` も同じ理屈なので、`V0426A` は**あえて同じ動き**のままにしてあります。演習2で直します。

### ILE のメッセージ

`CRTBNDRPG` のコンパイル・メッセージは `RNF`(コンパイル時)、`RNQ`・`RNX`(実行時)など `RN` で始まるものです。RPG III の `QRG`・`RPG0xxx` とは別の体系です(付録 [B](../appendix/b-message-ids.md) に実機で出会った分があります)。わざと間違えた次の4本は、実機で確認してから ID を書き入れます。**まだ実測していません**。

| 間違いのソース | 何を間違えたか | 実機メモのメッセージ ID |
|---|---|---|
| `V0426X1` | 組み合わせ WORKSTN ファイルで18桁目が空欄(RPG III の `QRG2096` に当たる間違い) | (実機で確認後に記入) |
| `V0426X2` | サブファイルへ `WRITE SFL1` するのに、`SFILE` キーワードが無い | (実機で確認後に記入) |
| `V0426X3` | `SFILE(SFL1:RRN)` はあるが、`RRN` の D 仕様書が無い | (実機で確認後に記入) |
| `V0426X4` | C 仕様書に、RPG III の習慣で条件標識を2個並べた | (実機で確認後に記入) |

### サブファイルの DDS(`D0426B`)

サブファイルは、**明細行の様式(`SFL`)と、それを制御する様式(`SFLCTL`)の2枚組**です。`SFL` を書いた次の様式が、その `SFLCTL` になります。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     A*  D0426B - customer list (TOKUIM), load-all subfile (04-26).
     A*  No DDS conditioning indicators (see docs/probes.md).
     A                                      DSPSIZ(24 80 *DS3)
     A          R SFL1                      SFL
     A            TOKCD          6A  O  4  2
     A            TOKNM         30A  O  4 10
     A          R SFL1CTL                   SFLCTL(SFL1)
     A                                      SFLSIZ(9999)
     A                                      SFLPAG(14)
     A                                      SFLDSP
     A                                      SFLDSPCTL
     A                                      CF03(03)
     A                                      OVERLAY
     A                                  1  2'D0426B - Customer list (TOKUIM)'
     A                                  3  2'Code'
     A                                  3 10'Name'
     A          R SFL1FTR
     A                                      OVERLAY
     A            MORE          10A  O 20  2
     A                                 23  2'F3=Exit  Roll=Page'
```

| キーワード | 役割 |
|---|---|
| `SFL`(`R SFL1` の45桁目) | この様式がサブファイルの1行分であることを示す。 |
| `SFLCTL(SFL1)` | この様式が `SFL1` の制御様式であることを示す。 |
| `SFLSIZ(9999)` | サブファイルが保持できる行数(最大)。 |
| `SFLPAG(14)` | 1画面に出す行数。4〜17行目の14行になる。 |
| `SFLDSP` | 明細の行を表示してよい。 |
| `SFLDSPCTL` | 制御様式の定数やフィールドを表示してよい。 |
| `OVERLAY` | 画面を消さずに重ねて書く(下の `SFL1FTR` とセットで使う)。 |
| `CF03(03)` | F3 で標識03を ON にする。 |

**`SFL1CTL` の定数(見出し)は、サブファイルの行より上にだけ置いています。** 制御様式の中で、行の上と下の両方に定数を置くとコンパイルが `CPD7812`(「サブファイル制御レコードがサブファイル・レコードに重なる」)で失敗することが、第5部の実機確認(`part05-legacy-probe`)で分かっています。下側の `MORE`・`F3=Exit` は、独立した `SFL1FTR` 様式に分けてあります。

### DDS の条件標識を使わない理由と、読むだけの `SFLCLR`・`SFLEND`

**この教材の出荷サンプルは、DDS の条件標識(7〜16桁目)を一切使いません。** 標識に応じて出し分ける書き方を、この教材の作者が実機で試して失敗し、桁位置を特定できなかったためです([`docs/probes.md`](../probes.md))。そのため `D0426B` では `SFLDSP`・`SFLDSPCTL` を無条件にしてあり、`SFLCLR`(サブファイルを空にする)も `SFLEND`(「続きがあるか、最後か」を画面右下に出す)も書いていません。

では `SFLCLR`・`SFLEND` はどう書くのか。一次資料(ILE RPG プログラマーズ・ガイド、サブファイル制御レコードの例)の形を、簡略にして読みます。**このレッスンでは書きません。実機でも未検証です。**

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     A          R FILCTL                    SFLCTL(SUBFIL)
     A N70                                  SFLCLR
     A  70                                  SFLDSPCTL
     A  71                                  SFLDSP
     A                                      SFLSIZ(15)
     A                                      SFLPAG(15)
```

条件標識は、8桁目に `N`(否定)、9〜10桁目に標識番号を書きます。上の例は「標識70が OFF のとき `SFLCLR`」「標識70が ON のとき制御様式を表示」「標識71が ON のとき明細を表示」という意味です。RPG 側の流れは、次のとおりです。

| 順 | RPG 側の処理 | 画面側に起きること |
|---|---|---|
| 1 | 標識70を OFF にして、制御様式を `WRITE` する | `SFLCLR` が働き、サブファイルが空になる |
| 2 | 行を `WRITE` する(RRN を1ずつ増やす) | 行が貯まる |
| 3 | 標識70・71を ON にして、`EXFMT` する | 制御様式と明細が表示される |

`SFLEND` は、制御様式に `SFLEND(*MORE)` と書くものです。標識で、「最後の行まで読み込んだか」を切り替えます。`D0426B` は代わりに、フッターの `MORE` という出力フィールドへ、RPG が `'BOTTOM'` か `'MORE...'` を `MOVEL` する方法を採っています。条件標識を使う形が実機で通るかどうかは、検証用の `D0426P`(出荷しない)で確かめます。**結果は、実機メモを参照してください**(未検証)。

### RRN と `SFILE`(RPG 側)

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     FD0426B    CF   E             WORKSTN SFILE(SFL1:RRN)
     DRRN              S              4P 0
```

`SFILE(SFL1:RRN)` は、「DDS の `SFL1` をサブファイルとして扱い、その行番号を `RRN` という変数で受け渡す」という宣言です。一次資料(ILE RPG リファレンス、`SFILE` キーワード)には、次のことが書かれています。

- DDS のサブファイルごとに、`SFILE` キーワードが必要。
- `RRN`(相対レコード番号のフィールド)は、**小数部が0の数値**で、最大の行番号が入る桁数が必要。
- `WRITE` のとき、RPG IV はこの `RRN` の値を、書き込む行の番号に使う。

`RRN` は、`D` 仕様書で自分で宣言します。`D` 仕様書の桁位置は、06-01b の `V0601B` と同じです(名前は7桁目から、`S` は24桁目、長さは39桁目で右づめ、型は40桁目、小数桁は42桁目)。`WRITE SFL1` の前に `RRN` を1増やし、行を1行ずつ貯めます。

### `V0426B` の流れ

| 段階 | 処理 |
|---|---|
| 準備 | `MORE` を空にし、`RRN` を0にする |
| 読み込み | `TOKUIM` を1件ずつ `READ` し、`RRN` を1増やして `WRITE SFL1`(最大9999行) |
| 空の場合 | `TOKUIM` が0件なら、空の行を1行 `WRITE` する(`SFLDSP` が無条件なので、サブファイルを空のままにしない) |
| 終端表示 | 全件を読み切ったら `MORE` に `'BOTTOM'`、途中で止めたら `'MORE...'` |
| 表示 | `SFL1FTR` を `WRITE`(フッター)してから `SFL1CTL` を `EXFMT`。F3(標識03)が ON になるまで繰り返す |

`TOKCD`・`TOKNM` は `TOKUIM` にも `SFL1` にも同じ名前であるので、`READ TOKUIM` の結果がそのまま `WRITE SFL1` で画面の行になります(04-11 の `CHAIN` の結果がそのまま画面に出た仕組みと同じです)。

**このサンプルには、RPG III の対応物がありません。** 旧システムの `TK0100`(05-05)は、サブファイル付きの `TK0100D` の画面を持っていますが、プログラム側は一覧を一度も動かしていません。共有しているのは DDS の考え方(`TK0100D` の `SFL1`・`SFL1CTL`・`SFL1FTR`)だけです。

## 実演

1. ソース物理ファイルを用意する。`QRPGLESRC` は 04-21 で作成済みです。無ければ次で作る。

   ```text
   CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112)
   ```

2. `WRKMBRPDM FILE(<自分のユーザー名>1/QDDSSRC)` で `D0426A`(ソース・タイプ `DSPF`)を作り、次を入力する(`src/qddssrc/d0426s.dspf` と同じ内容)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
        A                                      DSPSIZ(24 80 *DS3)
        A          R INQFMT
        A                                      CF03(03)
        A                                  1  2'Customer code:'
        A            TOKCD          6A  I  1 17
        A                                  3  2'Name:'
        A            TOKNM         30A  O  3  8
        A                                  5  2'F3=Exit'
   ```

3. `WRKMBRPDM FILE(<自分のユーザー名>1/QRPGLESRC)` で `V0426A`(ソース・タイプ `RPGLE`)を作り、次を入力する(`src/qrpglesrc/v0426s.rpgle` と同じ内容)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0426A - TOKUIM inquiry screen (WORKSTN, EXFMT, F3=exit).
         * Ports R0411A (RPG III, lesson 04-11) to fixed-form RPG IV.
         * Same screen (D0426A = R0411A DDS), same visible behavior.
         * Compile with CRTBNDRPG (default DFTACTGRP(*YES)).
        H
        FD0426A    CF   E             WORKSTN
        FTOKUIM    IF   E           K DISK
        C     *IN03         DOWEQ     *OFF
        C                   EXFMT     INQFMT
         * RPG III allowed N03 and 50 on one line; RPG IV has one
         * indicator slot (cols 9-11), so test 03 with an IF block.
        C     *IN03         IFEQ      *OFF
        C     TOKCD         CHAIN     TOKUIM                             50
        C   50              MOVEL     'NOTFOUND'    TOKNM
        C                   ENDIF
        C                   ENDDO
        C                   SETON                                        LR
   ```

4. 画面、プログラムの順にコンパイルする。**画面を先に**作ります(RPG のコンパイルが、画面の定義を読むためです)。

   ```text
   CRTDSPF FILE(<自分のユーザー名>1/D0426A) SRCFILE(<自分のユーザー名>1/QDDSSRC) SRCMBR(D0426A)
   CRTBNDRPG PGM(<自分のユーザー名>1/V0426A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(V0426A)
   ```

   どちらも最大重大度が00で終わるはずです(未検証)。

5. `CALL PGM(V0426A)` を実行する。`R0411A` と同じ画面が出る。`TOKUIM` に実在する得意先コード(例: `C00001`)を入力して `Enter` を押すと、名前が出る。存在しないコードで `NOTFOUND` が出る。`F3` で終了する。

   ```text
   Customer code: C00001

   Name:  ACME TRADING CO

   F3=Exit
   ```

   **この画面の動きは未検証です(V3)**。上の名前は例で、手元の `TOKUIM` の中身によって変わります。自分の5250で確認してください。

6. 同じ要領で `D0426B`(`DSPF`)と `V0426B`(`RPGLE`)を作る。DDS は上の「説明」の節に載せた全文(`src/qddssrc/d0426bs.dspf`)、RPG は次のとおりです(`src/qrpglesrc/v0426bs.rpgle` と同じ内容)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0426B - customer list (TOKUIM) in a load-all subfile.
         * Screen: D0426B (lesson 04-26). NEW sample: there is no RPG
         * III counterpart (TK0100 never drove its subfile); only the
         * DDS idea is shared with TK0100D (legacy DDS).
        H
        FD0426B    CF   E             WORKSTN SFILE(SFL1:RRN)
        FTOKUIM    IF   E           K DISK
         * RRN: relative record number of the subfile (numeric, 0 dec).
        DRRN              S              4P 0
         * Load phase: one WRITE SFL1 per TOKUIM record, RRN 1,2,3...
        C                   MOVE      *BLANKS       MORE
        C                   Z-ADD     0             RRN
        C                   READ      TOKUIM                                 98
        C     *IN98         DOWEQ     *OFF
        C     RRN           ANDLT     9999
        C                   ADD       1             RRN
        C                   WRITE     SFL1
        C                   READ      TOKUIM                                 98
        C                   ENDDO
         * SFLDSP is not conditioned in D0426B: write one blank row
         * when TOKUIM is empty, so the subfile is never empty.
        C     RRN           IFEQ      0
        C                   MOVE      *BLANKS       TOKCD
        C                   MOVE      *BLANKS       TOKNM
        C                   Z-ADD     1             RRN
        C                   WRITE     SFL1
        C                   ENDIF
        C     *IN98         IFEQ      *ON
        C                   MOVEL     'BOTTOM'      MORE
        C                   ELSE
        C                   MOVEL     'MORE...'     MORE
        C                   ENDIF
         * Display phase: footer first (OVERLAY), then the control
         * record, until F3 turns on indicator 03.
        C     *IN03         DOWEQ     *OFF
        C                   WRITE     SFL1FTR
        C                   EXFMT     SFL1CTL
        C                   ENDDO
        C                   SETON                                        LR
   ```

7. `CRTDSPF`(`D0426B`)、`CRTBNDRPG`(`V0426B`)の順にコンパイルし、`CALL PGM(V0426B)` を実行する。`TOKUIM` の全件が `Code`・`Name` の2列で並ぶ。14件を超えるときは `Page Down` で次の画面へ進む。`F3` で終了する。

   ```text
   D0426B - Customer list (TOKUIM)

   Code  Name
   C00001  ACME TRADING CO
   C00002  ...
   ...
   BOTTOM
   F3=Exit  Roll=Page
   ```

   上の画面例の名前・行数は、手元の `TOKUIM` の中身によって変わります。**画面の動きは未検証です(V3)**。

## 演習

1. **例題を読む**。`V0426A` を動かし、実在するコードの次に、存在しないコードを入力してください。`Name:` に何が出るか、予想してから確認してください。`R0411A`(RPG III 版)を残している人は、同じ操作で比べてみてください。
2. **修正する**。1. の結果が「`NOTFOUND` のあとに、前の名前の続きが混じる」ことになっていたら、`V0426C` として直してください。
   - ヒント: `MOVEL` の命令コード欄に、`P` を括弧で付けます(`MOVEL(P)`)。余った桁が空白で埋められます。
   - 模範解答: `solutions/04-26/v0426c.rpgle`(画面は `D0426A` のままです)。
3. **独力で**。`D0426B` の一覧に、担当者コード `TOKTAN`(6桁)の列を足した `D0426D`(DDS)と、それを使う `V0426D` を作ってください。
   - ヒント: `TOKTAN` は `TOKUIM` にある名前です。DDS に出力フィールドと見出しを足すだけで、RPG の処理は増えません。`V0426D` の F 仕様書のファイル名は `D0426D` にします。
   - 模範解答: `solutions/04-26/d0426d.dspf`・`solutions/04-26/v0426d.rpgle`。
4. **応用**。一覧の下に「`Count:` 読み込んだ件数」を出す `D0426E`・`V0426E` を作ってください。
   - ヒント: フッター様式 `SFL1FTR` に、`4S 0` の出力フィールド `CNT`(`Count:` という定数と組)を足します。読み込みが終わったあとで、`RRN` を `CNT` へ `Z-ADD` します。
   - 模範解答: `solutions/04-26/d0426e.dspf`・`solutions/04-26/v0426e.rpgle`。

## セルフチェック

- [ ] 画面(DDS)・RPG 両方をコンパイルし、`V0426A` が「実演」の手順5の画面どおりに動くのを確かめた。
- [ ] 固定形式 RPG IV の F 仕様書(17・18・22・36・44桁目)と C 仕様書(12・26・36・50桁目、`CHAIN` は71桁目、`READ` は75桁目)の桁位置を言える。
- [ ] 条件標識が1個だけであることと、2個必要なときの書き換え方(`IF` ブロック)を説明できる。
- [ ] `SFL`・`SFLCTL`・`SFLSIZ`・`SFLPAG`・`SFLDSP`・`SFLDSPCTL` の役割を説明できる。
- [ ] `SFILE(SFL1:RRN)` と `RRN` の D 仕様書の関係を説明できる。
- [ ] `SFLCLR`・`SFLEND` が、このレッスンでは「読むだけ」であることを言える。

## 片付け

`D0426A`・`V0426A` は、第6部の 06-04・06-10・06-11 で「書き換え前」として使うので、**残してください**。演習で作ったものと `D0426B`・`V0426B` は、個別に `DLTPGM`・`DLTF` で消します。たとえば次のとおりです。

```text
DLTPGM PGM(<USER>1/V0426B)
DLTF FILE(<USER>1/D0426B)
```

総称名(`V0426*`・`D0426*`)で消すと `V0426A`・`D0426A` も消えます。第6部へ進む前に消した場合は、「実演」の手順2〜4で作り直してください。`TOKUIM` は入力だけなので、データは書き換わりません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Display file | 表示装置ファイル |
| Subfile | サブファイル |
| Subfile control record | サブファイル制御レコード |
| Relative record number (RRN) | 相対レコード番号 |
| Response indicator | 応答標識 |
| Function key | ファンクション・キー |
| Full procedural file | 完全手続き型ファイル |
| Combined file | 組み合わせファイル |

次のレッスンは [04-27](04-27-route-preparation.md) です。

## 実機メモ

- **確認日: 未検証(2026-10-01時点)。** このレッスンのソース(`D0426A`・`D0426B`・`V0426A`・`V0426B`・演習の解答)は、まだ実機でコンパイルしていません。検証用のバッチは `verify/part04v-26scr/`(コンパイルだけで、`CALL` はしません)。実行後に、結果をここへ書き直します。
- **すでに根拠のあること**:
  - `D0426A` の DDS は、`src/qddssrc/r0411s.dspf` と同一の内容です(`R0411A` の DDS は 2026-09-25 に `CRTDSPF` の最大重大度00を確認済み、[04-11](../part04/04-11-display-file-inquiry.md))。
  - `D0426B` の DDS の行は、`src/qddssrc/d0611s.dspf`(2026-09-26 に `CRTDSPF` の最大重大度00を確認済み、06-11)と同じ桁位置です。違いは、`ROLLUP`・`ROLLDOWN`・オプション欄・メッセージ・サブファイルを省いた点です。
  - F 仕様書・C 仕様書の桁位置(結果標識の71・75桁目を含む)は、`src/qrpglesrc/v0601s.rpgle`(`CVTRPGSRC` の実出力、実機で最大重大度00)の行の形と、ILE RPG リファレンスの記述に依拠しています。
  - `EXFMT` が完全手続き型の組み合わせファイルを要求することと、`SFILE` の `RRN` が小数部0の数値であることは、ILE RPG リファレンス(一次資料)の記述です。
- **未検証(2026-10-01時点)**:
  - `V0426A`・`V0426B` が `CRTBNDRPG` を通ること、`D0426B` が `CRTDSPF` を通ること。`V0426B` は `SFILE(SFL1:RRN)` を使う、この教材で初めての固定形式のソースです。
  - 画面の動き(`EXFMT`・F3・`Page Down`)は、このハーネスでは確かめられません(V3)。`R0411A` と `V0426A` の見た目・動きが同じであること、`'NOTFOUND'` の後ろに直前の名前の続きが残ること、`TOKUIM` が0件のときの空の行の表示は、すべて理屈からの予想です。
  - 上の表の `V0426X1`〜`V0426X4` のメッセージ ID(実機で確認後に記入)。
  - DDS の条件標識(`D0426P`: `SFLCLR`・`SFLDSP`・`SFLEND` を標識70〜72で切り替える形、`D0426Q`: 標識50で定数を出し分ける形)が `CRTDSPF` を通るか。第5部の実機確認(`part05-gen-probe`)では条件標識を含む検証用 DDS が `CPD5238` で失敗していますが、その DDS には条件標識以外の誤り(引用符のない定数、無効な `SFLRCDNBR(*ALL)`)も含まれていたため、原因が桁位置だったかどうかは分かっていません。
  - `READC`・`SFLNXTCHG`・メッセージ・サブファイルを固定形式 RPG IV から使う方法(このレッスンでは書いていません)。`AN`/`OR` 行による複数の条件標識。
  - `MOVEL(P)` で余りの桁が空白になること(`ilerpgref75.txt` に `MOVEL(P)` の例があります)。
- 参照した一次資料: ILE RPG リファレンス(`EXFMT`・`SFILE`・`READC`・F 仕様書の17・18桁目・C 仕様書の7〜11桁目)、ILE RPG プログラマーズ・ガイド(サブファイル制御レコードの例)。DDS のキーワード辞典(表示装置ファイル用の DDS)は、手元の一次資料に無かったので参照していません。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
