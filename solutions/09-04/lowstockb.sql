-- lowstockb.sql - Lesson 09-04 exercise (a) 3 model answer: LOW_STOCK_BELOW.
-- See docs/part09/09-04-api-boundary-sql-routines.md (exercise).
--
-- STATUS: not run on the real machine (unverified as of 2026-09-29).
--
-- Run it like the lesson script (step 2):
--   RUNSQLSTM SRCSTMF('<path to this file>') COMMIT(*NONE) NAMING(*SQL)
--             DFTRDBCOL(<your dev library>) ERRLVL(40) OUTPUT(*PRINT)
-- Unqualified names are created in, and resolved through, the DFTRDBCOL
-- library. Through db2 (CLI) qualify the function name, the SPECIFIC name
-- and the tables with your library instead (otherwise SQL0455).
-- The RETURNS TABLE types match LOW_STOCK in src/sql/09-04-routines.sql.
-- Drop it in the cleanup: DROP SPECIFIC FUNCTION <lib>.LOWSTOCKB
-- Write a comma followed by a space in every list (PUB400 uses a decimal comma).

CREATE OR REPLACE FUNCTION LOW_STOCK_BELOW (P_LIMIT NUMERIC(7, 0))
  RETURNS TABLE (PRODUCT_CODE CHAR(6),
                 PRODUCT_NAME CHAR(30),
                 STOCK_QTY NUMERIC(7, 0))
  LANGUAGE SQL
  SPECIFIC LOWSTOCKB
  NOT DETERMINISTIC
  READS SQL DATA
  RETURN SELECT S.SHOCD, S.SHONM, Z.ZASU
           FROM SHOHIM S
           JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
          WHERE Z.ZASU < P_LIMIT;
