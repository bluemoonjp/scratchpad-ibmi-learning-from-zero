-- parse-zip.sql - Lesson 09-05 model answer: read the stored API
-- response (APILOG.RESP) with JSON_TABLE. The RPG program JUHTTPSV
-- does not parse JSON; this script does. Run it with ACS Run SQL
-- Scripts, or with RUNSQLSTM SRCSTMF (NAMING(*SQL) DFTRDBCOL(lib)).
-- Path expressions use dollar and square brackets, so keep this
-- script out of CL/RPG source members.
-- The CASE turns an empty response (error rows) into NULL, so
-- JSON_TABLE returns no row for it instead of a parse error.

CREATE OR REPLACE VIEW APIZIP AS
  SELECT L.LOGID, L.ZIP, L.RC, L.HTTPST,
         T.STATUS, T.PREFCODE, T.ADDR1, T.ADDR2, T.ADDR3
    FROM APILOG L,
         JSON_TABLE(CASE WHEN L.RESPLEN > 0 THEN L.RESP END,
                    'lax $'
                    COLUMNS (STATUS INT PATH 'lax $.status',
                             NESTED PATH 'lax $.results[*]'
                             COLUMNS (PREFCODE CHAR(2)
                                        PATH 'lax $.prefcode',
                                      ADDR1 VARCHAR(60)
                                        PATH 'lax $.address1',
                                      ADDR2 VARCHAR(60)
                                        PATH 'lax $.address2',
                                      ADDR3 VARCHAR(60)
                                        PATH 'lax $.address3'))) AS T;

SELECT * FROM APIZIP ORDER BY LOGID;
