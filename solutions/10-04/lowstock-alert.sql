-- lowstock-alert.sql - Lesson 10-04 model answer: the low stock alert as
-- one JSON document, built on the LOW_STOCK table function of 09-04.
--
-- STATUS: not run on the real machine yet (unverified as of 2026-09-30).
-- The batch verify/part10-04-checkpoint runs this file and records what
-- really happens; do not state a result from this header.
--
-- Prerequisite: LOW_STOCK exists (src/sql/09-04-routines.sql, SPECIFIC
-- LOWSTOCKT). Run this file like the 09-04 script:
--   RUNSQLSTM SRCSTMF('<path to this file>') COMMIT(*NONE) NAMING(*SQL)
--             DFTRDBCOL(<your dev library>) ERRLVL(40) OUTPUT(*PRINT)
-- Keep it out of source-physical-file members anyway (same rule as 09-04);
-- this file itself uses no dollar sign, no square or curly brackets, no bar.
-- Write a comma followed by a space in every list (PUB400 uses a decimal
-- comma).
--
-- Why a view and not a function: a view binds LOW_STOCK when it is created,
-- so a caller in another job should need no SQL path (unverified). A
-- function body that calls LOW_STOCK unqualified gave SQL0204 from another
-- job in 09-04. Through db2 (CLI) qualify the view name with your library.
--
-- The alert is a manual query: nothing here runs on a schedule, and the
-- 09-06 worker (C0906A) does not read it.
--
-- JSON_ARRAYAGG over zero rows should give NULL, so with no low stock
-- product the document should read count 0 and items null (checked by the
-- batch with a WHERE 1 = 0 copy of the query; read its result first).

CREATE OR REPLACE VIEW LOWALERT (ALERT_JSON) AS
  SELECT CAST(JSON_OBJECT(
           'alert': 'LOW_STOCK',
           'count': (SELECT COUNT(*)
                       FROM TABLE(LOW_STOCK()) L),
           'items': (SELECT JSON_ARRAYAGG(
                              JSON_OBJECT('product': L.PRODUCT_CODE,
                                          'name': TRIM(L.PRODUCT_NAME),
                                          'stock': L.STOCK_QTY,
                                          'reorderPoint': L.REORDER_POINT)
                              ORDER BY L.PRODUCT_CODE)
                       FROM TABLE(LOW_STOCK()) L) FORMAT JSON)
         AS VARCHAR(4000) CCSID 1208)
    FROM SYSIBM.SYSDUMMY1;

-- Try it (one statement at a time, db2 or ACS; a lone SELECT does not run
-- under RUNSQLSTM, SQL0084):
-- SELECT ALERT_JSON FROM LOWALERT;
-- The same data as a plain report, one line per product:
-- SELECT L.PRODUCT_CODE, TRIM(L.PRODUCT_NAME) AS NAME, L.STOCK_QTY,
--        L.REORDER_POINT
--   FROM TABLE(LOW_STOCK()) L ORDER BY L.PRODUCT_CODE;
-- Expected with the sample data (V2 in 09-04): P00002 (3 below 5) and
-- P00005 (12 below 50), two rows.

-- Clean up: DROP VIEW LOWALERT;
