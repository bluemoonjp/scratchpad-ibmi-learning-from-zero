# 03-10 *OUTFILE・QTEMP・OVRDBF: EXPSRC を作り、TXSETUP を読む

> 所要時間: 75分(長め)/ 前提レッスン: 03-09 / 目標番号: 2 / 観測方法: `DSPJOBLOG` / 道具: 5250、SSH / 同時接続数: 5250 + SSH / 作る・変えるオブジェクト: `<USER>1/EXPSRC` / DBVER: 1 / 依存するプローブ: P08 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- コマンドの結果を `*OUTFILE` に出し、`DCLF`/`RCVF` で処理できる。
- ソースを IFS に書き出し、`git` で記録できる。
- `TXSETUP`(既に自分で動かしたツール)のソースを読んで理解できる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. CL にはキーで1件だけ読む命令がある? ない?
2. `RCVF` がファイルの終わりに達すると出るメッセージは?

答え: 1. ない 2. `CPF0864`(のようなメッセージ)

</details>

## なぜ学ぶか

多くの `DSPxxx`/`WRKxxx` コマンドは、`OUTPUT(*OUTFILE)` を指定すると、**結果を画面ではなくデータベース・ファイルとして出力**できます。これを `DCLF`/`RCVF` で読めば、コマンドの結果を CL プログラムで自由に加工できます。また、02-04 で取り込んだこの教材の中身(`TXSETUP` 等)を、実際に読んで理解する回でもあります。

## 新出

- `OUTPUT(*OUTFILE)`(コマンドの結果をファイルに出す)
- `OVRDBF`/`DLTOVR`(ファイルの一時的な差し替え)
- `QTEMP` を作業場所にする(02-09 の復習を兼ねる)
- `CPYTOSTMF`(メンバーを IFS のストリーム・ファイルへ書き出す)

## 説明

### *OUTFILE

`DSPOBJD OBJ(<自分のユーザー名>1/*ALL) OBJTYPE(*PGM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMLIST)` のように指定すると、`<USER>1` にあるすべてのプログラムの一覧が、`QTEMP/PGMLIST` というデータベース・ファイルとして作られます。これを `DCLF`/`RCVF` で読めば、「プログラムを1つずつ処理する CL」が書けます。

### OVRDBF

`DCLF`/`RCVF` で読むファイルを、実行時に**別の実際のファイルに差し替える**ことができます。例えば、プログラムの中では `JUCHUM` を読むと書いておきながら、`OVRDBF FILE(JUCHUM) TOFILE(<USER>1/JUCHUM) POSITION(*START)` のように上書き指定を行うと、読み始める位置を指定できます。`DLTOVR` で、この差し替えを取り消せます。

## 実演

1. コマンド行に `DSPOBJD OBJ(<自分のユーザー名>1/*ALL) OBJTYPE(*PGM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMLIST)` と打ち、Enter を押す。
2. `STRSQL` で `SELECT ODOBNM FROM QTEMP/PGMLIST` を実行し(列名は環境によって異なる場合があるため、`SELECT * FROM QTEMP/PGMLIST` でまず確認してください)、これまでのレッスンで作ったプログラムの一覧が出ることを確認する。

## EXPSRC を作る

1. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `EXPSRC`(`CLP`)を作る(`src/qclsrc/expsrc.clp` と同じ内容です)。

   ```clp
   PGM        PARM(&SRCFILE &SRCMBR)

   DCL        VAR(&SRCFILE) TYPE(*CHAR) LEN(10)
   DCL        VAR(&SRCMBR) TYPE(*CHAR) LEN(10)
   DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
   DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
   DCL        VAR(&TOSTMF) TYPE(*CHAR) LEN(200)

   RTVJOBA    CURLIB(&LIB) USER(&USRPRF)

   CHGVAR     VAR(&TOSTMF) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                *TCAT '/work/' *TCAT %TRIM(&SRCMBR) *TCAT '.txt')

   CPYTOSTMF  FROMMBR('/QSYS.LIB/' *TCAT %TRIM(&LIB) *TCAT +
                '.LIB/' *TCAT %TRIM(&SRCFILE) *TCAT '.FILE/' +
                *TCAT %TRIM(&SRCMBR) *TCAT '.MBR') +
                TOSTMF(&TOSTMF) STMFOPT(*REPLACE) STMFCCSID(1208) +
                ENDLINFMT(*LF)

   SNDPGMMSG  MSG('EXPSRC: exported to ' *TCAT &TOSTMF)

   ENDPGM
   ```

2. コンパイルして `CALL PGM(EXPSRC) PARM('QCLSRC' 'C0301A')` を実行する(03-01 で作ったメンバーを書き出す例です)。
3. SSH で接続し、`~/work/C0301A.txt` の内容を `cat`(または `EDTF`)で確認する。

## TXSETUP を読む

`~/ibmi-kyozai/tools/qclsrc/txsetup.clp` を、SSH の `cat`(または PC のエディター)で開き、これまで学んだ要素(`DCL`・`IF`・`CALLSUBR`/`SUBR`・`MONMSG`・`ADDPFM`・`CPYFRMSTMF`・`CRTPF`)が、どのように組み合わされているか読んでみてください。**知らない要素(`RUNSQLSTM` など)があっても構いません。** 「知っているものが、どういう役割で使われているか」を追うのが目的です。

## 演習

1. `EXPSRC` を使って、これまで作った CL プログラムのメンバーを3つ、それぞれ `~/work/` に書き出してください。
2. SSH で `~/work/` に移動し、`git init`(まだであれば)・`git add .`・`git commit` を行い、自分のソースをバージョン管理してください(この教材のリポジトリーとは別の、自分専用の記録です)。

## セルフチェック

- [ ] `*OUTFILE` でコマンドの結果をファイルにできた。
- [ ] `EXPSRC` で、メンバーを IFS に書き出せた。
- [ ] `TXSETUP` のソースを読んで、大まかな流れを説明できる。
- [ ] `git commit` で自分のソースを記録できた。

## 片付け

`QTEMP/PGMLIST` はジョブが終われば自動的に消えます。`EXPSRC` はそのまま残してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Override | 上書き指定 |
| Outfile | 出力ファイル |

次のレッスン(03-11)では、CL を自作コマンドにする方法を学びます。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない、P08)。`*OUTFILE`/`OVRDBF`/`CPYTOSTMF` の一般的な仕様は一次資料に基づく。`DSPOBJD` の `*OUTFILE` 出力の列名は環境によって正式名称が異なる場合があるため、実機で `SELECT *` して確認する前提で書いている。
