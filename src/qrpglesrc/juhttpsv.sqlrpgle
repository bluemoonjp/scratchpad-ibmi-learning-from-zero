**FREE
// JUHTTPSV - Lesson 09-05: adapter for the external zip code API.
//
// Given a 7 digit zip code, either reads the canned response from
// APIMOCK (mode MOCK) or calls QSYS2.HTTP_GET (mode REAL). The mode
// is read from the one-row table APICFG. The raw response text is
// kept in a CLOB host variable (UTF-8) and written to APILOG together
// with mode, url, result code, length and SQLSTATE.
//
// This program does NOT parse the response. JSON parsing lives in a
// separate .sql script (solutions/09-05/parse-zip.sql), because JSON
// path expressions need characters that are unsafe in CL/RPG source.
//
// Parameters: zip (input, 7 chars), rc (output, 8 chars):
//   OK       response stored in APILOG
//   HTTPERR  mock row with an error status, or the real call failed
//   NOMOCK   mode MOCK but no APIMOCK row for this zip code
// Tables are found through the library list (system naming), so the
// caller must have the library on the list or as current library.
//
// Status: draft, not yet compiled on the real machine.
ctl-opt dftactgrp(*no) actgrp(*new);

dcl-pi *n;
  zip char(7);
  rc  char(8);
end-pi;

// CLOB host variable: the precompiler turns this into a data
// structure with fields resp_len and resp_data.
dcl-s resp sqltype(clob:32000) ccsid(1208);
dcl-s wMode  char(4) inz('MOCK');
dcl-s wBase  varchar(100) inz('');
dcl-s wUrl   varchar(200) inz('');
dcl-s wSt    int(10) inz(0);
dcl-s wSqlst char(5) inz('00000');

exec sql SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;

rc = 'OK';
resp_len = 0;

// 1. Which mode? Default to MOCK when the config row is missing.
exec sql
  SELECT APIMODE, BASEURL INTO :wMode, :wBase
    FROM APICFG
    FETCH FIRST 1 ROW ONLY;
if SQLSTATE <> '00000';
  wMode = 'MOCK';
endif;
wUrl = %trim(wBase) + %trim(zip);

if wMode = 'REAL';
  // 2a. Real path: one HTTP GET. Empty string = no options.
  exec sql
    SELECT QSYS2.HTTP_GET(CAST(:wUrl AS VARCHAR(200)), '')
      INTO :resp
      FROM SYSIBM.SYSDUMMY1;
  wSqlst = SQLSTATE;
  if wSqlst = '00000' or wSqlst = '01004';
    wSt = 200;
  else;
    wSt = 0;
    rc = 'HTTPERR';
  endif;
else;
  // 2b. Mock path: canned response and status from APIMOCK.
  wUrl = 'mock:' + %trim(zip);
  exec sql
    SELECT HTTPST, BODY INTO :wSt, :resp
      FROM APIMOCK
      WHERE ZIP = :zip;
  wSqlst = SQLSTATE;
  if wSqlst = '02000';
    rc = 'NOMOCK';
    wSt = 0;
  elseif wSt >= 400 or wSt = 0;
    rc = 'HTTPERR';
  endif;
endif;

// 3. Log every call. resp_len is the length of the stored text.
exec sql
  INSERT INTO APILOG
    (APIMODE, ZIP, URL, RC, HTTPST, RESPLEN, SQLST, RESP)
  VALUES (:wMode, :zip, :wUrl, :rc, :wSt, :resp_len, :wSqlst, :resp);

*inlr = *on;
return;
