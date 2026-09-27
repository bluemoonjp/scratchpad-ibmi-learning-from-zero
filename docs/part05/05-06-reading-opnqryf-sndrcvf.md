# 05-06 既存の CL を読む: OPNQRYF・SNDRCVF・`*LDA`

> 所要時間: 60分 / 前提レッスン: 05-05 / 目標番号: 4 / 観測方法: バッチの実行結果・QPJOBLOG / 道具: 5250(SBMJOB/WRKSBMJOB/WRKSPLF)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: なし(05-01 の `TXLEGACY` で投入済みの `JU0900C`/`MN0000C`/`MN0000D` を読む・動かす)/ DBVER: 1 / 依存するプローブ: P15・P22(未実施)/ PTF 依存: なし / 容量の目安: わずか(スプール1件程度)

## ゴール

- `OPNQRYF`＋`OVRDBF SHARE(*YES)` の組と、共有した ODP の後始末(このプログラムでは `ZA0500` の自動クローズ＋`DLTOVR`)が、なぜセットで初めて意味を持つのかを `ju0900c.clp` の実際の並びで説明できる。
- `SNDRCVF` による CL 駆動のメニュー画面と、`*LDA`(`CHGDTAARA`)による選択値の受け渡しを、`mn0000c.clp` の実際の使い方で説明できる。
- プログラム・レベルの `MONMSG MSGID(CPF0000)` がなぜ要るかを説明し、この古い定型を今ならどう書くか言える。

## ウォームアップ

<details><summary>前回の復習(05-05)</summary>

1. `SFLSIZ＝SFLPAG`(ページ単位)のサブファイルで、ページを戻る(`ROLLDOWN`)とき、RPG は何件読み直す必要がありますか?
2. `TK0100`(RPG)は、`TK0100D` が定義するサブファイル(`SFL1`/`MSGSFL`)を実際に駆動していますか?

答え: 1. `SFLPAG` 件分(ページ単位は毎回読み直す。拡張型なら0件)。2. していない(`READC`/`SFLNXTCHG` ループも SFILE 継続行も、まだ `TK0100` には無い)。

</details>

## なぜ学ぶか

保守の現場では、**新しく書く**より前に、**既にある古い CL を正確に読める**ことの方がずっと多く求められます。`src/legacy/qclsrc/ju0900c.clp`(受注明細を絞り込んで在庫引当プログラムを起動する)と `src/legacy/qclsrc/mn0000c.clp`(この旧システムのメニュー)は、どちらも RPG III 時代からある定型パターン ── `OPNQRYF`+`OVRDBF SHARE(*YES)` による並べ替え済みODPの受け渡しと`DLTOVR`による後始末、`SNDRCVF` による CL 主導の画面、`*LDA` によるプログラム間のちょっとした値の受け渡し ── をそのまま体現しています。この2本は、第5部のチェックポイント(05-13)で実際に手を入れる保守チケット1・2の主役でもあります。ここでは直さず、**まず正確に読む**ことに集中します。

## 新出

**中核(3つ)**

- `OPNQRYF`＋`OVRDBF SHARE(*YES)`: データベース・ファイルを絞り込み・並べ替えた**オープン・データ・パス(ODP)**を、別のプログラムと共有する2点セット。共有されたODPは、それを実際に開いたプログラムがLR成立時に自動クローズし、呼び出し元は`DLTOVR`でオーバーライドだけ後始末する。
- `SNDRCVF`: CL プログラムが、DDS で定義した画面を書いてから読む(RPG の `EXFMT` に相当)命令。
- `*LDA`(ローカル・データ域): ジョブに自動的に割り当てられる、文字型のデータ域。`CHGDTAARA`/`RTVDTAARA` で読み書きする。

**コマンド等(6つまで)**

- `MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))`: プログラム・レベルの安全網。
- `DCLF FILE(...)`: CL プログラムが外部記述ファイルのレコード様式・フィールドを、対応する `&変数` として自動的に宣言する。
- `SBMJOB`: ジョブをバッチ(ジョブキュー経由)で投入する。
- `INQMSGRPY(*DFT)`: そのジョブで発生した照会メッセージに、既定の応答を自動的に使わせる。
- `ADDLIBLE`: ライブラリー・リストの先頭にライブラリーを追加する(同一ジョブ内でのみ有効)。
- `RTVJOBA CURLIB`/`CURUSER`: ジョブの現行ライブラリー・実際のユーザーを取得する。

## 説明

