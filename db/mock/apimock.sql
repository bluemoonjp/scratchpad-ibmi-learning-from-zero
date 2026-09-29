-- apimock.sql - Lesson 09-05: tables for the external API adapter
-- (JUHTTPSV). Run with RUNSQLSTM or ACS Run SQL Scripts.
--
--   APICFG   one row: APIMODE 'MOCK' or 'REAL', BASEURL = API address
--   APIMOCK  zip code -> canned HTTP status and response text
--   APILOG   one row per adapter call (written by JUHTTPSV)
--
-- Tables are created in the current schema (dev library). The canned
-- responses are built with JSON_OBJECT so that this file contains no
-- braces or brackets (they are variant characters in CCSID 273).
-- The real zipcloud response has Japanese text in address1..3; the
-- mock uses ASCII romaji only, and ZIPADR keeps the plain address.
-- Note the comma followed by a space in every list (decimal comma).

CREATE OR REPLACE TABLE APICFG
  (APIMODE CHAR(4) NOT NULL,
   BASEURL VARCHAR(100) NOT NULL);

INSERT INTO APICFG
  VALUES ('MOCK', 'https://zipcloud.ibsnet.co.jp/api/search?zipcode=');

CREATE OR REPLACE TABLE APIMOCK
  (ZIP    CHAR(7) NOT NULL PRIMARY KEY,
   HTTPST INTEGER NOT NULL,
   ZIPADR VARCHAR(100) NOT NULL,
   BODY   CLOB(8000) CCSID 1208 NOT NULL);

-- OK case: one address found (same shape as the real response).
INSERT INTO APIMOCK
  VALUES ('1000001', 200, 'TOKYO-TO CHIYODA-KU CHIYODA',
    CAST(JSON_OBJECT('message': CAST(NULL AS VARCHAR(10)),
           'results': JSON_ARRAY(
                        JSON_OBJECT('address1': 'TOKYO-TO',
                                    'address2': 'CHIYODA-KU',
                                    'address3': 'CHIYODA',
                                    'prefcode': '13',
                                    'zipcode': '1000001')
                        FORMAT JSON) FORMAT JSON,
           'status': 200) AS CLOB(8000) CCSID 1208));

-- Not found: HTTP 200, but results is null (as zipcloud does).
INSERT INTO APIMOCK
  VALUES ('9999999', 200, '',
    CAST(JSON_OBJECT('message': CAST(NULL AS VARCHAR(10)),
           'results': CAST(NULL AS VARCHAR(10)),
           'status': 200) AS CLOB(8000) CCSID 1208));

-- Failure cases: server error / not found status, empty body.
INSERT INTO APIMOCK
  VALUES ('9999504', 504, '', CAST('' AS CLOB(8000) CCSID 1208));

INSERT INTO APIMOCK
  VALUES ('9999404', 404, '', CAST('' AS CLOB(8000) CCSID 1208));

CREATE OR REPLACE TABLE APILOG
  (LOGID   BIGINT GENERATED ALWAYS AS IDENTITY,
   LOGTS   TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP,
   APIMODE CHAR(4) NOT NULL,
   ZIP     CHAR(7) NOT NULL,
   URL     VARCHAR(200) NOT NULL,
   RC      CHAR(8) NOT NULL,
   HTTPST  INTEGER NOT NULL,
   RESPLEN INTEGER NOT NULL,
   SQLST   CHAR(5) NOT NULL,
   RESP    CLOB(32000) CCSID 1208);
