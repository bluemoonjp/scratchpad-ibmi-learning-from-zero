-- 02-06: customer order inquiry (SQL version). See docs/part02/02-06-sql-inquiry.md
SELECT M.JUNO,
       M.JUDATE,
       SUM(D.JUSU * D.JUTNK) AS TOTAL
  FROM JUCHUM M
  JOIN JUCHUD D ON D.JUNO = M.JUNO
 WHERE M.JUTOK = 'C00001'
 GROUP BY M.JUNO, M.JUDATE
 ORDER BY M.JUDATE;
