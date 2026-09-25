# 04-05 構造化命令とサブルーチン

> 所要時間: 75分(長め)/ 前提レッスン: 04-04 / 目標番号: 3 / 観測方法: `WRKSPLF` / 道具: 5250(SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/R0405A` / DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `IFxx`・`ELSE`・`ENDIF` で、標識を書かずに条件分岐を書ける。
- `ANDxx`・`ORxx` で条件を組み合わせられる。
- `DOWxx`・`ENDDO` で繰り返し処理を書ける。
- `EXSR`・`BEGSR`・`ENDSR` でサブルーチンを定義・呼び出しできる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. 条件標識(C 仕様書9〜17桁目)の各組は、何がどの順で入る?
2. `COMP` の結果標識は何桁目?

答え: 1. 否定(N)・標識番号2桁の順 2. 54〜59桁目

</details>

## なぜ学ぶか

04-04 で学んだ「標識で行の実行を制御する」方法は、RPG III の初期からある、**とても読みにくい**書き方です。後年の RPG III には、**標識を使わずに条件・繰り返しを書ける「構造化命令」**が追加されました。実務のコードでは両方が混在しているため、両方読めるようになる必要がありますが、**自分で書くときは構造化命令を使うほうが、はるかに分かりやすいコードになります。**

## 新出

- `IFxx`・`ELSE`・`ENDIF`(構造化 IF。`xx` は `EQ`/`NE`/`GT`/`LT`/`GE`/`LE`)
- `ANDxx`・`ORxx`(条件の組み合わせ)
- `DOWxx`・`ENDDO`(条件が真の間繰り返す。Do While)
- `EXSR`・`BEGSR`・`ENDSR`(サブルーチンの呼び出し・定義)

## 説明

### IFxx / ELSE / ENDIF

```text
C           SCORE     IFGE 80
C           SCORE     ANDLE100
C                     MOVEL'A'       GRADE  10
C                     ELSE
C                     MOVEL'B'       GRADE
C                     ENDIF
```

`IFxx` は Factor 1・Factor 2 を比較し、真なら `ELSE`(または `ENDIF`)までの行を実行します。`xx` の部分に、`EQ`(等しい)・`NE`(等しくない)・`GT`(より大きい)・`LT`(より小さい)・`GE`(以上)・`LE`(以下)のいずれかを書きます。`IFGE`(以上)なら、標識54〜55桁目(HI)を暗黙のうちに調べているのと同じですが、**標識番号を意識せずに書けます。**

### ANDxx / ORxx

`IFxx` の直後に `ANDxx`/`ORxx` の行を続けると、条件を組み合わせられます。上のコードは「`SCORE` が80以上、**かつ**100以下」という意味です。`AND` を複数続けることもできます。

### DOWxx / ENDDO

```text
C           I         DOWLE5
C                     ADD  I         SUM
C                     ADD  1         I
C                     ENDDO
```

`DOWxx`(Do While)は、条件が真である**間**、`ENDDO` までを繰り返します。`DOWLE`(以下である間)なら、`I` が5以下である間繰り返します。**繰り返しの中で `I` 自身を変化させないと、無限ループになります**(このコードでは `ADD 1 I` で1ずつ増やしています)。

### EXSR / BEGSR / ENDSR

```text
C                     EXSR PRTOUT
...
C           PRTOUT    BEGSR
C                     EXCPT
C                     ENDSR
```

**サブルーチンは、プログラムの中の「小さな別プログラム」のようなものです。** `BEGSR`(Factor 1 にサブルーチン名)から `ENDSR` までがサブルーチンの本体で、`EXSR`(Factor 2 にサブルーチン名)で呼び出します。**CL の `CALLSUBR`/`SUBR`/`ENDSUBR`(03-XX で学んだもの)と、考え方はよく似ています。** RPG III のサブルーチンも、パラメーターを受け取らず、変数はプログラム全体で共有します。

## 実演

1. `WRKMBRPDM FILE(<自分のユーザー名>1/QRPGSRC)` で `R0405A`(`RPG`)を作る。
2. 次を、桁位置に注意しながら入力する(`src/qrpgsrc/r0405s.rpg` と同じ内容です)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * R0405A - structured opcodes (IFxx/ANDxx/DOWxx) and a subroutine.
        H
        FQSYSPRT O   F     132            PRINTER
        C                     Z-ADD82        SCORE   30
        C                     Z-ADD0         SUM     50
        C                     Z-ADD1         I       30
        C           SCORE     IFGE 80
        C           SCORE     ANDLE100
        C                     MOVEL'A'       GRADE  10
        C                     ELSE
        C                     MOVEL'B'       GRADE
        C                     ENDIF
        C           I         DOWLE5
        C                     ADD  I         SUM
        C                     ADD  1         I
        C                     ENDDO
        C                     EXSR PRTOUT
        C                     SETON                     LR
        C           PRTOUT    BEGSR
        C                     EXCPT
        C                     ENDSR
        OQSYSPRT E
        O                         GRADE     10
        O                                   18 '  SUM='
        O                         SUM       24
   ```

   `SCORE`(82点)を成績(`GRADE`)に変換し、`1` から `5` までの合計を `SUM` に求め、印刷はサブルーチン `PRTOUT` にまとめています。

3. コンパイルして `CALL PGM(R0405A)` を実行し、`WRKSPLF` で `A             SUM= 00015` と印刷されることを確認する(82点は「80以上100以下」なので `A`。`1+2+3+4+5=15`)。

## 演習

1. `SCORE` の値を `55` に変えて再コンパイル・実行し、`B` が印刷されることを確認してください。
2. `DOWLE5` を `DOWLE10` に変え、`1` から `10` までの合計(`55`)が印刷されることを確認してください。
3. `ORxx` を使う練習として、`SCORE` が `0` 未満、**または** `100` を超える場合に `GRADE` を `'X'`(不正な値)にする分岐を、`IFxx`/`ORxx` を使って追加してください。

## セルフチェック

- [ ] `IFxx`・`ELSE`・`ENDIF` で条件分岐を書けた。
- [ ] `ANDxx`・`ORxx` で条件を組み合わせられた。
- [ ] `DOWxx`・`ENDDO` で繰り返し処理を書けた。
- [ ] `EXSR`・`BEGSR`・`ENDSR` でサブルーチンを定義・呼び出しできた。

## 片付け

作成したプログラムはそのまま残してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Structured opcode | 構造化命令 |
| Subroutine | サブルーチン |
| Do While | 条件が真の間繰り返す |

次のレッスン(04-06)では、外部記述ファイルを順に読む処理を書きます(いよいよファイルの入出力です)。

## 実機メモ

- 確認日: 2026-09-25。**`R0405A` を `<USER>2` で実際に `CRTRPGPGM` でコンパイルしたところ、1回目から Highest Severity 00 で成功した。** `CALL` で実行して `A             SUM= 00015` が正しく印刷されることも確認した。`IFGE`/`ANDLE`/`ELSE`/`ENDIF`/`DOWLE`/`ENDDO`/`EXSR`/`BEGSR`/`ENDSR` すべての桁位置(Factor 1・命令コード・Factor 2 の配置。`BEGSR` は Factor 1 に、`EXSR` は Factor 2 にサブルーチン名を書く)が実機で確認できた。コンパイル・リストの `IND`/`DO`欄に `B001`(ブロック開始)・`X001`(ELSE)・`E001`(ブロック終了)というネスト・レベルの印が表示され、`IFxx`/`ENDIF` と `DOWxx`/`ENDDO` の対応が正しく取れていることも確認できた。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
