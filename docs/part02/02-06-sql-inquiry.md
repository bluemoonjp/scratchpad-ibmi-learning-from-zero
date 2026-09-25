# 02-06 SQL で問い合わせる: 受注照会の SQL 版

> 所要時間: 60分 / 前提レッスン: 02-05 / 目標番号: 1 / 観測方法: SQL の SELECT 結果 / 道具: 5250(STRSQL)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: なし(参照のみ)/ DBVER: 1 / 依存するプローブ: P13 / PTF 依存: なし / 容量の目安: 0

## ゴール

- `SELECT`・`WHERE`・`ORDER BY`・`JOIN` を使って、得意先別の受注に答えられる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. `TXSETUP` が最後に行うことは?
2. `TXRESET` は何を戻す?

答え: 1. `TXSTATE` データ域に `DBVER=1` を書き込む 2. データだけ(スキーマは変えない)

</details>

## なぜ学ぶか

**ここから、この教科書を通して繰り返す「受注照会」という用件の、最初の形が始まります。** 同じ用件を、この後 SQL → CL → RPG III → RPG IV → API と、道具を変えながら何度も実装していきます(00-01 の表を思い出してください)。まずは、一番手軽な SQL で答えを出します。

## 新出

- `STRSQL`(対話式 SQL)
- `JOIN`
- 列名を明記する書き方
- `DSPPFM` での16進表示

## 説明

### STRSQL

`STRSQL` は、SQL 文を対話的に実行できる画面です。コマンド行で `STRSQL` と打つと開きます。SQL 文を入力して `F4`(実行、環境によっては Enter)で実行します。`F13`(サービスの変更)で、既定のスキーマ(`*SYS` 名前付け規則にするかどうか)などを設定できます。この教材では、テーブル名をそのまま(修飾せず)使えるよう、`*SYS` 名前付けを使います。

### JOIN と列の明記

複数のテーブルを結び付けて取得するときは `JOIN` を使います。`JUCHUM`(受注マスタ)と `JUCHUD`(受注明細)を `JUNO`(受注番号)で結び付けると、受注ごとの明細が取得できます。

**列名は `SELECT *` ではなく、必ず明記します。** どの列を使っているかが読み手にすぐ分かりますし、後でテーブルに列が増えても、意図しない列が混ざりません。

## 実演

1. コマンド行に `STRSQL` と打ち、Enter を押す。
2. 次の SQL を入力し、実行する(`src/sql/02-06-jucinq.sql` と同じ内容です)。

   ```sql
   SELECT M.JUNO,
          M.JUDATE,
          SUM(D.JUSU * D.JUTNK) AS TOTAL
     FROM JUCHUM M
     JOIN JUCHUD D ON D.JUNO = M.JUNO
    WHERE M.JUTOK = 'C00001'
    GROUP BY M.JUNO, M.JUDATE
    ORDER BY M.JUDATE;
   ```

3. 結果が2件(`J00001` と `J00003`。得意先 `C00001` の受注)表示されることを確認する。合計金額が、それぞれ `5560.00` と `9170.00` になっているはずです。

## 同じ手順を別の対象で

1. `WHERE M.JUTOK = 'C00001'` を `'C00003'` に変えて実行し、結果が変わることを確認してください。
2. `TOKUIM` と `JOIN` して、得意先名(`TOKNM`)も一緒に表示するよう書き換えてください。

   <details><summary>ヒント</summary>

   ```sql
   SELECT T.TOKNM, M.JUNO, M.JUDATE
     FROM JUCHUM M
     JOIN TOKUIM T ON T.TOKCD = M.JUTOK
    WHERE M.JUTOK = 'C00001'
    ORDER BY M.JUDATE;
   ```

   </details>

3. `TANTOM` とも `JOIN` して、担当者名も表示してください(`JUCHUM.JUTAN` = `TANTOM.TANTOCODE`)。

## 演習

1. **商品別**: `SHOHIM` と `JUCHUD` を `JOIN` し、商品ごとの受注数量の合計を求めてください。
2. **期間別**: `JUDATE` の範囲(例えば `20260905` から `20260910` の間)で受注を絞り込んでください。
3. **担当者別**: `TANTOM` と `JOIN` し、担当者ごとの受注件数を求めてください(`COUNT` を使います)。

## セルフチェック

- [ ] `STRSQL` で SQL を実行できた。
- [ ] `JOIN` で2つのテーブルを結び付けられた。
- [ ] 列名を明記して `SELECT` を書く理由を説明できる。
- [ ] 得意先ごとの合計金額を、正しく計算できた。

## 片付け

`STRSQL` で `F3` を押して終了してください。データは変更していないので、他に片付けるものはありません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Join | 結合 |
| Group by | グループ化 |

次のレッスン(02-07)では、集計と更新、`TXRESET` での戻し方を学びます。

## 実機メモ

- 確認日: 2026-09-25。金額の計算(`5560.00`・`9170.00`)は、`db/data/load_v1.sql` の実データから著者が手計算で検証済み。SQL の実行結果そのものは、`TXSETUP` の通し実行がまだ完了していないため、このセッションでは未確認(02-05 参照)。次回確認でき次第、この表記を更新する。
- `STRSQL` の画面操作は一次資料に基づく。食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