### OPNQRYF + OVRDBF SHARE(*YES) + DLTOVR: 実際の並びで読む

`ju0900c.clp` の該当部分を、実際の並び順のまま読みます。

```text
             OVRDBF     FILE(JUCHUD) TOFILE(&LIB/JUCHUD) SHARE(*YES)
             /* TICKET (05-13 ticket 2): unsorted JUCHUD is read in        */
             /* JUNO/JULINE (arrival/key) order, so a later-entered order  */
             /* for a short product can be allocated before an earlier    */
             /* one. See ZA0500 for the corresponding M1/MR ordering       */
             /* requirement this alone cannot satisfy.                     */
             OPNQRYF    FILE((JUCHUD)) KEYFLD((JUNO) (JULINE))
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: could not open JUCHUD.')
                GOTO       CMDLBL(TXCLOF)
             ENDDO

             CALL       PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: ZA0500 ended abnormally.')
             ENDDO

             /* FIXED (part05-legacy-probe, 2026-09-26, real-hardware      */
             /* CRTCLPGM): CLOF FILE(JUCHUD) here used to fail with        */
             /* CPD0043 ("Keyword FILE not valid") - CLOF is not a real    */
             /* command. JUCHUD's shared ODP is opened by the CALLed       */
             /* ZA0500 (its F-spec IP), which auto-closes its files on LR  */
             /* before returning here, so by the time TXCLOF runs there is */
             /* nothing left of this program's own to close.               */
TXCLOF:      DLTOVR     FILE(JUCHUD)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUM)
             MONMSG     MSGID(CPF0000)
             RETURN
```

- **`OVRDBF ... SHARE(*YES)`** は「これから `JUCHUD` を開く人は、私が作るオープン・データ・パス(ODP)を共有してよい」という予約です。これ単体では何も並べ替えません。
- **`OPNQRYF FILE((JUCHUD)) KEYFLD((JUNO) (JULINE))`** が、実際に `JUCHUD` を(`JUNO`+`JULINE` の順で並べ替えた)新しい ODP として開きます。`OVRDBF SHARE(*YES)` が直前にあるおかげで、この ODP は「共有可能」な状態です。

  **ここは注意して読んでください。** `ju0900c.clp` 冒頭のコメントはこのプログラムを「filter order details (JUCHUD) and run stock allocation」(受注明細を**絞り込んで**在庫引当を実行する)と説明していますが、実際の `OPNQRYF` には `QRYSLT`(絞り込み条件)が一つもありません。`KEYFLD((JUNO) (JULINE))` は**並べ替え**の指定だけです。コメントが述べる「絞り込み」は、このコマンド単体を見る限り行われていません。**コメントに書いてあることをそのまま信じず、実際のコマンドを読む**、という保守の基本がここでも当てはまります。
- **`CALL PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)`** が実行されると、`ZA0500` は自分で `JUCHUD` をオープンしますが、直前の `OVRDBF SHARE(*YES)`+`OPNQRYF` のおかげで、**`ZA0500` 自身は何もしていないのに、`JU0900C` が並べ替えた ODP をそのまま見ます。** もし `SHARE(*YES)` が無ければ、`ZA0500` は `JUCHUD` を(到着順など)独自に開き直してしまい、`OPNQRYF` の並べ替えは意味を失います。
- **`TXCLOF:`** には `CLOF FILE(JUCHUD)` はありません。`CLOF`(`FILE` パラメーター)は実在する CL コマンドではなく(`CPD0043`)、実機コンパイルで検出されて削除されています(上のコメントのとおり)。`JUCHUD` の共有 ODP は、`CALL` された `ZA0500`(F仕様書 `IP`)が LR 成立時に自分が開いたファイルを自動的にクローズすることで後始末されるため、`JU0900C` 側で改めて閉じる対象はそもそもありません。`TXCLOF:` が実際に行うのは `DLTOVR` による `JUCHUD`・`JUCHUM` 両方のオーバーライドの削除だけです。この後始末をしないと、オーバーライドが同じジョブの後続処理に影響を残したままになります。

**`OVRDBF SHARE(*YES)` と `OPNQRYF` のどちらが欠けても壊れます。** `OVRDBF SHARE(*YES)` が無ければ `ZA0500` は並べ替え前のデータを見ます。`OPNQRYF` が無ければ共有すべき並び替え済み ODP がそもそも存在しません。後始末の `DLTOVR` が無ければ、オーバーライドが必要以上に長く生き残ります。

