-- 09-02: build JSON with SQL and read it back. See docs/part09/09-02-sql-json.md
-- Run the statements one at a time in ACS Run SQL Scripts (or the VS Code
-- Db2 for i extension). RUNSQLSTM cannot run a plain SELECT (SQL0084), so
-- to run it from the IFS, wrap each SELECT as INSERT ... SELECT into a table.
-- Do NOT copy the path expressions into a source-physical-file member.
-- Unqualified names: CURRENT SCHEMA starts out as your user name, not your
-- dev library. Run SET SCHEMA <your dev library>; first (statement 0), or
-- run the file with RUNSQLSTM ... DFTRDBCOL(<your dev library>).
-- Write a comma followed by a space in every list (PUB400 uses a decimal comma).

-- 0. Point unqualified names at your dev library (replace the placeholder).
SET SCHEMA <your dev library>;

-- 1. One order (J00001) as a single JSON document: header + line array.
SELECT JSON_OBJECT(
         'orderNo': M.JUNO,
         'orderDate': M.JUDATE,
         'lines': (SELECT JSON_ARRAYAGG(
                            JSON_OBJECT('line': D.JULINE,
                                        'product': D.JUSHO,
                                        'qty': D.JUSU,
                                        'unitPrice': D.JUTNK)
                            ORDER BY D.JULINE)
                     FROM JUCHUD D
                    WHERE D.JUNO = M.JUNO) FORMAT JSON
       ) AS ORDER_JSON
  FROM JUCHUM M
 WHERE M.JUNO = 'J00001';

-- 1b. Counter-example: the same nesting WITHOUT FORMAT JSON. The line
-- array is treated as an ordinary string and is escaped a second time.
SELECT JSON_OBJECT(
         'orderNo': M.JUNO,
         'lines': (SELECT JSON_ARRAYAGG(
                            JSON_OBJECT('line': D.JULINE)
                            ORDER BY D.JULINE)
                     FROM JUCHUD D
                    WHERE D.JUNO = M.JUNO)
       ) AS ORDER_JSON
  FROM JUCHUM M
 WHERE M.JUNO = 'J00001';

-- 2. Read it back: one row per line, header fields repeated (NESTED PATH).
SELECT T.*
  FROM JSON_TABLE(
         '{"orderNo":"J00001","customer":"C00001","lines":[{"line":1,"product":"P00001","qty":2},{"line":2,"product":"P00003","qty":5}]}',
         'lax $'
         COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo',
                 CUSTOMER CHAR(6) PATH 'lax $.customer',
                 NESTED PATH 'lax $.lines[*]'
                 COLUMNS(LINE_NO INT PATH 'lax $.line',
                         PRODUCT CHAR(6) PATH 'lax $.product',
                         QTY INT PATH 'lax $.qty'))
       ) AS T;

-- 3. Round trip: every order as one JSON document, then back to rows.
WITH DOCS AS (
  SELECT M.JUNO,
         JSON_OBJECT('orderNo': M.JUNO,
                     'lines': (SELECT JSON_ARRAYAGG(
                                        JSON_OBJECT('line': D.JULINE,
                                                    'product': D.JUSHO,
                                                    'qty': D.JUSU)
                                        ORDER BY D.JULINE)
                                 FROM JUCHUD D
                                WHERE D.JUNO = M.JUNO) FORMAT JSON) AS DOC
    FROM JUCHUM M)
SELECT X.JUNO, T.LINE_NO, T.PRODUCT, T.QTY
  FROM DOCS X,
       JSON_TABLE(X.DOC, 'lax $'
         COLUMNS(NESTED PATH 'lax $.lines[*]'
                 COLUMNS(LINE_NO INT PATH 'lax $.line',
                         PRODUCT CHAR(6) PATH 'lax $.product',
                         QTY INT PATH 'lax $.qty'))) AS T
 ORDER BY X.JUNO, T.LINE_NO;

-- 4. Write a small JSON text to the IFS as UTF-8 (CCSID 1208) and read it
-- back. The directory must exist already (02-03 made /home/<user>/work).
-- Replace the placeholder path with your own home directory.
CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => '/home/<your user>/work/w.json',
                          LINE => '{"a":1}',
                          OVERWRITE => 'REPLACE',
                          END_OF_LINE => 'NONE');

SELECT * FROM TABLE(QSYS2.IFS_READ_UTF8(
                      PATH_NAME => '/home/<your user>/work/w.json'));
