-- lowstock-alert.sql - Lesson 10-04 model answer: the low stock alert as
-- one JSON document, built on the LOW_STOCK table function of 09-04.
--
-- STATUS: run on the real machine once (part10-04-checkpoint, 2026-09-30).
-- The first version of this file called LOW_STOCK() unqualified in the view
-- and RUNSQLSTM (NAMING(*SQL), DFTRDBCOL = dev library) stopped with SQL0204
-- "LOW_STOCK in *LIBL type *N not found": DFTRDBCOL sets the default schema
-- for tables, not the SQL path, and the path (QSYS, QSYS2, SYSPROC, SYSIBMADM,
-- user library) did not contain the dev library. The same view created
-- through db2 with the library written in front of LOW_STOCK worked and gave
-- the two expected products. This version has NOT been run yet: it repeats
-- the query of LOW_STOCK inside the view, so no function name has to be found
-- (tables are resolved through DFTRDBCOL, as in every other script here).
-- Do not state a result of this version from this header.
--
-- Prerequisite: the tables SHOHIM and ZAIKOM. The query is the one in
-- LOW_STOCK (src/sql/09-04-routines.sql, SPECIFIC LOWSTOCKT). Run this file
-- like the 09-04 script:
--   RUNSQLSTM SRCSTMF('<path to this file>') COMMIT(*NONE) NAMING(*SQL)
--             DFTRDBCOL(<your dev library>) ERRLVL(40) OUTPUT(*PRINT)
-- Keep it out of source-physical-file members anyway (same rule as 09-04);
-- this file itself uses no dollar sign, no square or curly brackets, no bar.
-- Write a comma followed by a space in every list (PUB400 uses a decimal
-- comma).
--
-- If you want the view to call LOW_STOCK itself, write your library in front
-- of it: TABLE(<your dev library>.LOW_STOCK()) (verified through db2).
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
                       FROM SHOHIM S
                       JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
                      WHERE Z.ZASU < S.SHOHAT),
           'items': (SELECT JSON_ARRAYAGG(
                              JSON_OBJECT('product': L.PRODUCT_CODE,
                                          'name': TRIM(L.PRODUCT_NAME),
                                          'stock': L.STOCK_QTY,
                                          'reorderPoint': L.REORDER_POINT)
                              ORDER BY L.PRODUCT_CODE)
                       FROM (SELECT S.SHOCD AS PRODUCT_CODE,
                                    S.SHONM AS PRODUCT_NAME,
                                    Z.ZASU AS STOCK_QTY,
                                    S.SHOHAT AS REORDER_POINT
                               FROM SHOHIM S
                               JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
                              WHERE Z.ZASU < S.SHOHAT) L) FORMAT JSON)
         AS VARCHAR(4000) CCSID 1208)
    FROM SYSIBM.SYSDUMMY1;

-- Try it (one statement at a time, db2 or ACS; a lone SELECT does not run
-- under RUNSQLSTM, SQL0084):
-- SELECT ALERT_JSON FROM LOWALERT;
-- The same data as a plain report, one line per product:
-- SELECT L.PRODUCT_CODE, TRIM(L.PRODUCT_NAME) AS NAME, L.STOCK_QTY,
--        L.REORDER_POINT
--   FROM TABLE(<your dev library>.LOW_STOCK()) L
--  ORDER BY L.PRODUCT_CODE;
-- Expected with the sample data (V2 in 09-04 and part10-04-checkpoint):
-- P00002 (3 below 5) and
-- P00005 (12 below 50), two rows.

-- Clean up: DROP VIEW LOWALERT;
