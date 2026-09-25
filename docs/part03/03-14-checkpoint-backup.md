# 03-14 チェックポイント: BACKUP コマンドを作る

> 所要時間: 75分(長め)/ 前提レッスン: 03-01〜03-13 / 目標番号: 2・14 / 観測方法: `DSPJOBLOG` / 道具: 5250 / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/BACKUP` / DBVER: 1 / 依存するプローブ: P23 / PTF 依存: なし / 容量の目安: 数十 KB

## ゴール

第3部で学んだことを組み合わせて、仕様書から CL(とコマンド)を1人で作れることを確認します。**新出項目はありません。**

## 仕様書

次の仕様を満たす `BACKUP` という CL プログラムを作ってください。

1. 現行ライブラリー(`&LIB`)にあるすべてのオブジェクトを、`<USER>B` の保存ファイルに保存する。
2. 保存ファイルの名前は `BKyymmdd`(実行日)とする(02-10 の命名規則)。
3. 保存ファイルが無ければ作成する(`CHKOBJ`+`MONMSG` のパターン。03-06)。
4. 成功したら、保存先を知らせるメッセージを送る。
5. 失敗したら、`JUMSGF`(03-07)を使って `*ESCAPE` メッセージで知らせる。
6. `SBMJOB` でバッチ投入できることを確認する(03-12)。

## ヒント

- 03-10 で学んだ `RTVJOBA` で、現行ライブラリーとユーザー・プロファイルを取得できます。
- `RTVSYSVAL SYSVAL(QDATE) RTNVAR(&変数)` で、システム日付を取得できます。
- `SAVOBJ OBJ(*ALL) LIB(&LIB) DEV(*SAVF) SAVF(...) OBJTYPE(*ALL)` で、ライブラリー内のすべてのオブジェクトを保存できます。

## 自分で作ってから、模範解答と見比べる

<details><summary>模範解答(自分で作ってから開いてください。`solutions/03-14/backup.clp` と同じです)</summary>

```clp
PGM
DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
DCL        VAR(&LIBB) TYPE(*CHAR) LEN(10)
DCL        VAR(&DATE) TYPE(*CHAR) LEN(6)
DCL        VAR(&SAVF) TYPE(*CHAR) LEN(10)

MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))

RTVJOBA    CURLIB(&LIB) USER(&USRPRF)
CHGVAR     VAR(&LIBB) VALUE(%TRIM(&USRPRF) *TCAT 'B')
RTVSYSVAL  SYSVAL(QDATE) RTNVAR(&DATE)
CHGVAR     VAR(&SAVF) VALUE('BK' *TCAT &DATE)

CHKOBJ     OBJ(&LIBB/&SAVF) OBJTYPE(*FILE)
MONMSG     MSGID(CPF9801) EXEC(CRTSAVF FILE(&LIBB/&SAVF) +
             TEXT('Weekly backup'))

SAVOBJ     OBJ(*ALL) LIB(&LIB) DEV(*SAVF) SAVF(&LIBB/&SAVF) OBJTYPE(*ALL)

SNDPGMMSG  MSG('BACKUP: saved ' *TCAT &LIB *TCAT ' to ' *TCAT &LIBB +
             *TCAT '/' *TCAT &SAVF)
GOTO       CMDLBL(END)

FAILED:    SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) MSGDTA('BACKUP +
             failed') MSGTYPE(*ESCAPE)

END:       ENDPGM
```

</details>

## 実機での確認

1. コンパイルし、`SBMJOB CMD(CALL PGM(BACKUP)) JOB(BACKUP) INQMSGRPY(*DFT)` で投入する。
2. `WRKSPLF` でジョブ・ログを確認し、成功のメッセージを確認する。
3. `DSPSAVF FILE(<自分のユーザー名>B/BKyymmdd)` で、保存されたオブジェクトの一覧を確認する。
4. 02-10 で学んだ手順(`RESTOBJ` → `CRTDUPOBJ` → `DLTLIB`)で、1つのオブジェクト(例えば `C0301A`)を実際に復元してください。

## 採点表

| 項目 | 確認 |
|---|---|
| 仕様1〜3を満たす CL を自力で書けた | |
| 成功時・失敗時のメッセージを正しく実装できた | |
| バッチで実行できた | |
| 1オブジェクトを実際に復元できた | |

## 片付け

`DSPSAVF` で確認した保存ファイルはそのまま残しても構いません(02-10 で学んだとおり、容量を圧迫しないよう古いものは定期的に削除してください)。復元でできた一時ライブラリー(`TMPxxxxxx`)は、忘れずに `DLTLIB` してください。

## まとめ

これで第3部は完了です。学習記録の第3部の行にチェックを入れてください。第4部では、いよいよ RPG III を書き始めます。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない、P23)。`SAVOBJ`/`RTVSYSVAL`/`CRTSAVF` の一般的な仕様は一次資料に基づく。`QDATE` の書式は `QDATFMT` に依存するため、実機で得られる具体的な値の形式は次回確認する。
