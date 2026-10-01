# 04-24 CALL・PARM のずれと実行時エラー(固定形式 RPG IV)

> 所要時間: 90分(長め)/ 前提レッスン: [04-23](04-23-external-files.md)・[03-08](../part03/03-08-parameters-and-call.md) / 目標番号: 3・9 / 観測方法: `WRKSPLF`・`DSPJOBLOG`・`HEX()`・`STRDBG` / 道具: 5250(SEU または Code for i)・SQL / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/V0424A`〜`V0424L`・`C0424A`・`W0424A`・`W0424B` / DBVER: 1 / 依存するプローブ: なし(このレッスンの実機バッチ `part04v-24run` が記録する。実機メモ参照)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- 呼ばれる側の `*ENTRY PLIST`/`PARM` と、呼ぶ側の `CALL`/`PARM` を、固定形式 RPG IV で書ける(`04-24-1`)。
- 呼ぶ側と呼ばれる側で `PARM` の長さ・小数点位置が食い違うと何が起きるかを自分で起こし、ジョブ・ログのメッセージから原因をたどれる。CL から RPG を呼ぶ場合(旧システムの `JU0900C`→`ZA0500` と同じ形)にも使える(`04-24-2`)。
- 実行時エラーを `*PSSR` で受け止める書き方と、`HEX()`・`STRDBG` で中身を確かめる手順を説明できる(`04-24-3`)。

## ウォームアップ

<details><summary>前回までの復習</summary>

1. 03-08 で学んだとおり、CL の `CALL`/`PARM` は値を渡すのか、場所を渡すのか?
2. 固定形式 RPG IV で、`CHAIN` の「レコードが無い」を受ける標識は何桁目に書く?
3. 5桁・小数0桁のパック10進数を、単独のフィールドとして D 仕様書で宣言する行は?

答え: 1. 場所(参照渡し)。呼ばれた側が書き換えると、呼んだ側の変数も変わる。 2. 71〜72桁目(NR)。 3. `DQTY              S              5P 0`(名前は7桁目、`S` は24桁目、長さ `5` は39桁目で右づめ、型 `P` は40桁目、小数 `0` は42桁目)。

</details>

## なぜ学ぶか

現場では、プログラム同士の「つなぎ目」の不具合が一番やっかいです。コンパイルは両方とも通るのに、実行すると止まる、あるいは何も言わずに別の変数が壊れる、という形で現れるからです。

この教材の旧システム(第5部で読む `JU0900C`・`ZA0500`)にも、その種の食い違いがあります。CL の `JU0900C` は数量を桁数 `3,0` で宣言して渡し、RPG の `ZA0500` は `*ENTRY PLIST` で `5,0` として受け取っています。**このルートでの実際の修正は [04-27](04-27-route-preparation.md) と第8部の 08-05b で扱います。** このレッスンでは、その種の食い違いを「どう再現し、どう診断し、どう防ぐか」を、小さなプログラムで一般的に練習します。

**RPG III を学んでいないことを前提にしています。** 呼び出しの仕組みは、CL(03-08)と、このルートの 04-21〜04-23 だけで説明します。なお、このレッスンの `V0424A`〜`V0424G` は、RPG III ルートの [04-08b](../part04/04-08b-call-parm-plist.md) の `R0408BA`〜`R0408BE` と同じ実験を、固定形式 RPG IV に移したものです(対応は次の表のとおり)。**画面や印刷に出る結果は、同じになるように作ってあります**(後の部で「`R0408BB` と同じ出力」と書くときは、`V0424B` でも同じです)。ただし、**RPG III(OPM)で起きたことを、ILE の RPG IV でも起きると決めつけてはいけません。** どのメッセージが出るかはこのレッスンの実機バッチが記録するもので、この文書では「(実機で確認後に記入)」としています。

| このレッスン | 役割 | RPG III ルートの対応 |
|---|---|---|
| `V0424A` | 呼ばれる側: 得意先コードから得意先名を返す | `R0408BA` |
| `V0424B` | 呼ぶ側: `V0424A` を呼んで名前を印字 | `R0408BB` |
| `V0424C` | 呼ばれる側: 発注が要るかの判定(`QTY` は 5,0) | `R0408BC` |
| `V0424D` | 呼ぶ側: `QTY` を 3,0 で渡す(食い違い) | `R0408BD` |
| `V0424E` | 呼ぶ側: 文字の長さの食い違い | `R0408BE` |
| `V0424F` | `V0424C` に `*PSSR` を足したもの | (RPG III ルートに対応なし) |
| `V0424G` | 呼ぶ側: `V0424F` を 3,0 で呼ぶ | (同上) |
| `V0424X` | 演習2の答え(`V0424D` の修正版) | 04-08b の修正版(`R0408BD` の `QTY` を `5,0` に直したもの) |
| `V0424H`・`V0424I` | 演習4の答え(`ENDSR '*CANCL'`) | (対応なし) |
| `V0424J`・`V0424K` | 演習3の答え(数量×単価) | `R0408BF`・`R0408BG` |
| `V0424L` | 壊れたゾーン10進数を読む | (対応なし) |
| `C0424A` | CL から食い違いで呼ぶ | (対応なし) |

## 新出

- 中核概念(3つ)
  1. **`*ENTRY PLIST` と `PARM`**: 呼ばれる側が値を受け取る入口。RPG IV では、受け取る変数を D 仕様書で宣言しておき、`PARM` には名前だけを書く。
  2. **長さの食い違いは、`CALL`/`PARM` の書き方では検査されない(と考えられる。実機で記録する)**: 渡されるのは変数の先頭の場所だけ。食い違いの結果は、メッセージ(数値)かデータの破壊(文字)として現れる。
  3. **`*PSSR`**: プログラム全体の例外/エラー・サブルーチン。実行時エラーを自分で受け止める。
- 命令・構文(6つまで): `PLIST`・`PARM`・`CALL`(エラー標識は73〜74桁)・`RETURN`・`BEGSR *PSSR`・`ENDSR`(戻り先)
- 読解用(上の数に含めない): ILE のメッセージ接頭辞 `RNQ`/`RNX`/`RNF`/`MCH`、`HEX()`(SQL)、`STRDBG`(デバッガー)

## 説明

### RPG III と固定形式 RPG IV の桁の違い(このレッスンで使う行だけ)

04-21 で見たとおり、固定形式 RPG IV の桁位置は RPG III と違います。呼び出しまわりでは、次の点に注意してください。**CALL のエラー標識を RPG III の桁(56〜57桁)の習慣で書くと、RPG IV では置き場所が合いません。**

| 項目 | RPG III(参考。この教材のこのルートでは使いません) | 固定形式 RPG IV(このレッスン) |
|---|---|---|
| `*ENTRY` | Factor 1 の18桁目 | Factor 1 の12桁目 |
| `PARM` の変数 | 結果フィールド(43桁目)に、長さと小数点位置も書く | 結果フィールド(50桁目)。長さ・小数点位置は **D 仕様書で宣言**しておく |
| `CALL` のエラー標識 | 56〜57桁目 | **73〜74桁目**(ER)。71〜72桁目は空白でなければならない |
| `COMP` の「より小さい」(LO) | 56〜57桁目 | 73〜74桁目 |
| 呼び出し元へ戻る命令 | `RETRN` | `RETURN` |

(RPG IV 側の桁は、IBM の ILE RPG リファレンスの `CALL` の項「Positions 71 and 72 must be blank」と、`CALL` の標識表(`ER` と `LR`)、および 04-21〜04-23 のサンプルに沿っています。RPG III 側は 04-08b の記述です。)

`CALL` の 75〜76桁目には、`LR` を ON にして戻ってきたときに ON になる標識を書けます。このレッスンでは使いません。

ソースの先頭付近は `H DFTACTGRP(*YES)` の行です(04-21 のサンプルと同じ)。このレッスンのプログラムはすべて既定の活動化グループ(OPM と同じ環境)で動きます。活動化グループは第7部で扱います。

### 呼ばれる側: `*ENTRY PLIST`

`V0424A` は、得意先コード(6桁の文字)を受け取り、得意先名(30桁)と結果コード(1桁の数値。0=見つかった、1=無い)を返します。ソースは、`src/qrpglesrc/v0424s.rpgle` と同じ内容です。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424A - called side: look up a customer name by code.
      * Port of R0408BA (04-08b) to fixed-form RPG IV. Same behaviour.
      * PARM 1 PCODE 6 in, PARM 2 PNAME 30 out, PARM 3 PRC 1,0 out
      * (0 = found, 1 = not found).
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E           K DISK
     DPCODE            S              6A
     DPNAME            S             30A
     DPRC              S              1P 0
     C     *ENTRY        PLIST
     C                   PARM                    PCODE
     C                   PARM                    PNAME
     C                   PARM                    PRC
     C                   MOVE      *BLANKS       PNAME
     C     PCODE         CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    PNAME
     C   99              Z-ADD     1             PRC
     C  N99              MOVEL     TOKNM         PNAME
     C  N99              Z-ADD     0             PRC
     C                   SETON                                        LR
     C                   RETURN
```