**もう一点、正直に見ておくべき欠けがあります。** `FAILSAFE:` ラベルは次のとおりです。

```text
FAILSAFE:    SNDPGMMSG  MSG('JU0900C: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
```

`FAILSAFE:` は `TXCLOF:` へは進みません。つまり、プログラムの**どこか**(`OVRDBF` 2本、`RCVF`、`ADDLIBLE` など、個別の `MONMSG` を持たないコマンド)で予期しないエラーが起きてプログラム・レベルの `MONMSG MSGID(CPF0000)` が発動すると、`DLTOVR` による後始末は一切実行されないまま `ENDPGM` に至ります。これは「読んで気づく」ための題材であり、この場で直すものではありません(05-13 のチケットで扱う保守対象の候補です)。

### SNDRCVF: CL 駆動のメニュー画面

`mn0000c.clp` は `MN0000D`(レコード様式 `MNUFMT`、フィールド `SELNO`(1,0、入出力)・`MSGTXT`(40A、出力専用))を使う、この旧システムのメニュー・プログラムです。

```text
             DCLF       FILE(MN0000D)
             ...
MENU:        SNDRCVF    RCDFMT(MNUFMT)

             IF         COND(&IN03) THEN(GOTO CMDLBL(TXEND))

             CHGVAR     VAR(&SELCHAR) VALUE(&SELNO)
             CHGDTAARA  DTAARA(*LDA (1 1)) VALUE(&SELCHAR)

             IF         COND(&SELNO *EQ 1) THEN(GOTO CMDLBL(OPT1))
             IF         COND(&SELNO *EQ 2) THEN(GOTO CMDLBL(OPT2))
             IF         COND(&SELNO *EQ 3) THEN(GOTO CMDLBL(OPT3))
```

- `DCLF FILE(MN0000D)` は、`MN0000D` のレコード様式・フィールドを、CL の `&変数` として自動的に宣言します(`&SELNO`・`&MSGTXT`)。`MN0000D` は `CF03(03)` を持つため、`DCLF` は追加で `&IN03`(論理型)も宣言します。RPG の `INDARA` と違い、CL では `DCLF` した時点で応答標識が自動的に変数化されます。
- `SNDRCVF RCDFMT(MNUFMT)` が、RPG の `EXFMT` に相当する「画面を書いてから読む」動作です。学習者がメニュー番号を入力して `Enter` を押すまで、ここで制御が止まります。
- `&IN03`(F3)が ON なら、そのままメニューを抜けます。
- 選択された番号は `&SELNO`(数値)ですが、後述の `*LDA` へ渡すために、まず `&SELCHAR`(1文字の文字型)へ変換しています。

`MN0000D`(`src/legacy/qddssrc/mn0000d.dspf`)自体も、04-11/`TK0100D` と同じく DDS 条件標識を使わない設計で、`MSGTXT` は `CHGVAR` による直接上書きで書き換えます(RPG の `MOVEL` と同じ考え方の CL 版です)。

### *LDA(ローカル・データ域)

`*LDA` は、ジョブが始まると自動的に用意される、文字型の小さなデータ域です(`TK0100` の `LASTCD` のような名前付きデータ域と違い、`CRTDTAARA` で作る必要がありません)。`mn0000c.clp` の使い方は次のとおりです。

```text
             DCL        VAR(&SELCHAR) TYPE(*CHAR) LEN(1)
             ...
             CHGVAR     VAR(&SELCHAR) VALUE(&SELNO)
             CHGDTAARA  DTAARA(*LDA (1 1)) VALUE(&SELCHAR)
```

`&SELNO` は `*DEC`(数値)ですが、`CHGDTAARA` の `VALUE()` に `*CHAR` のデータ域へ渡すには文字型の値が要ります。`CHGVAR VAR(&SELCHAR) VALUE(&SELNO)` は、CL の標準的な `*DEC`→`*CHAR` 変換(右詰めの数字)です。`CHGDTAARA DTAARA(*LDA (1 1))` の `(1 1)` は「開始位置1、長さ1」で、`*LDA` の先頭1バイトだけを書き換えます。

