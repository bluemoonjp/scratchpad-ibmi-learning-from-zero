-- 02-11 checkpoint: sales rep T00002's customers and their order totals.
-- See docs/part02/02-11-checkpoint.md
SELECT T.TOKCD,
       T.TOKNM,
       COUNT(M.JUNO) AS ORDER_COUNT,
       SUM(D.JUSU * D.JUTNK) AS TOTAL
  FROM TOKUIM T
  JOIN JUCHUM M ON M.JUTOK = T.TOKCD
  JOIN JUCHUD D ON D.JUNO = M.JUNO
 WHERE T.TOKTAN = 'T00002'
 GROUP BY T.TOKCD, T.TOKNM
 ORDER BY T.TOKCD;