- `D` 仕様書で `PCODE`・`PNAME`・`PRC` を宣言しています(`PRC` は `1P 0`、つまり1桁のパック10進数)。
- `C     *ENTRY        PLIST` の次に、`PARM` を呼ぶ側と同じ順に並べます。`PARM` の結果フィールド(50桁目)に変数の名前だけを書きます。
- `RETURN` は呼び出し元へ**すぐに**戻ります。プログラムを終わらせたいときは、その前に `SETON LR` を実行します(`LR` は71〜72桁目)。
- `CHAIN` の「レコードなし」標識 `99` は71〜72桁目です。`TOKUIM` は04-23 で学んだ外部記述ファイルで、`TOKNM` はそのフィールドです。

### 呼ぶ側: `CALL` と `PARM`

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424B - calling side: pass a customer code, print the name.
      * Port of R0408BB. Calls V0424A. RC is set to 9 first so that a
      * change is visible. CALL error indicator 85 is in cols 73-74.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DCODE             S              6A
     DNAME             S             30A
     DRC               S              1P 0
     C                   MOVEL     'C00001'      CODE
     C                   MOVE      *BLANKS       NAME
     C                   Z-ADD     9             RC
     C                   CALL      'V0424A'                             85
     C                   PARM                    CODE
     C                   PARM                    NAME
     C                   PARM                    RC
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       CODE                 6
     O                                            8 '  '
     O                       NAME                38
     O                                           40 '  '
     O                       RC                  41
     O               85                          55 'CALL FAILED'
