# 03-11 自作コマンド: JUCINQ・EXPSRC・SETENV

> 所要時間: 60分 / 前提レッスン: 03-10 / 目標番号: 2 / 観測方法: `DSPJOBLOG` / 道具: 5250(SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/JUCINQ`(コマンド)、`<USER>1/SETENV` / DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- CL プログラムを、`F4` で使える自作コマンドにできる。
- コマンドが「型付きのインターフェース」であることを説明できる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. `OUTPUT(*OUTFILE)` を指定すると何が起きる?
2. `EXPSRC` は何をするツール?

答え: 1. 結果が画面ではなくデータベース・ファイルに出る 2. メンバーを IFS のストリーム・ファイルに書き出す

</details>

## なぜ学ぶか

03-08 で、コマンド行から直接 `CALL` すると型の罠にはまることを見ました。**プログラムを「コマンド」にしてしまえば、パラメーターの型・長さが定義され、`F4` でプロンプトでき、罠も起きません。** ここでは `JUCINQ`(通し例3。03-09 の `JUCINQC` を呼び出すコマンド)を作ります。

## 新出

- `CMD`/`PARM`(コマンド定義ソースの `TYPE`/`LEN`/`MIN` など)
- CPP(Command Processing Program。コマンドの実体となるプログラム)
- `CRTCMD`

## 説明

コマンド定義ソース(`src/qcmdsrc/jucinq.cmd`)は、DDS や RPG III と同じ固定形式のソースで、**そのコマンドが受け取るパラメーターの型・長さ・必須かどうか**などを定義します。

```clp
CMD        PROMPT('Order inquiry by customer')
PARM       KWD(TOKCD) TYPE(*CHAR) LEN(6) MIN(1) +
             PROMPT('Customer code')
```

`KWD` がパラメーターのキーワード名(`TOKCD(...)` のように指定する部分)、`TYPE`/`LEN` が型と長さ、`MIN(1)` は「省略できない(最低1つ必要)」という意味です。

`CRTCMD CMD(コマンド名) PGM(呼び出すプログラム名) SRCFILE(...) SRCMBR(...)` で、コマンドをコンパイルします。**コマンドの本体である `PGM()` を、CPP(Command Processing Program)と呼びます。** `JUCINQ` というコマンドの CPP は、03-09 で作った `JUCINQC` です。今後、この CPP を RPG III 版・RPG IV 版へと差し替えていきますが(第4部・第6部)、**コマンド `JUCINQ` のインターフェース(パラメーターの型)は変わりません。** これが「コマンドは型付きのインターフェースである」という意味です。

## 実演

1. `WRKMBRPDM FILE(<自分のユーザー名>1/QCMDSRC)` で `JUCINQ`(ソース・タイプ `CMD`)を作る(`QCMDSRC` が無ければ `CRTSRCPF FILE(<自分のユーザー名>1/QCMDSRC) RCDLEN(92)` で作成してください)。
2. `src/qcmdsrc/jucinq.cmd` と同じ内容を入力する。
3. `F3` で保存し、コマンド行で `CRTCMD CMD(<自分のユーザー名>1/JUCINQ) PGM(<自分のユーザー名>1/JUCINQC) SRCFILE(<自分のユーザー名>1/QCMDSRC) SRCMBR(JUCINQ)` を実行する。
4. コマンド行に `JUCINQ` とだけ打ち、`F4` を押す。プロンプト画面に「Customer code」という項目が出るはずです。`C00001` と入力して Enter を押し、03-09 と同じ結果が出ることを確認する。
5. 得意先コードを入力せずに Enter を押すとどうなるか試してください(`MIN(1)` の効果です)。

## SETENV を作る

`SETENV`(開発環境 `*DEV` と本番役 `*PRD` を切り替えるツール)も、CL プログラムとして作ります(`src/qclsrc/setenv.clp` と同じ内容です)。今回はコマンド化まではせず、次の演習で扱います。

```clp
PGM        PARM(&ENV)
DCL        VAR(&ENV) TYPE(*CHAR) LEN(4)
DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
DCL        VAR(&LIB1) TYPE(*CHAR) LEN(10)
DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)

IF         COND(&ENV *EQ ' ') THEN(CHGVAR VAR(&ENV) VALUE('*DEV'))

RTVJOBA    USER(&USRPRF)
CHGVAR     VAR(&LIB1) VALUE(%TRIM(&USRPRF) *TCAT '1')
CHGVAR     VAR(&LIB2) VALUE(%TRIM(&USRPRF) *TCAT '2')

IF         COND(&ENV *EQ '*PRD') THEN(DO)
   CHGCURLIB  CURLIB(&LIB2)
   ADDLIBLE   LIB(&LIB1) POSITION(*LAST)
   MONMSG     MSGID(CPF2103)
   SNDPGMMSG  MSG('SETENV: now *PRD (curlib=' *TCAT %TRIM(&LIB2) *TCAT ')')
ENDDO
ELSE       CMD(DO)
   CHGCURLIB  CURLIB(&LIB1)
   RMVLIBLE   LIB(&LIB2)
   MONMSG     MSGID(CPF2105)
   SNDPGMMSG  MSG('SETENV: now *DEV (curlib=' *TCAT %TRIM(&LIB1) *TCAT ')')
ENDDO

DSPLIBL
ENDPGM
```

**なぜ `*PRD` に切り替えても `<USER>1` をライブラリー・リストに残すのか**(`ADDLIBLE ... POSITION(*LAST)`)に注目してください。`SETENV` 自身や `EXPSRC` のようなツールは `<USER>1` にあるため、現行ライブラリーを `<USER>2` に変えただけでは、それらのツールが `*LIBL` から見えなくなってしまいます(01-05 の内容を思い出してください)。この対策は、05-12(本番への移送)で本格的に使います。

`WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `SETENV` を作り、コンパイルして `CALL PGM(SETENV) PARM('*PRD')` → `DSPLIBL` の表示を確認 → `CALL PGM(SETENV) PARM('*DEV')` で元に戻す、という一連の流れを試してください。

## 演習

`EXPSRC` と `SETENV` を、`JUCINQ` と同じ要領でコマンド化してください(`CMD`/`PARM` を書いて `CRTCMD`)。`SETENV` の `PARM` には `RSTD(*YES) VALUES('*DEV' '*PRD')`(入力できる値を制限する)を付けてみてください(`F1` で `RSTD`/`VALUES` の意味を確認してください)。

## セルフチェック

- [ ] `JUCINQ` コマンドを作り、`F4` でプロンプトできた。
- [ ] `MIN(1)` の効果を確認した。
- [ ] CPP(コマンドの実体)の意味を説明できる。
- [ ] `SETENV` で開発/本番役を切り替え、`<USER>1` が `*LIBL` に残ることを確認した。

## 片付け

`SETENV` を実行したままにせず、最後に `*DEV` に戻してから終えてください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Command | コマンド |
| CPP | コマンド処理プログラム |

次のレッスン(03-12)では、バッチ・ジョブの投入と監視を学びます。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない)。`CMD`/`PARM`/`CRTCMD` の一般的な仕様は一次資料に基づく。`SETENV` の `ADDLIBLE ... POSITION(*LAST)` の設計は、批評で見つかった「`*PRD` 切り替え時に `<USER>1` が `*LIBL` から外れる」問題への対策として組み込んだが、実機での動作確認はまだ行っていない。
