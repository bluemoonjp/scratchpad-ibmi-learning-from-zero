-- 09-04: SQL routines as the API boundary. See docs/part09/09-04-sql-routines.md
-- Run this file as a script (ACS Run SQL Scripts, or RUNSQLSTM SRCSTMF from
-- the IFS). Do NOT copy it into a source-physical-file member: the JSON path
-- expressions in section 5 contain characters that move in CCSID 273.
-- Unqualified names resolve through the current schema (your dev library).
-- Write a comma followed by a space in every list (PUB400 uses a decimal comma).
-- Every routine gets an explicit SPECIFIC name (at most 10 characters) so the
-- object that Db2 creates for it has a name you can predict and check.
-- Run order: section 1 first (section 2 uses GET_CUST_NAME). Create everything
-- first, then try the routines (the commented "try it" lines at the end).

-- 1. Register existing service program procedures as SQL functions.
--    No new RPG is written: JUCSRV and ZAISRV stay exactly as they are.
--    The quoted name in EXTERNAL NAME must match the exported name exactly:
--    JUCSRV exports mixed case (extproc(*dclcase)), ZAISRV exports upper case.
--    The library part is left out, so the program is found through the
--    library list. If a call fails to find it, write the library:
--    EXTERNAL NAME 'YOURLIB/JUCSRVU(getCustName)'.
CREATE OR REPLACE FUNCTION GET_CUST_NAME (CUST_CODE CHAR(6))
  RETURNS CHAR(30)
  LANGUAGE RPGLE
  SPECIFIC GETCUSTNM
  NOT DETERMINISTIC
  NO SQL
  RETURNS NULL ON NULL INPUT
  EXTERNAL NAME 'JUCSRVU(getCustName)'
  PARAMETER STYLE GENERAL
  NOT FENCED
  DISALLOW PARALLEL;

CREATE OR REPLACE FUNCTION COUNT_CUST_ORDERS (CUST_CODE CHAR(6))
  RETURNS NUMERIC(5, 0)
  LANGUAGE RPGLE
  SPECIFIC CNTCUSTORD
  NOT DETERMINISTIC
  NO SQL
  RETURNS NULL ON NULL INPUT
  EXTERNAL NAME 'JUCSRVU(countCustOrders)'
  PARAMETER STYLE GENERAL
  NOT FENCED
  DISALLOW PARALLEL;

CREATE OR REPLACE FUNCTION GET_STOCK_QTY (PROD_CODE CHAR(6))
  RETURNS DECIMAL(7, 0)
  LANGUAGE RPGLE
  SPECIFIC GETSTOCKQT
  NOT DETERMINISTIC
  NO SQL
  RETURNS NULL ON NULL INPUT
  EXTERNAL NAME 'ZAISRVU(GET)'
  PARAMETER STYLE GENERAL
  NOT FENCED
  DISALLOW PARALLEL;

-- 2. Scalar function: one order as one JSON document (header + line array).
--    The customer name is looked up with a sub-select on TOKUIM. (A call to
--    GET_CUST_NAME here was tried on PUB400 and failed with SQL0204 when the
--    function was run from another job: the path stored with the routine
--    did not include the library. See lesson 09-04, section on the SQL path.)
CREATE OR REPLACE FUNCTION JUCHU_INQUIRY_JSON (P_ORDER_NO CHAR(6))
  RETURNS VARCHAR(4000) CCSID 1208
  LANGUAGE SQL
  SPECIFIC JUCHUINQJS
  NOT DETERMINISTIC
  READS SQL DATA
  RETURN CAST((SELECT JSON_OBJECT(
                        'orderNo': M.JUNO,
                        'customer': M.JUTOK,
                        'customerName': (SELECT TRIM(T.TOKNM)
                                           FROM TOKUIM T
                                          WHERE T.TOKCD = M.JUTOK),
                        'orderDate': M.JUDATE,
                        'salesRep': M.JUTAN,
                        'lines': (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT('line': D.JULINE,
                                                       'product': D.JUSHO,
                                                       'qty': D.JUSU,
                                                       'unitPrice': D.JUTNK)
                                           ORDER BY D.JULINE)
                                    FROM JUCHUD D
                                   WHERE D.JUNO = M.JUNO) FORMAT JSON)
                 FROM JUCHUM M
                WHERE M.JUNO = P_ORDER_NO)
              AS VARCHAR(4000) CCSID 1208);

-- 3. Table function (UDTF), written in SQL: products below the reorder point.
CREATE OR REPLACE FUNCTION LOW_STOCK ()
  RETURNS TABLE (PRODUCT_CODE CHAR(6),
                 PRODUCT_NAME CHAR(30),
                 STOCK_QTY NUMERIC(7, 0),
                 REORDER_POINT NUMERIC(5, 0))
  LANGUAGE SQL
  SPECIFIC LOWSTOCKT
  NOT DETERMINISTIC
  READS SQL DATA
  RETURN SELECT S.SHOCD, S.SHONM, Z.ZASU, S.SHOHAT
           FROM SHOHIM S
           JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
          WHERE Z.ZASU < S.SHOHAT;