**ここも正直に確認しておきます。** `mn0000c.clp` はこの旧システム全体の `*LDA` の使い方をヘッダー・コメントで整理しており、それによれば位置1(この選択番号)以外に、位置11〜16(`JU0300` が読む `FTOK` という得意先コード・フィルター)が使われているとされています。実際に `src/` 全体を `UDS`/`RTVDTAARA`/`*LDA` で検索すると、`JU0300`(`src/legacy/qrpgsrc/ju0300.rpg`)が I仕様書の UDS(`U` オプションのデータ構造)で位置11〜16を読む設計になっていることは確認できます(ただしこちらも実機未確認)。一方、**`mn0000c.clp` がこの位置1へ書き込んだ選択番号そのものを、`src/` 内のどのプログラムも読み返していません。** `TK0100`/`JU0300`/`JU0900C`/`ZA0500` はいずれも `*LDA` の位置1を参照しないので、`MN0000C` はこの値を書くだけで、実際には誰にも使われていません。05-05 で見た「サブファイルの画面は定義されているが RPG がまだ駆動していない」のと同じ形の、「仕組みは書かれているが、まだつながっていない」実例です。

さらに、`mn0000c.clp` のヘッダー・コメントには「位置17は `TK0100` の外部標識 `U1` に対応し、`*LDA` からロードされる」という記述がありますが、これは誤りです。**`tk0100.rpg` 自身のヘッダーが、この誤りを訂正しています。** RPG/400 Reference の「External Indicators」の節によれば、`U1`〜`U8` は `CHGJOB`/`CRTJOBD` の `SWS`(switch-setting)パラメーターで設定する**ジョブ・スイッチ**であり、`*LDA` からのロードではありません。`RPG/400 Reference` 全体を検索しても、`U1`〜`U8` を `*LDA` に結びつける記述は見当たりません。これは、05-05 の「KSFILE」の訂正と同じ形の、**このリポジトリー自身が見つけて直した誤り**です。

### プログラム・レベルの MONMSG MSGID(CPF0000) ― なぜ要るか

`ju0900c.clp`・`mn0000c.clp` はどちらも、パラメーター宣言の直後にこの1行を置いています。

```text
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))
```

これがなぜ重要かは、`tools/qclsrc/txsetup.clp` のコメントが端的に説明しています。

> Safety net: on IBM i, an *ESCAPE message left unmonitored becomes a function check (CPF9999), which on a default job sends an INQUIRY message (C/D/I/R). Nobody can answer that from a non-interactive job (SSH/system), so it HANGS forever instead of failing.

実際、このリポジトリーの検証記録(`docs/probes.md`)には、`TXSETUP` 自身がこの安全網を書き忘れていたために、`ADDPFM` の失敗(`CPF7306`)が未処理のまま `CPF9999`(機能検査)に格上げされ、応答できる相手のいない SSH の非対話ジョブが実際に無期限のハングを起こした、という記録が残っています。この行1本は「念のため」ではなく、**実際に踏んだ障害から確定した**定型です。

**ただし、`ju0900c.clp` の `FAILSAFE:` には見落としやすい弱点があります。** `SNDPGMMSG ... MSGTYPE(*COMP)` は**完了メッセージ**です。ジョブ・ログ自体には(他の `SNDPGMMSG` 行と同じく)残りますが、**呼び出し元にエスケープ・メッセージとして届くことはありません。** つまり、`JU0900C` が内部で予期しないエラーに遭い `FAILSAFE:` へ飛んでも、`JU0900C` 自体は(呼び出し元から見ると)正常に `ENDPGM` へ到達します。`mn0000c.clp` の `OPT3:` はこの `JU0900C` を次のように呼びますが、

```text
OPT3:        CHGVAR     VAR(&MSGTXT) VALUE(' ')
             CALL       PGM(&LIB/JU0900C) PARM(&RUNMODE &LIB)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                CHGVAR     VAR(&MSGTXT) VALUE('MN0000C: JU0900C ended +
                             abnormally.')
                SNDPGMMSG  MSG('MN0000C: JU0900C ended abnormally.')
             ENDDO
```

**もう一点、この `OPT3:` 自体にも注意してください。** `&RUNMODE` は `mn0000c.clp` のヘッダーいわく「意図的に空白のまま」宣言されています。`ju0900c.clp` は `&RUNMODEP` が空白なら `*LIVE` を既定値にするので、**`MN0000C` のメニューでオプション3(`JU0900C`)を選ぶと、常に `*LIVE`(実際に `ZAIKOM` を更新するモード)で実行されます。** `05-01` で「メニューから各機能を実行する」と紹介されるこの入り口から `JU0900C` を試すときは、この点を踏まえておいてください。