```

- `CALL` の Factor 2 に、プログラム名を**引用符付きのリテラル**で書きます。ライブラリー・リスト(`*LIBL`)から探すので、呼ばれる側のあるライブラリーが `*LIBL` に入っている必要があります。
- `CALL` に続く `PARM` は、呼ぶ側の**変数の場所**を渡します。**呼ばれた側が書き換えると、呼んだ側の変数が変わります**(03-08 の CL と同じ参照渡し)。
- `CALL` の73〜74桁目の `85` は、呼び出しが失敗したとき(呼ばれるプログラムが見つからない、または呼ばれたプログラムが異常終了した)に ON になるエラー標識です。この標識で失敗を受けると、呼ぶ側は続行できます。
- `RC` は、書き換わったことが分かるように、最初に `9` を入れています。

**期待する印字(未検証)** は、`R0408BB` と同じ `C00001  ACME TRADING CO                 0` です。

### 長さの食い違い

IBM の ILE RPG リファレンス(`PARM` 命令の項)は、次のことを述べています。

- パラメーターは**アドレスで**渡されるので、呼ぶ側と呼ばれる側が同じ変数名を使う必要はない。
- ただし、対応するパラメーターの属性(長さ・型)は**同じにしておくべき**で、違うと「望ましくない結果」(undesirable results)になりうる。
- 型の検査が大事なら、`PLIST`/`PARM` ではなく、プロトタイプとプロシージャー・インターフェースを使うべき(第6部の [06-05](../part06/06-05-subprocedures-prototypes.md))。

つまり、`CALL`/`PARM` の古い書き方では、**コンパイラーが長さの食い違いを見つけてくれるとは限りません。** `V0424C`(呼ばれる側。`QTY` は `5P 0` で3バイト)と `V0424D`(呼ぶ側。`QTY` は `3P 0` で2バイト)で実際に確かめます。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424C - called side: reorder check. QTY is 5,0 (packed).
      * PARM 1 QTY 5,0 in, PARM 2 FLG 1 out (R = reorder, O = ok).
      * Port of R0408BC (04-08b). LO indicator 90 is in cols 73-74.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C     *ENTRY        PLIST
     C                   PARM                    QTY
     C                   PARM                    FLG
     C     QTY           COMP      10                                   90
     C   90              MOVEL     'R'           FLG
     C  N90              MOVEL     'O'           FLG
     C                   SETON                                        LR
     C                   RETURN
```

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424D - calling side: QTY is 3,0 but V0424C expects 5,0.
      * Calls V0424C. Output layout is the same as R0408BD.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DQTY              S              3P 0
     DFLG              S              1A
     C                   Z-ADD     5             QTY
     C                   MOVEL     '-'           FLG
     C                   CALL      'V0424C'                             85
     C                   PARM                    QTY
     C                   PARM                    FLG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       QTY                  5
     O                                            7 '  '
     O                       FLG                  8
     O               85                          25 'CALL FAILED'