-- 4. Procedure that returns a result set: open a cursor WITH RETURN and leave
--    it open (no CLOSE). ACS or a Java/ODBC client reads it; STRSQL does not.
CREATE OR REPLACE PROCEDURE LOW_STOCK_RS ()
  LANGUAGE SQL
  SPECIFIC LOWSTOCKRS
  DYNAMIC RESULT SETS 1
  READS SQL DATA
BEGIN
  DECLARE C1 CURSOR WITH RETURN FOR
    SELECT S.SHOCD, S.SHONM, Z.ZASU, S.SHOHAT
      FROM SHOHIM S
      JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
     WHERE Z.ZASU < S.SHOHAT
     ORDER BY S.SHOCD;
  OPEN C1;
END;

-- 5. Order registration: one JSON document in, one header row and its detail
--    rows out. NESTED PATH turns the line array into rows. The order number
--    is checked first so a repeated call does not create duplicate rows.
CREATE OR REPLACE PROCEDURE JUCHU_REGISTER (IN P_JSON VARCHAR(4000) CCSID 1208)
  LANGUAGE SQL
  SPECIFIC JUCHUREGST
  MODIFIES SQL DATA
  SET OPTION COMMIT = *NONE
BEGIN
  DECLARE V_NO CHAR(6);
  SET V_NO = (SELECT H.ORDER_NO
                FROM JSON_TABLE(P_JSON, 'lax $'
                       COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo')) AS H);
  IF EXISTS (SELECT 1 FROM JUCHUM WHERE JUNO = V_NO) THEN
    SIGNAL SQLSTATE '75001' SET MESSAGE_TEXT = 'Order already exists';
  END IF;
  INSERT INTO JUCHUM (JUNO, JUTOK, JUDATE, JUTAN)
    SELECT H.ORDER_NO, H.CUSTOMER, H.ORDER_DATE, H.SALES_REP
      FROM JSON_TABLE(P_JSON, 'lax $'
             COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo',
                     CUSTOMER CHAR(6) PATH 'lax $.customer',
                     ORDER_DATE DECIMAL(8, 0) PATH 'lax $.orderDate',
                     SALES_REP CHAR(6) PATH 'lax $.salesRep')) AS H;
  INSERT INTO JUCHUD (JUNO, JULINE, JUSHO, JUSU, JUTNK)
    SELECT T.ORDER_NO, T.LINE_NO, T.PRODUCT, T.QTY, T.PRICE
      FROM JSON_TABLE(P_JSON, 'lax $'
             COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo',
                     NESTED PATH 'lax $.lines[*]'
                     COLUMNS(LINE_NO DECIMAL(3, 0) PATH 'lax $.line',
                             PRODUCT CHAR(6) PATH 'lax $.product',
                             QTY DECIMAL(5, 0) PATH 'lax $.qty',
                             PRICE DECIMAL(7, 2) PATH 'lax $.unitPrice'))) AS T;
END;

-- 6. Try it (remove the leading -- and run one statement at a time).
-- SELECT JUCHU_INQUIRY_JSON('J00001') AS ORDER_JSON FROM SYSIBM.SYSDUMMY1;
-- SELECT * FROM TABLE(LOW_STOCK()) AS L ORDER BY PRODUCT_CODE;
-- CALL LOW_STOCK_RS();
-- Pass the document as ONE text literal. (Building it with JSON_OBJECT and
-- literal numbers inside RUNSQL/RUNSQLSTM gave quoted numbers and a decimal
-- comma such as "1580,00" on PUB400, and the detail insert then failed.)
-- CALL JUCHU_REGISTER('{"orderNo":"J09901","customer":"C00001","orderDate":20260930,"salesRep":"T00001","lines":[{"line":1,"product":"P00001","qty":2,"unitPrice":1580.00}]}');
-- SELECT JUCHU_INQUIRY_JSON('J09901') AS ORDER_JSON FROM SYSIBM.SYSDUMMY1;

-- 7. Clean up what you created (the sample data rows too).
-- DELETE FROM JUCHUD WHERE JUNO = 'J09901';
-- DELETE FROM JUCHUM WHERE JUNO = 'J09901';
-- DROP SPECIFIC PROCEDURE JUCHUREGST;
-- DROP SPECIFIC PROCEDURE LOWSTOCKRS;
-- DROP SPECIFIC FUNCTION LOWSTOCKT;
-- DROP SPECIFIC FUNCTION JUCHUINQJS;
-- DROP SPECIFIC FUNCTION GETSTOCKQT;
-- DROP SPECIFIC FUNCTION CNTCUSTORD;
-- DROP SPECIFIC FUNCTION GETCUSTNM;