`JU0900C` が `FAILSAFE:` を経由して正常終了したように見える以上、**この `MONMSG MSGID(CPF0000)` は発動しません。** `MN0000C` の側からは「異常なく終わった」としか分からず、`JU0900C` が本当は途中で失敗していたことは伝わりません。今ならどう書くか、を考えると、`MSGTYPE(*COMP)` の代わりに本物のエスケープとして再送出したいところですが、`docs/probes.md` にはこの部分に関わる実機での確認済みの制約が記録されています。「`SNDPGMMSG` に `MSGTYPE(*ESCAPE)` を指定すると、`MSG()` の自由形式テキストではなく `MSGID()`(メッセージ・ファイルに登録された定型メッセージ)が必要になる(`CPD2489`)」というものです。つまり、`JU0900C` が本当にエラーを呼び出し元へ伝えたいなら、専用のメッセージ・ファイルを用意する(`ZA0500` 向けに設計だけされている `JUMSGF` のような)か、あるいは元のコマンドの失敗メッセージを `MONMSG` で吸収せずそのまま伝播させる、という判断が要ります。ここではこれ以上深入りせず、「`MSGTYPE(*COMP)` は失敗を握りつぶす」という事実だけ押さえてください。

もう一つの安全網が、次の「実演」で使う `INQMSGRPY(*DFT)` です。`mn0000c.clp` のヘッダーは、`MONMSG MSGID(CPF0000)` が **`RPG1216`(RPG 独自の照会メッセージ、`CPF` で始まらない)を捕まえられない**ことを明記しています。バッチ・ジョブに `INQMSGRPY(*DFT)` を付けておけば、`MONMSG` で捕まえられない種類の照会メッセージが万一発生しても、**そのジョブが応答者のいないまま無期限に待ち続けることだけは防げます**(メッセージの既定の応答が自動的に使われ、ジョブは先に進むか終わるかします)。ただし、既定の応答が必ずしも「処理を継続する」側とは限らない点には注意してください。`MONMSG` は「プログラムが監視しているメッセージ」だけに効く網、`INQMSGRPY(*DFT)` は「ジョブに来たすべての照会メッセージに、ハングだけはさせずに既定の応答を返す」もう一段外側の網です。

### 今ならどう書くか

- `OPNQRYF`: 現在なら、多くの場合 SQL のビュー・共通表式(CTE)や埋め込み SQL で同じことを表現します(第9部の範囲)。
- `SNDRCVF` によるメニュー: 04-11 で確認した `EXFMT` ループ、あるいは05-05のサブファイルで一覧+選択を1画面にまとめる方が今風です。
- `MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))`: 考え方(照会メッセージによる無期限ハングを防ぐ)自体は現在も有効です。今なら、`MSGTYPE(*COMP)` で握りつぶさず、専用メッセージを登録して `MSGTYPE(*ESCAPE)` で呼び出し元に正しく失敗を伝える設計にするのが望ましいところです。

## 実演

1. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `JU0900C` と `MN0000C` を開き、上の「説明」で読んだ箇所を自分のソースで確認する。`OPNQRYF` に `QRYSLT` が無いこと、`TXCLOF:` が `DLTOVR FILE(JUCHUD)` から始まり `CLOF` を含まないこと、`FAILSAFE:` が `TXCLOF:` を経由しないことを、自分の目で確かめる。
2. `JU0900C` をバッチで流す。**`RUNMODE` は必ず `*LIVE` 以外を渡してください**(`*LIVE` は `ZAIKOM`(在庫)を実際に更新します)。また、**`LIB` は必ず明示的に渡してください**。`ju0900c.clp` は `&LIB` が空白のとき、`mn0000c.clp`/`tools/qclsrc/txsetup.clp` のように `RTVJOBA CURLIB(&LIB)` で実際のライブラリー名に解決するのではなく、文字列 `'*CURLIB'` をそのまま `&LIB` へ代入するだけです(この経路が `ADDLIBLE LIB(&LIB)` に対してどう振る舞うかは、実機未確認です)。

   `SBMJOB` は指定するパラメーターが多いので、コマンド行に `SBMJOB` とだけ打って `F4`(プロンプト)で個別の欄に入力する方法を勧めます。論理的には次の値を埋めることになります。

   ```text
   CMD(CALL PGM(<自分のユーザー名>1/JU0900C) PARM('*NO' '<自分のユーザー名>1'))
   JOB(JU0900C)
   INQMSGRPY(*DFT)
   LOG(4 00 *SECLVL)
   ```

   (プローブ P15 の想定コマンド形を、`docs/probes.md` の記述に沿って `JU0900C` 向けに書き換えたものです。**この SBMJOB そのものは、このセッションではまだ実機で確認していません。**)