```

パック10進数(`P`)は、1バイトに2桁を入れ、最後の半バイトが符号です(正は `F` か `C`)。3桁なら2バイト(値5は `005F`)、5桁なら3バイトです。`V0424C` は、`V0424D` が渡した2バイトの**先に続く1バイト**まで、自分の `QTY` として読みます。その1バイトが何なのかは、**この文書では確かめていません**(呼ぶ側のプログラムの記憶域の、2バイトの後ろにあるものです。ILE では変数の並びが保証されません)。

### ILE のメッセージ(RPG III との違い)

ILE の RPG が出すメッセージの接頭辞は、RPG III(OPM)の `RPG`・`QRG` とは別物です。

| 接頭辞 | 種類 | 例 |
|---|---|---|
| `RNF` | コンパイル時のメッセージ | `RNF7030` など(04-21 以降で出会います) |
| `RNQ` | 実行時の**照会**メッセージ(応答を求める) | `RNQ0202`(呼び出し失敗) |
| `RNX` | 実行時の**エスケープ**メッセージ | `RNX9001`(`*PSSR` の `'*CANCL'`)・`RNX0100` |
| `MCH` | マシン(MI)レベルの例外 | `MCH1202`(10進数データ・エラーの MI レベル名) |

出所と確度は次のとおりです。

- ILE RPG プログラマーズ・ガイドによると、実行時の照会メッセージは「サイクル・メイン・プロシージャーでの機能検査(function check)で、既定のエラー処理が呼ばれたとき」に出ます。サブプロシージャーでは照会メッセージは出ません。サイクル・メインが呼び出し失敗(状況コード 00202)を受けて既定のハンドラーに入ると `RNQ0202` が出ます。
- ILE の照会メッセージ(`RNQ0100`〜`RNQ9999`)は、`DSPMSGD RANGE(RNQ0100 RNQ9999) MSGF(QRNXMSG) DETAIL(*BASIC) OUTPUT(*PRINT)` で一覧できます(同ガイド)。
- プログラム状況コード `00907` は「10進数データ・エラー(桁または符号が不正)」です(ILE RPG リファレンス)。RPG III(OPM)ではこれが `RPG0907` として現れました(04-08b・05-11・[付録B](../appendix/b-message-ids.md))。ILE のサイクル・メインで同じ状況がどのメッセージ ID になるかは、**(実機で確認後に記入)** です。`RNQ0907` が出ると予想されますが、この教材の別の ILE プログラム(08-05b の `Q0805B`。サブプロシージャーの中)では、同じ種類の状況が `MCH1202` として現れました。**どちらが出るかは、このレッスンの実機バッチで確認します。**
- 非対話ジョブで照会メッセージが出ると、`CHGJOB INQMSGRPY(*DFT)` により、そのメッセージの既定の応答が自動で返ります。システム応答リスト(`ADDRPYLE`)に登録する方法もありますが、**システム全体の設定なので PUB400 では触りません**。ILE の照会メッセージの既定の応答が何かは、**(実機で確認後に記入)** です。

### `*PSSR`: 実行時エラーを自分で受け止める

`BEGSR` の Factor 1 に `*PSSR` と書いたサブルーチンは、そのプログラムで、エラー標識や `(E)` 拡張子で受けていない実行時エラーが起きたときに、制御を受け取ります。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424F - called side: reorder check. QTY is 5,0 (packed).
      * PARM 1 QTY 5,0 in, PARM 2 FLG 1 out (R = reorder, O = ok).
      * Port of R0408BC plus a *PSSR that ends with RETURN. The *PSSR
      * touches only FLG (character), so it cannot fail and loop.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C     *ENTRY        PLIST
     C                   PARM                    QTY
     C                   PARM                    FLG
     C     QTY           COMP      10                                   90
     C   90              MOVEL     'R'           FLG
     C  N90              MOVEL     'O'           FLG
     C                   SETON                                        LR
     C                   RETURN
     C     *PSSR         BEGSR
     C                   MOVEL     'E'           FLG
     C                   SETON                                        LR
     C                   RETURN
     C                   ENDSR
```

IBM のリファレンスによる決まりは、次のとおりです。

- `ENDSR` の Factor 2 に戻り先を書けます。**空白のまま `ENDSR` に来ると、既定のエラー処理が制御を受け取ります**(つまり、照会メッセージが出ます)。`V0424F` は、`*PSSR` の中で `RETURN` を実行して、呼び出し元へ正常に戻っています。
- `ENDSR '*CANCL'` で終えると、プログラムは異常終了し、エスケープ・メッセージ `RNX9001` が呼び出し元へ送られます(ILE RPG プログラマーズ・ガイド)。`V0424H` で試します(演習4)。
- **`*PSSR` の中でエラーが起きると、`*PSSR` がもう一度呼ばれ、書き方によっては無限ループになります。** `V0424F` の `*PSSR` は文字のフィールド `FLG` にしか触れないので、ここでは再びエラーになりません。
- `*PSSR` の中での `RETURN`: サイクル・メインでの動作は、このレッスンの実機バッチで確認します(`*PSSR` の `RETURN` を述べたリファレンスの箇所は、サブプロシージャーの話として書かれています)。

### 中身を見る: `HEX()` とデバッガー

