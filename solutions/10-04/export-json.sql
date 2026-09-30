-- export-json.sql - Lesson 10-04 model answer: write JSON to the IFS with
-- QSYS2.IFS_WRITE_UTF8, once with a literal line and once with a line that
-- comes from a column (the low stock alert view of lowstock-alert.sql).
--
-- STATUS: run on the real machine (part10-04-checkpoint, 2026-09-30, V2):
-- a literal LINE, a LINE from a variable filled from a view column (this
-- procedure), and a scalar subselect directly as LINE all wrote the file; a
-- relative PATH_NAME lands in the home directory of the job (not next to
-- your script); LINE of 3000 and of 20000 bytes were written whole. Read back
-- with IFS_READ_UTF8: one row, the same 180 characters. The view LOWALERT
-- must exist first.
--
-- Prerequisite: the view LOWALERT (solutions/10-04/lowstock-alert.sql).
-- Run:
--   RUNSQLSTM SRCSTMF('<path to this file>') COMMIT(*NONE) NAMING(*SQL)
--             DFTRDBCOL(<your dev library>) ERRLVL(40) OUTPUT(*PRINT)
-- then call the procedure with an absolute path of your own, for example
--   CALL <your library>.EXPORT_LOWSTOCK('/home/<your user>/work/low.json')
-- Read it back (db2 or ACS, one statement):
--   SELECT LINE_NUMBER, LINE FROM TABLE(QSYS2.IFS_READ_UTF8(
--     PATH_NAME => '/home/<your user>/work/low.json'))
-- The file has no line break at the end (END_OF_LINE => 'NONE').
-- The directory must exist: create it before (mkdir in qsh, or CRTDIR).
-- Same rules as the other scripts: no dollar sign, no brackets or braces
-- in this file (the JSON text is built by JSON_OBJECT at run time), and a
-- comma followed by a space in every list.
--
-- Fallback if IFS_WRITE_UTF8 is missing on your release: CPYTOIMPF needs
-- RCDDLM(*CR), else CPF2845 reason 11. Never demonstrated in this course
-- (unverified as of 2026-09-30).

-- 1. Literal LINE. The path is relative: it is meant to resolve against the
--    home directory of the job. Verified: the file appeared in the home
--    directory (21 bytes), not next to this script. Use an absolute path.
CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => 'p1004lit.txt',
                          LINE => 'LOW STOCK EXPORT TEST',
                          OVERWRITE => 'REPLACE',
                          END_OF_LINE => 'NONE');

-- 2. Column-valued LINE: read the document into a variable, pass the
--    variable. (A subselect directly as LINE is a separate test in the
--    batch: unverified.) VARCHAR(4000) CCSID 1208 is the type of the view.
CREATE OR REPLACE PROCEDURE EXPORT_LOWSTOCK (IN P_PATH VARCHAR(200))
  LANGUAGE SQL
  SPECIFIC EXPLOWJSN
  MODIFIES SQL DATA
  SET OPTION COMMIT = *NONE
BEGIN
  DECLARE V_JSON VARCHAR(4000) CCSID 1208;
  SET V_JSON = (SELECT A.ALERT_JSON FROM LOWALERT A);
  CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => P_PATH,
                            LINE => V_JSON,
                            OVERWRITE => 'REPLACE',
                            END_OF_LINE => 'NONE');
END;

-- Clean up: DROP SPECIFIC PROCEDURE EXPLOWJSN; and delete the files you
-- wrote (rm in qsh, or DEL in CL).