3. 03-12 と同じ手順で追いかけます。`WRKSBMJOB` でジョブが実行中であることをまず確認し、しばらく待ってから再度 `WRKSBMJOB` を実行してジョブが終わったことを確認します。終わったら `WRKSPLF` で、そのジョブのジョブ・ログ(スプール・ファイル `QPJOBLOG`)を開きます。`JU0900C:` で始まる `SNDPGMMSG` の文言(`could not open JUCHUD.` など)が実際に出ているか、`CPF0864`(`JUCHUM` が空)のような標準メッセージが出ていないかを、ソースの該当行と突き合わせてください。
4. `ZA0500` の呼び出し部分(`CALL PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)`)に注目する。`ju0900c.clp` 自身のコメントは、ここで渡す `&MINQTY` の宣言が `ZA0500` の `*ENTRY PLIST` の宣言と食い違っていることを認めています(05-13 保守チケット1で扱う不具合そのものです)。このレッスンでは調査・修正までは行いませんが、**この食い違いは、1回の実機実行でこの1件については実際に発生しており(`RPG0907`(10進データ・エラー)で1行も印字されないまま `ZA0500` が異常終了)、パックド10進数の桁数不一致という仕組みから見て、偶然ではなく機械的に毎回起きると考えられます**(実機メモ参照)。手順2のバッチを実際に流すと同じ並び(`RPG0907`→`CPF9999`→`JU0900C: ZA0500 ended abnormally.`、印字0件)になると見込まれますが、これは`CALL`を直接実行する形での確認であり、`SBMJOB` 経由のジョブ・ログ/スプールに実際どう残るかは未検証です。

## 演習

**流れ図を書く。** `ju0900c.clp` の実際の制御の流れを、以下の情報をもとにテキスト(箇条書きや矢印つきの ASCII でよい)で描いてください。

- `PGM` 入り口 → `DCL` 群 → プログラム・レベルの `MONMSG MSGID(CPF0000) EXEC(GOTO FAILSAFE)` 設定
- `&LIB`/`&RUNMODEP` が空白かどうかの分岐 → 既定値の代入 → `&MINQTY` に `5` を代入
- `ADDLIBLE`(`MONMSG CPF2103` のみ監視)→ `OVRDBF JUCHUM SHARE(*NO)` → `RCVF`(`MONMSG CPF0864`→メッセージ、`MONMSG CPF0000`→メッセージ)
- `OVRDBF JUCHUD SHARE(*YES)` → `OPNQRYF`(`MONMSG CPF0000`→メッセージ+`GOTO TXCLOF`)
- `CALL ZA0500`(`MONMSG CPF0000`→メッセージ)
- `TXCLOF:` → `DLTOVR`×2 → `RETURN`
- `FAILSAFE:` → `SNDPGMMSG(*COMP)` → `ENDPGM`

矢印を描くときは、**次の2種類を区別**してください。

1. ソース上に明示されている分岐(`IF`/`GOTO`/ラベル)
2. その行に個別の `MONMSG` が無いために、プログラム・レベルの安全網へ**暗黙に**つながる経路(例: 両方の `OVRDBF` 自体には専用の `MONMSG` が無いので、失敗すればそのままプログラム・レベルの `MONMSG` に捕まり `FAILSAFE:` へ飛びます)

最後に、`FAILSAFE:` へ飛んだ場合に `TXCLOF:` の後始末(`DLTOVR`×2)が実行されない、という経路を図の上で赤入れ(注記)してください。

<details><summary>解答の方針</summary>

図そのものに単一の正解はありませんが、次の点が反映されていれば十分です。

- `RCVF` と `OPNQRYF`・`CALL ZA0500` には、それぞれの直後に個別の `MONMSG` があり、特定のメッセージ(または `CPF0000` 全般)をその場で処理してから先へ進む(`OPNQRYF` だけは `GOTO TXCLOF` で打ち切る)。
- `ADDLIBLE` は `CPF2103` だけを監視しているので、それ以外の `CPF0000` 系のエラーはプログラム・レベルの安全網に落ちる。
- 両方の `OVRDBF` には個別の `MONMSG` が無く、失敗は即座にプログラム・レベルの安全網に落ちる。
- `FAILSAFE:` に落ちた場合、`TXCLOF:` の `DLTOVR`(×2)は一切実行されない。