- **ファイルの中のデータ**は、SQL の `HEX()` で見ます([05-11](../part05/05-11-decimal-data-error.md) と同じ道具)。ゾーン10進数(`5S 0` など)は1バイト1桁で、各バイトの下位4ビットが数字です。数字の位置に `0`〜`9` 以外があると、10進数データ・エラーになります。たとえばピリオド5個 `'.....'` は EBCDIC では `4B4B4B4B4B` で、数字の位置が `B` なので不正です(05-11 の実機確認)。
- **プログラムの変数(`PARM` で渡ってきた値など)**は、デバッガーで見ます。`EVAL QTY:x` のように `:x` を付けると 16 進で表示されます(ILE RPG プログラマーズ・ガイドの `EVAL` の説明による。**実機の画面では未確認(V3)**)。

## 実演

### 準備

- `WRKLIBL` で `<USER>1` がライブラリー・リストに入っていることを確認します(`V0424A` が `TOKUIM` を開き、`V0424B` が `V0424A` を探すので、どちらも `*LIBL` から見つかる必要があります)。入っていなければ `ADDLIBLE LIB(<USER>1)` で追加します。
- `QRPGLESRC`(レコード長112)は、04-21 で作ったものを使います。
- `TOKUIM` に `C00001`(`ACME TRADING CO`)が入っていること(DBVER 1 のサンプル・データ)。
- 以下の `CRTBNDRPG` は、デバッガーでソースを見るため `DBGVIEW(*SOURCE)` を付けます。

### 1. 呼ばれる側 `V0424A` と、呼ぶ側 `V0424B`

1. `V0424A`(メンバー・タイプ `RPGLE`)を作り、上のとおり入力します。桁は、必ず上の目盛りと見比べてください。
2. コンパイルします。

   ```text
   CRTBNDRPG PGM(<USER>1/V0424A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(V0424A) DBGVIEW(*SOURCE)
   ```

   最高重大度: (実機で確認後に記入)。
3. `V0424B` を同じ要領で作り、`CALL PGM(V0424B)` を実行して、`WRKSPLF` で印字を見ます。期待は上のとおりです。実際の印字: (実機で確認後に記入)。

### 2. 呼ばれる側が無いとき

`DLTPGM PGM(<USER>1/V0424A)` で `V0424A` をいったん消し、`V0424B` をもう一度実行します。ジョブ・ログのメッセージ ID と、`85` が ON になって `CALL FAILED` が印字されるかどうか: (実機で確認後に記入)。確認したら `V0424A` をコンパイルし直します。

### 3. 数値の食い違い: `V0424C` と `V0424D`

1. `V0424C` と `V0424D` を作り、コンパイルします。**どちらもコンパイルが通るか(最高重大度)**: (実機で確認後に記入)。
2. `CALL PGM(V0424D)` を実行します。次の表を埋めてください(OPM の RPG III の欄は、04-08b の実機の記録です。ILE の欄はこのレッスンの実機バッチが埋めます)。

   | | RPG III(OPM、04-08b の記録) | 固定形式 RPG IV(ILE、このレッスン) |
   |---|---|---|
   | 実行時のメッセージ | `RPG0907`(文700)→ `RPG9001` | (実機で確認後に記入) |
   | メッセージの種類(照会かどうか) | 照会(`(C G S D F)` の応答を求める) | (実機で確認後に記入) |
   | 呼ぶ側の `85` | ON になり `CALL FAILED` | (実機で確認後に記入) |
   | 呼ぶ側の `QTY` と `FLG` | `QTY` は壊れず(`005`)、`FLG` は `-` のまま | (実機で確認後に記入) |

3. 照会メッセージの返信欄に入れる値: (実機で確認後に記入)。5250 の対話ジョブでの見え方は、**未検証(V3)** です。
4. `DSPJOBLOG` で、呼ばれる側の名前・文番号(`V0424C` の `COMP` の行)・メッセージ ID を確認します。記録: (実機で確認後に記入)。

### 4. 文字の食い違い: `V0424E`

`V0424E` は、30桁の名前を返す `V0424A` に、10桁の `NAME` を渡します。`RPG III` の `R0408BE` と違うのは、`NAME`・`GUARD`・`TAIL`(各10桁)を**データ構造 `BUF`** にまとめていることです。ILE では、単独のフィールドが宣言順に並ぶことは保証されないため、30バイトの書き込みが全部 `BUF` の中に収まるようにしてあります。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424E - calling side, NAME is 10 long but V0424A writes 30.
      * Port of R0408BE. Unlike R0408BE, NAME and GUARD sit in a data
      * structure with a 10-byte TAIL, so that all 30 bytes written by
      * V0424A land inside BUF (no storage outside BUF is touched).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DCODE             S              6A
     DRC               S              1P 0
     DBUF              DS
     D NAME                          10A
     D GUARD                         10A
     D TAIL                          10A
     C                   MOVEL     'C00001'      CODE
     C                   MOVE      *BLANKS       BUF
     C                   MOVEL     'GUARD'       GUARD
     C                   Z-ADD     9             RC
     C                   CALL      'V0424A'                             85
     C                   PARM                    CODE
     C                   PARM                    NAME
     C                   PARM                    RC
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            1 '/'
     O                       NAME                11
     O                                           12 '/'
     O                       GUARD               22
     O                                           23 '/'
     O                       RC                  24
     O               85                          40 'CALL FAILED'
