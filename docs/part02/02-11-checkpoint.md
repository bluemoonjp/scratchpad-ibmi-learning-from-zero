# 02-11 チェックポイント: 受注データ調査

> 所要時間: 60分 / 前提レッスン: 02-01〜02-10 / 目標番号: 1・11 / 観測方法: SQL の SELECT 結果 / 道具: 5250(STRSQL)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: なし(調査のみ、最後に TXRESET)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: 0

## ゴール

第2部で学んだことを組み合わせて、実際のデータ調査を1人で行えることを確認します。**新出項目はありません。**

## 課題

あなたは、担当者 `T00002` を引き継ぐことになりました。前任者のデータを確認するため、次を調べてください。

1. `T00002` が担当している得意先の一覧(得意先コードと名前)。
2. それぞれの得意先について、受注件数と受注金額の合計。
3. 商品ごとの在庫数量のうち、発注点(`SHOHAT`)を下回っているものの一覧。
4. 上記1・2の結果を、`STRSQL` の `SELECT`(`src/sql/02-11-check.sql`)で求めた後、`CPYTOIMPF` で CSV に書き出し、PC にダウンロードして表計算ソフトで開けることを確認する。

## 期待される結果

<details><summary>解答(自分で調べてから開いてください)</summary>

```sql
SELECT T.TOKCD, T.TOKNM,
       COUNT(M.JUNO) AS ORDER_COUNT,
       SUM(D.JUSU * D.JUTNK) AS TOTAL
  FROM TOKUIM T
  JOIN JUCHUM M ON M.JUTOK = T.TOKCD
  JOIN JUCHUD D ON D.JUNO = M.JUNO
 WHERE T.TOKTAN = 'T00002'
 GROUP BY T.TOKCD, T.TOKNM
 ORDER BY T.TOKCD;
```

| TOKCD | TOKNM | ORDER_COUNT | TOTAL |
|---|---|---|---|
| C00003 | BLUE OCEAN INC | 2 | 7620.00 |
| C00004 | GREEN FIELD CO | 1 | 11200.00 |

在庫が発注点を下回っている商品(02-07 の演習3と同じ考え方):

```sql
SELECT S.SHOCD, S.SHONM, Z.ZASU, S.SHOHAT
  FROM SHOHIM S
  JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
 WHERE Z.ZASU < S.SHOHAT;
```

</details>

## 採点表

| 項目 | 確認 |
|---|---|
| 得意先一覧を正しく求められた | |
| 受注件数・合計金額が解答と一致した | |
| 発注点を下回る商品を正しく求められた | |
| CSV に書き出し、PC で開けた | |
| 調査中にデータを変更していないこと(`TXRESET` が不要な状態) | |

## 片付け

このチェックポイントは調査のみなのでデータは変わっていないはずですが、念のため `TXRESET` を実行し、`TXSTATUS` で `DBVER=1` のままであることを確認してください。ダウンロードした CSV は不要であれば削除してください。

## まとめ

これで第2部は完了です。学習記録の第2部の行にチェックを入れてください。第3部では、CL プログラミングを本格的に学びます。

## 実機メモ

- 確認日: 2026-09-25。期待される結果の数値(7620.00・11200.00)は、`db/data/load_v1.sql` の実データから手計算で検証済み。**`TXSETUP` は実機での完走を確認済み**(02-05 参照)。`STRSQL` でこのレッスンの `SELECT` 文自体を実行して画面表示を確認するところまでは、このセッションではまだ行っていない。