</details>

## セルフチェック

- [ ] `OPNQRYF`＋`OVRDBF SHARE(*YES)` の組と、共有 ODP の後始末(`ZA0500` の自動クローズ＋`DLTOVR`)がセットで初めて意味を持つ理由を説明できた。
- [ ] `ju0900c.clp` の実際の `OPNQRYF` には `QRYSLT`(絞り込み)が無く、`KEYFLD`(並べ替え)だけであることに、ソースを読んで気づけた。
- [ ] `SNDRCVF` と `*LDA`(`CHGDTAARA`)の実際の使われ方(`mn0000c.clp`)を、自分の言葉で説明できた。
- [ ] `mn0000c.clp` が `*LDA` 位置1へ書き込んだ選択番号を、実際には他のどのプログラムも読み返していないことに気づけた。
- [ ] プログラム・レベルの `MONMSG MSGID(CPF0000)` がなぜ要るか、`FAILSAFE:` がなぜ `TXCLOF:` の後始末を素通りするかを説明できた。
- [ ] `ju0900c.clp` の流れ図を、`MONMSG` の有無による暗黙の分岐も含めて書けた。

## 片付け

新しく作成したオブジェクトはありません。バッチで `JU0900C` を実行した場合は、`WRKSPLF` でそのジョブのスプール・ファイルを確認し、不要であれば削除してください。`RUNMODE` を `*LIVE` 以外にしていれば `ZAIKOM` は更新されないので、後片付けとしての `TXRESET` は不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| OPNQRYF (Open Query File) | オープン照会ファイル |
| Shared ODP (Open Data Path) | 共有オープン・データ・パス |
| SNDRCVF (Send/Receive File) | 送信・受信ファイル(CL 駆動の画面表示) |
| Local Data Area (`*LDA`) | ローカル・データ域 |
| Inquiry message | 照会メッセージ |
| MONMSG | メッセージ監視 |

次のレッスン(05-07)では、影響調査(`DSPPGMREF`・`DSPDBR`・`FNDSTRPDM`)を扱います。

## 実機メモ

