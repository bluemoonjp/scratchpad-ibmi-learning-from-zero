# 01-06b オブジェクトとメンバーを作る・写す・名前を変える・消す

> 所要時間: 60分 / 前提レッスン: 01-06 / 目標番号: 1 / 観測方法: 最下行のメッセージ / 道具: 5250 / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1` 内の練習用オブジェクト(片付けで削除) / DBVER: なし / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- オブジェクトを複製・改名・削除できる。
- ソース物理ファイルの中のメンバーを、追加・複写・改名・削除できる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. ソース物理ファイルの1行は、何と何と何でできている?
2. `QRPGSRC` の RCDLEN はいくつにした?

答え: 1. 順序番号・日付・本文 2. 92

</details>

## なぜ学ぶか

この教科書のいたるところで、「練習用のオブジェクトを作って、試して、消す」という作業を繰り返します。ここでまとめて練習しておくと、以後のレッスンがスムーズになります。**総称名(`*` を使った指定)で自分以外のものを巻き込まないよう、常に自分のオブジェクトだけを対象にする**ことも、ここで身につけます。

## 新出

- `CRTDUPOBJ`・`RNMOBJ`・`DLTOBJ`(オブジェクトの複製・改名・削除)
- `ADDPFM`・`RMVM`・`RNMM`(メンバーの追加・削除・改名)
- `CPYSRCF`(ソース・メンバーの複写)

## 説明

### オブジェクトの複製・改名・削除

| コマンド | 意味 |
|---|---|
| `CRTDUPOBJ` | オブジェクトを複製する(元と同じ内容の新しいオブジェクトを作る) |
| `RNMOBJ` | オブジェクトの名前を変える |
| `DLTOBJ` | オブジェクトを削除する(型ごとの `DLTF`・`DLTPGM` などもよく使われる) |

### メンバーの追加・削除・改名・複写

ソース物理ファイルの中のメンバーは、ファイルそのものとは別のコマンドで操作します。

| コマンド | 意味 |
|---|---|
| `ADDPFM` | ファイルに新しいメンバーを追加する |
| `RMVM` | メンバーを削除する |
| `RNMM` | メンバーの名前を変える |
| `CPYSRCF` | ソース・メンバーの内容を、別のメンバーに複写する |

## 実演

1. コマンド行に `CRTDTAARA DTAARA(<自分のユーザー名>1/PRACTICE) TYPE(*CHAR) LEN(10) VALUE('HELLO')` と打ち、Enter を押す。練習用のデータ域を作る。
2. `CRTDUPOBJ OBJ(PRACTICE) FROMLIB(<自分のユーザー名>1) OBJTYPE(*DTAARA) TOLIB(<自分のユーザー名>1) NEWOBJ(PRACTICE2)` で複製する。
3. `WRKOBJ OBJ(<自分のユーザー名>1/PRACTICE*)` で、`PRACTICE` と `PRACTICE2` の両方があることを確認する。
4. `RNMOBJ OBJ(<自分のユーザー名>1/PRACTICE2) OBJTYPE(*DTAARA) NEWOBJ(PRACTICE3)` で改名する。
5. `WRKOBJ OBJ(<自分のユーザー名>1/PRACTICE*)` で、`PRACTICE2` が `PRACTICE3` になっていることを確認する。

## 同じ手順を別の対象で(メンバー操作)

1. コマンド行に `ADDPFM FILE(<自分のユーザー名>1/QRPGSRC) MBR(SCRATCH) TEXT('Practice member')` と打ち、Enter を押す。01-06 で作った `QRPGSRC` に、空のメンバーを追加する。
2. `WRKMBRPDM FILE(<自分のユーザー名>1/QRPGSRC)` で、メンバーが追加されたことを確認する(PDM の使い方は01-07で詳しく学びます。今は一覧が見られることだけ確認してください)。`F3` で戻る。
3. `CPYSRCF FROMFILE(<自分のユーザー名>1/QRPGSRC) TOFILE(<自分のユーザー名>1/QRPGSRC) FROMMBR(SCRATCH) TOMBR(SCRATCH2) MBROPT(*REPLACE)` で、メンバーを複写する。
4. `RNMM FILE(<自分のユーザー名>1/QRPGSRC) MBR(SCRATCH2) NEWMBR(SCRATCH3)` で改名する。
5. `RMVM FILE(<自分のユーザー名>1/QRPGSRC) MBR(SCRATCH3)` で削除する。

## 演習

1. `WRKOBJPDM` でも同じような操作ができます(オプション `3`=複写、`4`=削除、`7`=改名、`8`=説明の表示、`13`=説明の変更)。`WRKOBJPDM CURLIB` を実行し、`PRACTICE`・`PRACTICE3` の行でオプション `8` を試して、`DSPOBJD` と同じような情報が出ることを確認してください。
2. 総称名を使うときの注意を、自分の言葉で説明してください。`WRKOBJ OBJ(<自分のユーザー名>1/PRACTICE*)` は許されますが、なぜ `WRKOBJ OBJ(*ALL/PRACTICE*)` のような指定を避けるべきなのか(00-02 の規約を思い出してください)。

## セルフチェック

- [ ] オブジェクトを複製・改名できた。
- [ ] メンバーを追加・複写・改名・削除できた。
- [ ] 総称名を自分のライブラリーの中だけで使うべき理由を説明できる。

## 片付け

このレッスンで作った練習用オブジェクトを片付けます。

1. `DLTOBJ OBJ(<自分のユーザー名>1/PRACTICE) OBJTYPE(*DTAARA)`
2. `DLTOBJ OBJ(<自分のユーザー名>1/PRACTICE3) OBJTYPE(*DTAARA)`
3. `QRPGSRC` に残っている `SCRATCH` メンバーを `RMVM` で削除する。

`WRKOBJ OBJ(<自分のユーザー名>1/PRACTICE*)` を実行し、何も表示されない(オブジェクトなし)ことを確認してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Duplicate | 複製 |
| Rename | 改名 |
| Member | メンバー |

次のレッスン(01-07)では、いよいよ PDM と SEU を使って最初のプログラムを動かします。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない)。コマンドの存在とパラメーターの一般的な仕様は一次資料に基づく。実機での画面遷移は次回確認する。食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
