-- 05-07: impact analysis for a change to JUCHUM (or ZAIKOM - see docs/part05/05-07-impact-analysis.md).
-- Run in the SAME job as the DSPPGMREF/DSPDBR commands below (QTEMP is job-scoped).
--
-- UNVERIFIED FIELD NAMES: WHPGM/WHLIB/WHFILE/WHFLIB below are the commonly
-- documented DSPPGMREF *OUTFILE field names, but (like tools/qclsrc/txmigr.clp's
-- own DSPDBR/DSPOBJD field names) they have not been confirmed against a real
-- OUTFILE dump on PUB400 in this session. If DCLF-style field access fails to
-- compile or the SELECT below errors with "column not found", run
-- `DSPPGMREF PGM(<自分のライブラリー>/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)`
-- once, then `SELECT * FROM QTEMP.PGMREF FETCH FIRST 1 ROW ONLY` to see the
-- real column names, and fix this script before relying on it (same "verify
-- before relying on this source" rule the rest of this part follows).

-- Step 1 (run once per investigation, via CL or "Run SQL Scripts" *SHELL):
--   DSPPGMREF PGM(<自分のライブラリー>/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)
--   DSPDBR FILE(<自分のライブラリー>/JUCHUM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/DBRJUCHUM)

-- Step 2: which of MY OWN programs reference JUCHUM directly?
-- (Filtered to my own library, per this repo's rule: never scan other users'
-- objects/jobs - QTEMP.PGMREF only ever contains what step 1's PGM(...) scoped
-- to my own library produced anyway, but the WHERE keeps the intent explicit.)
SELECT WHPGM, WHLIB, WHFILE, WHFLIB
  FROM QTEMP.PGMREF
 WHERE WHFILE = 'JUCHUM'
 ORDER BY WHPGM;

-- Step 3: which logical files are built over JUCHUM (DSPDBR's own report)?
SELECT WHFILE, WHLIB
  FROM QTEMP.DBRJUCHUM
 ORDER BY WHFILE;

-- Step 4: CL programs that DCLF JUCHUM are NOT visible to DSPPGMREF (DCLF is a
-- CL-only, source-level dependency - see tools/qclsrc/txmigr.clp's own header
-- comment on JUYAKC's CPYTOIMPF FROMFILE() reference for the same class of
-- gap). Find them the same way FNDSTRPDM would, but from your own source
-- files via the IFS text search this session already uses elsewhere
-- (05-02's FNDSTRPDM lesson): search src/legacy/qclsrc/*.clp for "DCLF" and
-- "JUCHUM" together. There is no SQL-only substitute for this step.