- **V1(コンパイル確認)は確認済みです。** `ju0900c.clp`・`mn0000c.clp`・`mn0000d.dspf` は、`part05-legacy-probe`(確認日 2026-09-26、CONFIRMED SUCCESS、2回接続)で旧システム一式11オブジェクトの一部として実機コンパイルされ、正常に作成されたことを確認しました(`part05-legacy-probe DONE` まで到達、ハングなし)。さらに `part05-txlegacy-exec`(確認日 2026-09-27、CONFIRMED SUCCESS)では、`TXLEGACY` 自身が `CLONEDIR` 配下の実ツリーから `CPYFRMSTMF` で取り込むという本来の経路で、この3ファイルを含む一式を新規に作成し `TXLEGACY: done.` まで到達したことも確認しています(CCSID 1208 への変換が壊れずに再現できることも合わせて確認済みで、上の「作る・変えるオブジェクト」欄が述べる「05-01 の `TXLEGACY` で投入済み」という前提そのものの裏付けになっています)。
- **`ju0900c.clp` の `TXCLOF:` に `CLOF FILE(JUCHUD)` があった版は、V1確認済みの版と一致しません。** `CLOF`(`FILE` パラメーター)という組み合わせは実在する CL コマンドではなく(`CPD0043`)、`part05-legacy-probe` で最初にコンパイルを試みた際にこの行がバグとして検出されました。`part05-legacy-probe` の判断では、`ZA0500`(F仕様書 `IP`)が LR 成立時に自分が開いたファイルを自動的にクローズするため `JU0900C` 側で改めて閉じる対象はそもそも無いとされ、実機コンパイルが通る版では `CLOF FILE(JUCHUD)` の行自体を削除し、`TXCLOF:` は `DLTOVR` から始まります(現在の `src/legacy/qclsrc/ju0900c.clp` もこの形です)。本文(「ゴール」「説明」「実演」「演習」「セルフチェック」)のコード引用・流れ図・目標記述は、この現行版に合わせて修正済みです。
- **`JU0900C` の実行(`OVRDBF SHARE(*YES)`＋`OPNQRYF` が成功し、`CALL PGM(&LIB/ZA0500)` まで到達すること)は、V2(実行結果の一致)に確認済みです(確認日 2026-09-27、`part05-ju0900c-baseline`)。** これは、`verify/part05-legacy-probe/manifest.json` がコンパイル確認だけに留め、後の別ステップに意図的に分けていた「`JU0900C`→`ZA0500` のバッチ実行」を実際に行ったものです。**as-shipped(05-13保守チケット1のバグ、`&MINQTY` の桁数不一致を未修正のまま)の状態での実行**である点に注意してください。`&LIB` は空白にせず実際のライブラリー名を明示的に渡し(`CALL PGM(&LIB/JU0900C) PARM('*TEST' '<USER>2')` に相当)、`OPNQRYF` は `could not open JUCHUD.` のエラーを出さずに成功し、`ZA0500` は共有 ODP 経由で少なくとも1件目のレコードを読み込みました(`LOKUP` 成立まで到達)。**そのうえで、`&MINQTY` を最初に参照する箇所(統合ソースの statement 8100)で `RPG0907`(10進データ・エラー)→`RPG9001`→`CPF9999`(`JU0900C` 自身の `MONMSG MSGID(CPF0000)` が捕捉)→`JU0900C: ZA0500 ended abnormally.` という順のメッセージが記録され、1行も印字されないまま、ハングせず正常に `part05-ju0900c-baseline DONE` まで到達しました(`FAILSAFE:` 側のメッセージは出ておらず、`TXCLOF:` の `DLTOVR`×2 を通ったと推測されます)。** `ZAIKOM` は接続前後で完全に不変でした。**このバグは、1回の実機実行でこの1件については実際に1行目で発生しました。** パックド10進数の桁数不一致という仕組みから見て、これは偶然ではなく機械的に毎回起きると考えられます(事前に立てていた「`MCH1202`が出るはず」という予想は外れ、実際は`RPG0907`でした。バグの結論自体には影響しません)。`05-13`/`src/legacy/tickets/ticket1.md` の「まれに」という表現、`ju0900c.clp` 自身のヘッダー・コメントの「corrupting its low-order digit」という説明は、どちらも実態と食い違っています(いずれも本レッスンの対象ファイルではないため、ここでは修正していません)。なお、`OPNQRYF` の `KEYFLD` による並べ替えそのもの(順序が実際に反映されているか)は、この検証では確認していません(**未検証(2026-09-27時点)**)。
- **P15(バッチ: `SBMJOB`・`QPJOBLOG`・`INQMSGRPY(*DFT)` など)は、未検証(2026-09-27時点)のままです。** `docs/probes.md` を検索しても `SBMJOB` を実機で試した記録は見当たりません。「実演」手順2の `SBMJOB` の書式(`INQMSGRPY(*DFT)`・`LOG(4 00 *SECLVL)` を含む)は、P15 の計画を踏まえたものですが、実機では未確認のままです。上記 `part05-ju0900c-baseline` の結果から、`SBMJOB` 経由で(`RUNMODE` に `*LIVE` 以外を渡して)実行した場合も、as-shipped のままであれば同じ決定論的な失敗(0行印字・`RPG0907`・ハングなし)が起きると見込まれますが、`SBMJOB` の書式そのものはあくまで未検証です。
- `SNDRCVF` は `EXFMT`・`STRDBG` と同じく対話的な機能で、SSH 経由の非対話ジョブでは検証できません(`mn0000c.clp` 自身のヘッダーもこの制約を明記しています)。**V3(対話操作)として**、実演・演習は学習者自身の実際の5250セッションで行ってください(この教材の検証方針上、5250の対話操作は自動化していません)。**参考**: `CHGDTAARA(*LDA ...)`/`RTVDTAARA` による読み書きの仕組みそのものが実機で機能することは、`mn0000c.clp` とは別の経路(`ZA0510` の `*PSSR`/`QCMDEXC` 経路、`part05-qcmdexc-runtime`、確認日 2026-09-27、CONFIRMED SUCCESS)で確認済みです。ただし `mn0000c.clp` 自身が位置1へ書き込む処理(`CHGDTAARA DTAARA(*LDA (1 1))`)は `SNDRCVF` を経由するため、引き続き未実行のまま(V1どまり)です。
- `ju0900c.clp` の `&LIB` 省略時の挙動(文字列 `'*CURLIB'` をそのまま `ADDLIBLE` に渡す経路)が実際にどう動くかは、引き続き実機未検証です。`part05-ju0900c-baseline` を含め、これまでの実行検証はいずれも `&LIB` を明示的に渡しており、この省略経路そのものは踏んでいません。実演では `LIB` を必ず明示することでこの経路を避けています。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
