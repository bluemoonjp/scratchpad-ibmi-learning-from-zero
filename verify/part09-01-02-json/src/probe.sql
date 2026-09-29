-- part09-01-02-json probe script (VFYJSON). Results go into a table so they can be collected.
CREATE OR REPLACE TABLE VFYJSON (TAG VARCHAR(30), VAL VARCHAR(2000));
INSERT INTO VFYJSON VALUES ('SCHEMA', CURRENT SCHEMA);
INSERT INTO VFYJSON
  SELECT 'P1-ORDER-FORMATJSON',
         CAST(JSON_OBJECT('orderNo': M.JUNO,
                          'customer': M.JUTOK,
                          'lines': (SELECT JSON_ARRAYAGG(
                                             JSON_OBJECT('line': D.JULINE,
                                                         'product': D.JUSHO,
                                                         'qty': D.JUSU)
                                             ORDER BY D.JULINE)
                                      FROM JUCHUD D
                                     WHERE D.JUNO = M.JUNO) FORMAT JSON)
              AS VARCHAR(2000))
    FROM JUCHUM M
   WHERE M.JUNO = 'J00001';
INSERT INTO VFYJSON
  SELECT 'P1B-ORDER-NO-FORMAT',
         CAST(JSON_OBJECT('orderNo': M.JUNO,
                          'lines': (SELECT JSON_ARRAYAGG(
                                             JSON_OBJECT('line': D.JULINE)
                                             ORDER BY D.JULINE)
                                      FROM JUCHUD D
                                     WHERE D.JUNO = M.JUNO))
              AS VARCHAR(2000))
    FROM JUCHUM M
   WHERE M.JUNO = 'J00001';
INSERT INTO VFYJSON
  SELECT 'P2-NESTED',
         T.ORDER_NO CONCAT '/' CONCAT T.CUSTOMER CONCAT '/' CONCAT
         CHAR(T.LINE_NO) CONCAT '/' CONCAT T.PRODUCT CONCAT '/' CONCAT CHAR(T.QTY)
    FROM JSON_TABLE(
           '{"orderNo":"J00001","customer":"C00001","lines":[{"line":1,"product":"P00001","qty":2},{"line":2,"product":"P00003","qty":5}]}',
           'lax $'
           COLUMNS(ORDER_NO CHAR(6) PATH 'lax $.orderNo',
                   CUSTOMER CHAR(6) PATH 'lax $.customer',
                   NESTED PATH 'lax $.lines[*]'
                   COLUMNS(LINE_NO INT PATH 'lax $.line',
                           PRODUCT CHAR(6) PATH 'lax $.product',
                           QTY INT PATH 'lax $.qty'))) AS T;
INSERT INTO VFYJSON
  SELECT 'P3-KEYVALUE-SYNTAX',
         CAST(JSON_OBJECT(KEY 'k' VALUE 1, KEY 'v' VALUE 'x') AS VARCHAR(200))
    FROM SYSIBM.SYSDUMMY1;
INSERT INTO VFYJSON
  SELECT 'P4-BRACE-LITERAL', '{"a":1}' FROM SYSIBM.SYSDUMMY1;
INSERT INTO VFYJSON
  SELECT 'P4-HEX-OF-DOLLAR-BRACKET', HEX('lax $.a[*]{}') FROM SYSIBM.SYSDUMMY1;
