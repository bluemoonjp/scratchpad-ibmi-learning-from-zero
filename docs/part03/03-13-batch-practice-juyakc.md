# 03-13 CL 実践: 夜間ジョブストリーム JUYAKC

> 所要時間: 90分(長め)/ 前提レッスン: 03-12 / 目標番号: 2 / 観測方法: `DSPJOBLOG` / 道具: 5250 / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/JUYAKC` / DBVER: 1 / 依存するプローブ: P15, P17, P35 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 前処理・本処理・後処理・異常処理がそろった、実践的な CL を書ける。
- バッチで安全に投入・実行できる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. `SBMJOB` に必ず付けるべきパラメーターは?
2. バッチで使わない命令は?

答え: 1. `INQMSGRPY(*DFT)` 2. `DSPLY`

</details>

## なぜ学ぶか

これまでのレッスンは、1つの新しい要素を確認するための小さなプログラムでした。ここでは、**現場でよくある「夜間バッチ」の形**を、1本の CL にまとめます。第4部で RPG III を学んだ後、この骨格の「本処理」の部分に、実際の業務処理(在庫引当 `ZAHIK3`)を差し込みます。

## 新出

- `ALCOBJ`/`DLCOBJ`(オブジェクトの排他制御)
- `RTVDTAARA`/`CHGDTAARA`(データ域の読み書き。採番に使う)
- `OVRPRTF`(印刷装置ファイルの上書き指定)

## 説明

### 前処理・本処理・後処理・異常処理

実務のバッチ処理は、大きく4つに分けて考えると整理しやすくなります。

| 段階 | 内容 |
|---|---|
| 前処理 | 準備(採番、ロックの確保など) |
| 本処理 | 実際の業務処理 |
| 後処理 | 結果の出力、片付け |
| 異常処理 | 途中で失敗したときの対応 |

### 排他制御と採番

複数のジョブが同時に「次の受注番号」を採番しようとすると、同じ番号を2つの受注が使ってしまう競合が起きます。`ALCOBJ`(排他を確保する)→ `RTVDTAARA`(現在値を読む)→ `CHGDTAARA`(次の値を書く)→ `DLCOBJ`(排他を解放する)、という手順で、これを防ぎます。

## 実演

1. `TXMSGF`(03-07)と `JUNODA`(03-06)が既に作られていることを確認する(`DSPOBJD OBJ(<自分のユーザー名>1/JUNODA) OBJTYPE(*DTAARA)`)。
2. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `JUYAKC`(`CLP`)を作る(`src/qclsrc/juyakc.clp` と同じ内容です)。

   ```clp
   PGM
   DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
   DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
   DCL        VAR(&NEXTNO) TYPE(*DEC) LEN(6 0)
   DCL        VAR(&TOSTMF) TYPE(*CHAR) LEN(200)

   MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))

   RTVJOBA    CURLIB(&LIB) CURUSER(&USRPRF)

   ALCOBJ     OBJ((&LIB/JUNODA *DTAARA *EXCL)) WAIT(10)
   MONMSG     MSGID(CPF1002 CPF1085) EXEC(DO)
      SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) +
                   MSGDTA('JUNODA locked') MSGTYPE(*ESCAPE)
   ENDDO

   RTVDTAARA  DTAARA(&LIB/JUNODA) RTNVAR(&NEXTNO)
   CHGVAR     VAR(&NEXTNO) VALUE(&NEXTNO + 1)
   CHGDTAARA  DTAARA(&LIB/JUNODA) VALUE(&NEXTNO)
   DLCOBJ     OBJ((&LIB/JUNODA *DTAARA *EXCL))

   /* Main: business processing plugs in here (Part 4 onward) */

   CHGVAR     VAR(&TOSTMF) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                *TCAT '/work/juchum_export.csv')
   CPYTOIMPF  FROMFILE(&LIB/JUCHUM) TOSTMF(&TOSTMF) MBROPT(*REPLACE) +
                STMFCCSID(1208)

   SNDPGMMSG  MSG('JUYAKC: done. Next order number is now ' *BCAT +
                %CHAR(&NEXTNO) *BCAT '.')
   GOTO       CMDLBL(END)

   FAILED:    SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) +
                MSGDTA('JUYAKC failed') MSGTYPE(*ESCAPE)

   END:       ENDPGM
   ```

3. コンパイルする。
4. `SBMJOB CMD(CALL PGM(JUYAKC)) JOB(JUYAKC) INQMSGRPY(*DFT)` で投入する。
5. `WRKSBMJOB` で完了を待ち、`WRKSPLF` でジョブ・ログを確認する。`JUNODA` の値が1つ増えていることも、`DSPOBJD`(または `RTVDTAARA` を使う小さなテスト・プログラム)で確認してください。

## 演習: わざと失敗させる

1. **ロック中に失敗させる**: `ALCOBJ OBJ((<自分のユーザー名>1/JUNODA *DTAARA *EXCL)) WAIT(*IMMED)` をコマンド行から直接実行して排他を確保したまま(解放しない)、別途 `JUYAKC` を投入し、`ALCOBJ` の失敗(ロック競合)でエラーになることを確認してください。確認できたら、最初に確保した排他は `DLCOBJ OBJ((<自分のユーザー名>1/JUNODA *DTAARA *EXCL))` で解放してください。
2. **データなしで失敗させる**: `JUCHUM` を一時的に `RNMOBJ` で別名に変えてから `JUYAKC` を投入し、`CPYTOIMPF` の失敗が正しく捕まることを確認してください。確認できたら、元の名前に戻してください。

## セルフチェック

- [ ] 前処理・本処理・後処理・異常処理という構造を説明できる。
- [ ] `ALCOBJ`/`DLCOBJ` で排他制御ができた。
- [ ] `JUYAKC` をバッチで実行し、正常終了を確認できた。
- [ ] ロック競合・データなしの2通りの失敗を、意図的に再現できた。

## 片付け

演習で使った一時的な変更(排他の解放、ファイル名を元に戻すこと)を確認してください。

## まとめ

次のレッスン(03-14)は、第3部のチェックポイントです。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない、P15, P17, P35)。`ALCOBJ` のロック競合時のメッセージID(`CPF1002`/`CPF1085`)は、一次資料からの推定であり、実機で確定させる必要がある。`ALCOBJ`/`DLCOBJ`/`CPYTOIMPF` の一般的な仕様は一次資料に基づく。
