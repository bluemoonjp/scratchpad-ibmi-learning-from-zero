-- 09-07 checkpoint: the order summary API as ONE SQL routine (model answer).
-- Returns one JSON document: the latest P_N orders and how many products are
-- below their reorder point.
-- Run this file as a script (ACS Run SQL Scripts), or as a source member with
-- RUNSQLSTM (NAMING(*SQL), DFTRDBCOL(your library)). It uses no character
-- that moves in CCSID 273 (no dollar sign, no square or curly brackets, no
-- bar) and no line is longer than 80 columns.
-- Unqualified names resolve through the current schema (your dev library).
-- Write a comma followed by a space in every list (PUB400 uses a decimal
-- comma).
-- The routine gets an explicit SPECIFIC name (at most 10 characters) so the
-- object Db2 creates for it has a name you can predict and check with
-- TXCHECK.
--
-- Built from the techniques of 09-02 (JSON_OBJECT, JSON_ARRAYAGG, FORMAT
-- JSON) and 09-04 (scalar function, VARCHAR ... CCSID 1208, SPECIFIC name).
-- It works on the base tables only, so it needs no other 09-04 routine.
-- When LOW_STOCK exists (09-04), the last entry can be written as
--    (SELECT COUNT(*) FROM TABLE(LOW_STOCK()) L)
-- and the order block can call JUCHU_INQUIRY_JSON instead; the result must
-- stay the same (compare the two versions).

CREATE OR REPLACE FUNCTION ORDER_SUMMARY_JSON (P_N INTEGER)
  RETURNS VARCHAR(4000) CCSID 1208
  LANGUAGE SQL
  SPECIFIC ORDSUMJSN
  NOT DETERMINISTIC
  READS SQL DATA
  RETURN CAST((SELECT JSON_OBJECT(
    'requested': P_N,
    'latestOrders': (SELECT JSON_ARRAYAGG(
                       JSON_OBJECT('orderNo': R.JUNO,
                                   'orderDate': R.JUDATE,
                                   'customer': R.JUTOK,
                                   'lineCount': R.LINE_CNT,
                                   'amount': R.AMOUNT)
                       ORDER BY R.RN)
                       FROM (SELECT M.JUNO, M.JUDATE, M.JUTOK,
                               (SELECT COUNT(*)
                                  FROM JUCHUD D
                                 WHERE D.JUNO = M.JUNO) AS LINE_CNT,
                               (SELECT COALESCE(SUM(D.JUSU * D.JUTNK), 0)
                                  FROM JUCHUD D
                                 WHERE D.JUNO = M.JUNO) AS AMOUNT,
                               ROW_NUMBER() OVER (
                                 ORDER BY M.JUDATE DESC, M.JUNO DESC) AS RN
                               FROM JUCHUM M) R
                      WHERE R.RN <= P_N) FORMAT JSON,
    'lowStockCount': (SELECT COUNT(*)
                        FROM SHOHIM S
                        JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
                       WHERE Z.ZASU < S.SHOHAT))
    FROM SYSIBM.SYSDUMMY1)
    AS VARCHAR(4000) CCSID 1208);

-- Try it (expected with the sample data: three orders J00008, J00007,
-- J00006, and lowStockCount 2 because P00002 and P00005 are below their
-- reorder point).
-- SELECT ORDER_SUMMARY_JSON(3) FROM SYSIBM.SYSDUMMY1;