```

実行する**前に**、`NAME`・`GUARD`・`RC` に何が印字されるかを予想し、実行して予想と比べます。`R0408BE`(OPM)では、`/ACME TRADI/NG CO     /0` と印字され、メッセージは出ませんでした。ILE の実際の印字とメッセージ: (実機で確認後に記入)。

### 5. 直す: `V0424X`

`V0424D` の `QTY` を `5P 0` にそろえた版が `solutions/04-24/v0424x.rpgle`(`V0424X`)です(演習2)。実行すると `00005  R` と印字されるはずです(**未検証**)。

### 6. `*PSSR`: `V0424F` と `V0424G`

`V0424G` は `V0424D` と同じ食い違い(3,0 対 5,0)で `V0424F` を呼びます。`V0424F` は `*PSSR` を持ち、エラーのときは `FLG` に `E` を入れて戻ります。

1. `V0424F`、`V0424G` を作ってコンパイルし、`CALL PGM(V0424G)` を実行します。
2. 期待(**未検証**): 照会メッセージにならず、`QTY` は `005`、`FLG` は `E` と印字され、`CALL FAILED` は出ない。実際: (実機で確認後に記入)。
3. `V0424D`(`*PSSR` なし)の結果との違いを、ジョブ・ログで比べます。

### 7. CL から呼ぶ: `C0424A`(旧システムと同じ形)

旧システムの `JU0900C` は、`DCL VAR(&MINQTY) TYPE(*DEC) LEN(3 0)` で宣言した変数を、5,0 で受ける `ZA0500` に渡します。同じ形を `C0424A` で作ります(`solutions/04-24/c0424a.clp`。演習5)。

```text
/* C0424A - CL caller: &QTY is *DEC 3 0 but V0424C expects 5,0.       */
/* Same mismatch as JU0900C (&MINQTY 3 0) against ZA0500 (MINQTY 5 0). */
             PGM
             DCL        VAR(&QTY) TYPE(*DEC) LEN(3 0) VALUE(5)
             DCL        VAR(&FLG) TYPE(*CHAR) LEN(1) VALUE('-')
             CALL       PGM(V0424C) PARM(&QTY &FLG)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000) EXEC(DO)
                SNDPGMMSG  MSG('C0424A: V0424C ended abnormally.')
             ENDDO
             SNDPGMMSG  MSG('C0424A: FLG after the call is' *BCAT &FLG)
             ENDPGM
```

1. `CRTCLPGM PGM(<USER>1/C0424A) SRCFILE(<USER>1/QCLSRC) SRCMBR(C0424A)` でコンパイルし、`CALL PGM(C0424A)` を実行します。
2. ジョブ・ログを読み、**「どの変数の宣言と、どの `*ENTRY PLIST` を見比べればよいか」**を言えるようにします。結果: (実機で確認後に記入)。
3. 参考(別の実験): CL の `CALL PGM(V0424C) PARM(5 'X')` のように、**数値リテラルをそのまま `PARM` に書く**と、`*DEC(15 5)`(8バイトのパック10進数)で渡ります(08-05b の記録。ILE の `Q0805B` に CL の裸の数値リテラル `5` を渡した例)。これを5,0(3バイト)で受けるとどうなるかは、実機バッチで記録します: (実機で確認後に記入)。

### 8. 壊れたゾーン10進数と `HEX()`: `V0424L`

05-11 と同じ要領で、型チェックを飛ばした複写でデータを壊します(自分のライブラリーの作業用の表だけを使います)。

1. 次の SQL で、文字の表 `W0424A` と、数値(ゾーン10進数)の表 `W0424B` を作ります。

   ```text
   RUNSQL SQL('CREATE TABLE <USER>1/W0424A (ID CHAR(2) NOT NULL, QTY CHAR(5) NOT NULL)') COMMIT(*NONE)
   RUNSQL SQL('CREATE TABLE <USER>1/W0424B (ID CHAR(2) NOT NULL, QTY NUMERIC(5, 0) NOT NULL)') COMMIT(*NONE)
   RUNSQL SQL('INSERT INTO <USER>1/W0424A VALUES(''A1'', ''00003''), (''B2'', ''.....''), (''C3'', ''00004'')') COMMIT(*NONE)
   CPYF FROMFILE(<USER>1/W0424A) TOFILE(<USER>1/W0424B) MBROPT(*ADD) FMTOPT(*NOCHK)
   ```

2. SQL で `SELECT ID, QTY, HEX(QTY) AS QTY_HEX FROM <USER>1/W0424B` を実行し、`B2` の行が `4B4B4B4B4B` になっていることを確認します(05-11 と同じ。`A1` は `F0F0F0F0F3` のはずです)。
3. `V0424L`(`solutions/04-24/v0424l.rpgle`)は `W0424B` を読み、`QTY` を足し込みます。`CALL PGM(V0424L)` を実行し、どの行で・どのメッセージで止まるかを `DSPJOBLOG` で確認します。記録: (実機で確認後に記入)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0424L - reads W0424B (QTY 5,0 zoned) and sums QTY into TOT.
      * Row B2 holds X4B4B4B4B4B (five periods) in QTY: not valid zoned
      * decimal data. The batch records which message the ILE program
      * raises. Prints one line (ID and running total) per good row.
     H DFTACTGRP(*YES)
     FW0424B    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     DTOT              S              9P 0
     C                   READ      W0424B                                 98
     C     *IN98         DOWEQ     *OFF
     C                   ADD       QTY           TOT
     C                   EXCEPT
     C                   READ      W0424B                                 98
     C                   ENDDO
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       ID                   2
     O                                            4 '  '
     O                       TOT           1     14
   ```

