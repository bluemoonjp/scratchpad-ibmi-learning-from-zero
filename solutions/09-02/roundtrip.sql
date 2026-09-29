-- roundtrip.sql - Lesson 09-02 model answer: TOKUIM + JUCHUM + JUCHUD
-- to JSON and back. See docs/part09/09-02-sql-json.md (exercise).
--
-- STATUS: not run on the real machine (unverified as of 2026-09-29).
-- Only the building blocks are confirmed (JSON_OBJECT, JSON_ARRAYAGG
-- with FORMAT JSON, JSON_TABLE with NESTED PATH, INSERT ... SELECT with
-- CAST(... AS VARCHAR(2000))). The join to TOKUIM, RTRIM, the EXCEPT
-- check and reading the JSON back from a table column are new here.
--
-- Run in ACS Run SQL Scripts, one statement at a time. Replace the
-- placeholders. Write a comma followed by a space in every list.
-- The path expressions contain dollar and square brackets, so keep this
-- file out of CL/RPG source members.

SET SCHEMA <your dev library>;

-- Exercise 2 (fill in): customer name added, then read back.
-- TOKNM is CHAR(30), so RTRIM it to drop the padding.
WITH DOCS AS (
  SELECT M.JUNO,
         JSON_OBJECT('orderNo': M.JUNO,
                     'customer': M.JUTOK,
                     'customerName': (SELECT RTRIM(K.TOKNM)
                                        FROM TOKUIM K
                                       WHERE K.TOKCD = M.JUTOK),
                     'lines': (SELECT JSON_ARRAYAGG(
                                        JSON_OBJECT('line': D.JULINE,
                                                    'product': D.JUSHO,
                                                    'qty': D.JUSU)
                                        ORDER BY D.JULINE)
                                 FROM JUCHUD D
                                WHERE D.JUNO = M.JUNO) FORMAT JSON) AS DOC
    FROM JUCHUM M)
SELECT T.ORDER_NO, T.CUST_CODE, T.CUST_NAME, T.LINE_NO, T.PRODUCT, T.QTY
  FROM DOCS X,
       JSON_TABLE(X.DOC, 'lax $'
         COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo',
                 CUST_CODE CHAR(6) PATH 'lax $.customer',
                 CUST_NAME VARCHAR(30) PATH 'lax $.customerName',
                 NESTED PATH 'lax $.lines[*]'
                 COLUMNS(LINE_NO INT PATH 'lax $.line',
                         PRODUCT CHAR(6) PATH 'lax $.product',
                         QTY INT PATH 'lax $.qty'))) AS T
 ORDER BY T.ORDER_NO, T.LINE_NO;

-- Exercise 3 (on your own): did the round trip lose anything?
-- Rows in JUCHUD that did not come back (expect 0 rows), and the
-- reverse (expect 0 rows). If either side returns rows, look at them.
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
    FROM JUCHUM M),
BACK AS (
  SELECT X.JUNO, T.LINE_NO, T.PRODUCT, T.QTY
    FROM DOCS X,
         JSON_TABLE(X.DOC, 'lax $'
           COLUMNS(NESTED PATH 'lax $.lines[*]'
                   COLUMNS(LINE_NO INT PATH 'lax $.line',
                           PRODUCT CHAR(6) PATH 'lax $.product',
                           QTY INT PATH 'lax $.qty'))) AS T)
SELECT JUNO, JULINE, JUSHO, JUSU FROM JUCHUD
EXCEPT
SELECT JUNO, LINE_NO, PRODUCT, QTY FROM BACK;

-- (Swap the two SELECTs for the reverse direction.)

-- Exercise 4 (extension): keep the documents in a work table. This is
-- also the shape that RUNSQLSTM can run (INSERT ... SELECT, never a bare
-- SELECT). CAST to VARCHAR(2000) is the form confirmed on the machine.
CREATE TABLE W0902A (JUNO CHAR(6) NOT NULL, DOC VARCHAR(2000));

INSERT INTO W0902A (JUNO, DOC)
  SELECT M.JUNO,
         CAST(JSON_OBJECT('orderNo': M.JUNO,
                          'lines': (SELECT JSON_ARRAYAGG(
                                             JSON_OBJECT('line': D.JULINE,
                                                         'product': D.JUSHO,
                                                         'qty': D.JUSU)
                                             ORDER BY D.JULINE)
                                      FROM JUCHUD D
                                     WHERE D.JUNO = M.JUNO) FORMAT JSON)
              AS VARCHAR(2000))
    FROM JUCHUM M;

-- Reading the documents back from the table column (unverified).
SELECT X.JUNO, T.LINE_NO, T.PRODUCT, T.QTY
  FROM W0902A X,
       JSON_TABLE(X.DOC, 'lax $'
         COLUMNS(NESTED PATH 'lax $.lines[*]'
                 COLUMNS(LINE_NO INT PATH 'lax $.line',
                         PRODUCT CHAR(6) PATH 'lax $.product',
                         QTY INT PATH 'lax $.qty'))) AS T
 ORDER BY X.JUNO, T.LINE_NO;

-- Clean up.
DROP TABLE W0902A;
