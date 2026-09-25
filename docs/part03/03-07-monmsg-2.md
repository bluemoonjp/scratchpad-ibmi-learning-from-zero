# 03-07 MONMSG(2): エラー処理の骨格と自分のメッセージ・ファイル

> 所要時間: 75分(長め)/ 前提レッスン: 03-06 / 目標番号: 2・14 / 観測方法: `DSPJOBLOG` / 道具: 5250(SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/C0307A`、`<USER>1/JUMSGF`(メッセージ・ファイル)/ DBVER: 1 / 依存するプローブ: P06 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- プログラム・レベルの `MONMSG` で、プログラム全体を監視できる。
- 自分のメッセージ・ファイルを使って、`*ESCAPE` メッセージを正しく送れる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. コマンド・レベルの `MONMSG` は、何個のコマンドを監視する?
2. `CPF9800` のように末尾を `00` にすると、どうなる?

答え: 1. 直前の1個だけ 2. その範囲全体(この例では CPF9801〜CPF9899)を捕まえる

</details>

## なぜ学ぶか

03-06 では、1つのコマンドだけを監視しました。ここでは、**プログラム全体**を対象にした `MONMSG`(プログラム・レベル)を学びます。また、`SNDPGMMSG` で正式なエラー(`*ESCAPE` 型)を送るには、**メッセージ・ファイルに登録されたメッセージID**が必要だということも学びます(`docs/probes.md` に記録した、このセッションでの実機での発見です)。

## 新出

- プログラム・レベルの `MONMSG`(宣言のすぐ後に置く。**実行できるのは `GOTO` だけ**)
- `*ESCAPE` メッセージ(処理を中断して呼び出し元に伝える)
- `CRTMSGF`・`ADDMSGD`(メッセージ・ファイルとメッセージの登録)

## 説明

### プログラム・レベルの MONMSG

宣言(`DCL`)のすぐ後、最初の実行可能なコマンドの前に `MONMSG` を置くと、**そのプログラム全体**を対象にした監視になります。**ただし、プログラム・レベルの `MONMSG` で実行できるのは `GOTO` だけです。** コマンド・レベル(03-06)のように、任意のコマンドを直接実行することはできません。「想定外のエラーが起きたら、決まった後始末の場所へ飛ぶ」という使い方をします。

### *ESCAPE メッセージと自分のメッセージ・ファイル

`SNDPGMMSG` で `MSGTYPE(*ESCAPE)` を指定すると、プログラムを異常終了させ、呼び出し元にエラーを伝えられます。**このとき、`MSG()` の自由形式テキストではなく、メッセージ・ファイルに登録した `MSGID` を使う必要があります。** これは、このセッションで実際に実機のコンパイル・エラー(`CPD2489`)から発見した仕様です(`docs/probes.md` 参照)。

そのため、自分のメッセージ・ファイル(`JUMSGF`)を用意し、そこにメッセージ(`JUM0001` など)を登録しておきます。`tools/qclsrc/txmsgf.clp`(この教材のツール)が、`JUMSGF` を作成します。この `JUMSGF` は、後の API 化のレッスン(第9部)でも、エラーの語彙として再利用します。

## 実演

1. SSH で `~/ibmi-kyozai` を `git pull` で最新化する(`exit` で 5250 に戻る)。
2. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `TXMSGF`(`CLP`)を作り、`tools/qclsrc/txmsgf.clp` の内容を入力する(または SSH 経由の `CPYFRMSTMF` で取り込む)。
3. コンパイルして `CALL PGM(TXMSGF)` を実行する。`JUMSGF` が作られ、メッセージ `JUM0001`(`'Object not found: &1'`、`&1` は文字列20桁の差し替え項目)が登録される。
4. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `C0307A`(`CLP`)を作る。次を入力する(`src/qclsrc/c0307s.clp` と同じです)。

   ```clp
   PGM
   DCL        VAR(&LIB) TYPE(*CHAR) LEN(10) VALUE('*CURLIB')
   DCL        VAR(&OBJNAME) TYPE(*CHAR) LEN(20) VALUE('NOSUCHOBJ')

   MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(UNEXPCT))

   CHKOBJ     OBJ(&LIB/&OBJNAME) OBJTYPE(*DTAARA)
   MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(NOTFND))

   SNDPGMMSG  MSG('Object found.')
   GOTO       CMDLBL(END)

   NOTFND:    SNDPGMMSG  MSGID(JUM0001) MSGF(*LIBL/JUMSGF) MSGDTA(&OBJNAME) +
                           MSGTYPE(*ESCAPE)

   UNEXPCT:   SNDPGMMSG  MSG('Unexpected error. See the job log.')

   END:       ENDPGM
   ```

5. コンパイルして `CALL PGM(C0307A)` を実行する。`NOSUCHOBJ` は存在しないので、`JUM0001` の `*ESCAPE` メッセージでプログラムが終了するはずです。`DSPJOBLOG` で、`Object not found: NOSUCHOBJ` というメッセージが記録されていることを確認する。

## 演習

03-06 で作った `C0306A` の「なければ作る」ロジックに、この骨格(プログラム・レベルの `MONMSG` と、想定外エラーへの `GOTO`)を組み込んで書き直してください。

## セルフチェック

- [ ] プログラム・レベルの `MONMSG` を書けた(`GOTO` だけが使えることを理解している)。
- [ ] `JUMSGF`/`JUM0001` を使って `*ESCAPE` メッセージを送れた。
- [ ] `DSPJOBLOG` で、差し替え項目(`&1`)が正しく埋め込まれたメッセージを確認できた。

## 片付け

`JUMSGF` は、この先何度も再利用するので、そのまま残してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Escape message | エスケープ・メッセージ |
| Message file | メッセージ・ファイル |

次のレッスン(03-08)では、パラメーターと `CALL` の罠を学びます。

## 実機メモ

- 確認日: 2026-09-25。`SNDPGMMSG MSGTYPE(*ESCAPE)` に `MSGID` が必要なことは、このセッションで実機のコンパイル・エラーから確認済み(`docs/probes.md`)。`JUMSGF`/`C0307A` そのものの実機コンパイル・実行は、このセッションの SSH 接続の状況(`docs/probes.md` 参照)により未確認。次回優先して確認する。