### 9. デバッガー(`STRDBG`)で値を見る(対話。V3)

**この節は 5250 の対話操作で、この教材の検証ハーネスでは確認できません。** IBM の一次資料(ILE RPG プログラマーズ・ガイド)の記述に基づく手順です。**未検証(2026-10-01時点)** として、ご自身の 5250 セッションで試してください。

1. `V0424C` を `DBGVIEW(*SOURCE)` でコンパイルしてあることを確認します(既定の `*STMT` では、ソースの行が見えません)。
2. `STRDBG PGM(<USER>1/V0424C) UPDPROD(*NO)` を実行します(ガイドでは、デバッグ・データを持つ ILE プログラムを指定し、ソース画面が出なければ `DSPMODSRC` を実行します)。
3. ソース画面で `QTY COMP 10` の行にカーソルを置いてブレークポイントを設定し(一般には F6)、F3 で画面を抜けて `CALL PGM(V0424D)` を実行します。
4. 止まったら、`EVAL QTY` と `EVAL QTY:x` で、呼ぶ側が渡した値と、16 進のバイト列を見ます。ここで `QTY` の3バイト目が何になっているかを確認します(F10 でステップ実行、F12 で再開、`ENDDBG` で終了。これらのキーは一般的な操作で、この画面では確認していません)。

## 演習

1. (読む)`V0424B` と `V0424A` の `PARM` を、上から順に見比べて、対応表を作ってください。「呼ぶ側の変数名 / 長さ / 呼ばれる側の変数名 / 長さ」の4列で3行です。
2. (直す)`V0424D` の `QTY` を、`V0424C` に合わせて直してください。直す場所は D 仕様書の1か所です。再コンパイルして実行すると `00005  R` と印字されるはずです。続けて、`Z-ADD` の `5` を `20` にすると `FLG` は `O` になるはずです(予想してから試してください)。
3. (自分で書く)呼ばれる側 `V0424J` と、呼ぶ側 `V0424K` を書いてください。
   - `V0424J`: 数量 `QTY`(`5,0`)と単価 `PRICE`(`7,0`)を受け取り、明細合計 `TOTAL`(`9,0`)に `QTY × PRICE`(`MULT`)を返す。
   - `V0424K`: `3` と `1500` を渡して呼び、`TOTAL` を編集コード `1` で印字する。`4,500` と印字されれば合格です。
   - ヒント: 受け取る変数も渡す変数も D 仕様書で宣言します。**呼ぶ側と呼ばれる側の宣言をそろえる**のを忘れないでください。編集コードは O 仕様書の44桁目です。
4. (応用)`V0424F` の `*PSSR` の終わりを、`RETURN` から `ENDSR '*CANCL'` に変えた版が `V0424H` です(呼ぶ側は `V0424I`)。実行して、呼ぶ側にどのメッセージが届くか、`85` が ON になるかを予想し、確かめてください。
5. (CL から)`C0424A` を自分で書いてください。`&QTY` を `*DEC LEN(3 0)` で宣言し、`V0424C` を呼びます。次に `&QTY` を `LEN(5 0)` に直して、結果がどう変わるかを確かめてください。
6. (わざと間違える)`V0424B` の `CALL` の標識 `85` を、71〜72桁目へ動かしてコンパイルしてください。どんなメッセージ ID が出るでしょう。(予想: リファレンスは、`CALL` の71〜72桁目は空白でなければならないと述べています。実際: (実機で確認後に記入))
7. (わざと間違える)`CALL PGM(V0424A) PARM('C00001')` のように、**`PARM` の数が足りない**呼び出しをしたらどうなるでしょう。実行前に予想し、ジョブ・ログで確かめてください(実際: (実機で確認後に記入))。

