-- validate-zip.sql - Lesson 10-04 model answer: validate zip code lookups
-- by presence only. Two views over the tables of 09-05.
--
-- STATUS: not run on the real machine yet (unverified as of 2026-09-30).
-- The batch verify/part10-04-checkpoint runs this file after the adapter
-- calls and records the verdicts; do not state a result from this header.
--
-- Run it like the 09-05 scripts:
--   RUNSQLSTM SRCSTMF('<path to this file>') COMMIT(*NONE) NAMING(*SQL)
--             DFTRDBCOL(<your dev library>) ERRLVL(40) OUTPUT(*PRINT)
-- Prerequisites: db/mock/apimock.sql (APICFG, APIMOCK, APILOG), the adapter
-- JUHTTPSV called for some zip codes (rows in APILOG), and, for the second
-- view, solutions/09-05/parse-zip.sql (view APIZIP). If APIZIP is missing
-- only the second statement fails.
--
-- Rule of this file: a lookup is FOUND when an address field is present in
-- the response, and NOTFOUND when it is not. Nothing here compares the
-- Japanese text itself: in 09-05 a Japanese address came back as 3F3F3F in
-- a job CCSID 273 column, so a comparison on the text would be wrong.
-- This file contains only ASCII, no dollar sign and no brackets. The
-- first view needs no JSON path at all (LOCATE of the field name).
-- Write a comma followed by a space in every list.

-- 1. Over the canned responses (APIMOCK), before any adapter call.
--    HTTPERR: the canned status is 400 or more, or 0 (same rule as the
--    adapter). FOUND: the body contains the field name address1.
CREATE OR REPLACE VIEW ZIPCHECK AS
  SELECT M.ZIP, M.HTTPST,
         CASE WHEN M.HTTPST >= 400 OR M.HTTPST = 0 THEN 'HTTPERR'
              WHEN LOCATE('"address1"', M.BODY) > 0 THEN 'FOUND'
              ELSE 'NOTFOUND'
         END AS VERDICT
    FROM APIMOCK M;

-- 2. Over what the adapter really did (APILOG joined to APIZIP). The join
--    is a LEFT join because APIZIP has no row for an empty response.
--    RC comes from the adapter: HTTPERR and NOMOCK are passed through;
--    an OK call is FOUND when APIZIP has an address, else NOTFOUND.
CREATE OR REPLACE VIEW ZIPCHKLOG AS
  SELECT L.LOGID, L.ZIP, L.RC,
         CASE WHEN L.RC = 'HTTPERR' THEN 'HTTPERR'
              WHEN L.RC = 'NOMOCK' THEN 'NOMOCK'
              WHEN Z.ADDR1 IS NOT NULL THEN 'FOUND'
              ELSE 'NOTFOUND'
         END AS VERDICT
    FROM APILOG L
    LEFT JOIN APIZIP Z ON Z.LOGID = L.LOGID;

-- Try it (one statement at a time):
-- SELECT * FROM ZIPCHECK ORDER BY ZIP;
-- SELECT * FROM ZIPCHKLOG ORDER BY LOGID;
-- Expected from the mock rows (09-05): 1000001 FOUND, 9999999 NOTFOUND,
-- 9999504 HTTPERR, 9999404 HTTPERR; from the log, 1234567 NOMOCK.

-- Clean up: DROP VIEW ZIPCHKLOG; DROP VIEW ZIPCHECK;