模範解答(演習2〜5)は `solutions/04-24/` にあります(`v0424x.rpgle`・`v0424j.rpgle`・`v0424k.rpgle`・`v0424h.rpgle`・`v0424i.rpgle`・`c0424a.clp`)。

## セルフチェック

- [ ] 呼ばれる側の `*ENTRY PLIST` と `PARM`、呼ぶ側の `CALL` と `PARM` を、固定形式 RPG IV の桁位置で書けた。
- [ ] `CALL` のエラー標識を73〜74桁目に書く理由(71〜72桁目は空白)を説明できた。
- [ ] 長さ・小数点位置が食い違うとき、数値と文字でそれぞれ何が起きるか(この教材の実機の記録から)を説明できた。
- [ ] ILE のメッセージ接頭辞 `RNF`・`RNQ`・`RNX`・`MCH` の違いを説明できた。
- [ ] `*PSSR` の `ENDSR` の戻り先(空白・`RETURN`・`'*CANCL'`)で何が変わるかを説明できた。
- [ ] `HEX()` で壊れたゾーン10進数を見つけられた。
- [ ] 旧システムの `JU0900C`(`DCL ... LEN(3 0)`)と `ZA0500`(`*ENTRY PLIST` の `MINQTY`)のどこを見比べるか、説明できる。

## 片付け

```text
DLTPGM PGM(<USER>1/V0424*)
DLTPGM PGM(<USER>1/C0424A)
DLTF FILE(<USER>1/W0424A)
DLTF FILE(<USER>1/W0424B)
```

ソース・メンバーは残してかまいません。`STRDBG` を使った場合は `ENDDBG` で終了します。印字されたスプールは `WRKSPLF` で削除してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Entry parameter list (`*ENTRY PLIST`) | 入口パラメーター・リスト |
| Pass by reference | 参照渡し(03-08) |
| Called program / calling program | 呼ばれる側のプログラム / 呼ぶ側のプログラム |
| Inquiry message / escape message | 照会メッセージ / エスケープ・メッセージ |
| Program exception/error subroutine (`*PSSR`) | プログラム例外/エラー・サブルーチン |
| Decimal data error | 10進数データ・エラー(05-11) |
| Debugger | デバッガー(`STRDBG`) |

次は [04-25](04-25-cycle-and-control-levels.md) に進みます。

## 実機メモ

- **未検証(2026-10-01時点)**: このレッスンのプログラム(`V0424A`〜`V0424L`・`C0424A`)は、まだ実機でコンパイルも実行もしていません(V1 にも達していません)。実機バッチ `verify/part04v-24run/` が、コンパイル(`CRTBNDRPG`、イベント・ファイルからメッセージ ID と重大度)と実行(印字とジョブ・ログ)を記録します。記録できたら、本文の「(実機で確認後に記入)」を実測値で置き換えます。
- **RPG III(OPM)の記録を、ILE の事実として使っていません。** `RPG0907`・`MCH3401` など、04-08b・05-11 の記録は OPM のものです。ILE の対応するメッセージ ID は、すべてこのバッチで確認します。
- 一次資料で確認した内容: ILE RPG リファレンスの `CALL`(エラー標識 `ER`、71〜72桁目は空白)・`PARM`・`*PSSR`・プログラム状況コード `00907`、ILE RPG プログラマーズ・ガイドの照会メッセージ(`RNQ0202`・`DSPMSGD RANGE(RNQ0100 RNQ9999) MSGF(QRNXMSG)`)・`RNX9001`・`STRDBG`・`EVAL ...:x`。
- 未確認の桁位置: O 仕様書の出力標識(`CALL FAILED` の行の `85`)を22〜23桁目に置いたこと(リファレンスの O 仕様書の桁見出しによる。CVTRPGSRC の実出力では見ていません)。C 仕様書の `PARM` の結果フィールドに長さ・小数点位置を書く形(RPG III 式)がコンパイルできるかは、実機バッチ(`V24PL`・`V24ND`)で記録します。
- `V0424E` は、`R0408BE` と違い、`NAME`・`GUARD`・`TAIL` をデータ構造にまとめています(ILE では単独のフィールドの並びが保証されないため)。
- **未検証(2026-10-01時点、V3)**: `STRDBG` の操作(ブレークポイントの設定キー、`EVAL QTY:x` の表示)と、5250 の対話ジョブでの照会メッセージへの返信。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
