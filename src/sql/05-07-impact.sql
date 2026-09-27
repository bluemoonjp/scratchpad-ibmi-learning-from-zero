-- 05-07: impact analysis for a change to JUCHUM (or ZAIKOM - see docs/part05/05-07-impact-analysis.md).
-- Run in the SAME job as the DSPPGMREF/DSPDBR commands below (QTEMP is job-scoped).
--
-- UNVERIFIED FIELD NAMES: WHPGM/WHLIB/WHFILE/WHFLIB below are the commonly
-- documented DSPPGMREF *OUTFILE field names, but (like tools/qclsrc/txmigr.clp's
-- own DSPDBR/DSPOBJD field names) they have not been confirmed against a real
-- OUTFILE dump on PUB400 in this session. **Do not skip Step 0 below** - treat
-- the field names in Steps 2-5 as a best guess until Step 0 confirms them
-- (same "verify before relying on this source" rule the rest of this part
-- follows).

-- Step 0 (ALWAYS run this first, not just when something fails): inspect the
-- real outfile columns before trusting any WHxxx name below. txmigr.clp
-- already flags WHFILE/WHLIB and ODOBNM/ODOBAT as unconfirmed guesses; this
-- is the one query that turns the guess into a fact for your session.
--   DSPPGMREF PGM(<自分のライブラリー>/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)
--   DSPDBR FILE(<自分のライブラリー>/JUCHUM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/DBRJUCHUM)
--   SELECT * FROM QTEMP.PGMREF FETCH FIRST 1 ROW ONLY;
--   SELECT * FROM QTEMP.DBRJUCHUM FETCH FIRST 1 ROW ONLY;
-- If the column names below don't match what these two SELECTs actually
-- show, fix Steps 2-5 to match your real columns before relying on them.
-- Also note DSPDBR's own ambiguity (from txmigr.clp's header): it is
-- unconfirmed whether WHFILE/WHLIB name the DEPENDENT logical file or the
-- file DSPDBR was run AGAINST (JUCHUM itself) - Step 0's dump is what
-- resolves this for your own session, not this comment.

-- Step 1: which of MY OWN programs reference JUCHUM directly?
-- (Filtered to my own library, per this repo's rule: never scan other users'
-- objects/jobs - QTEMP.PGMREF only ever contains what Step 0's PGM(...) scoped
-- to my own library produced anyway, but the WHERE keeps the intent explicit.)
SELECT WHPGM, WHLIB, WHFILE, WHFLIB
  FROM QTEMP.PGMREF
 WHERE WHFILE = 'JUCHUM'
 ORDER BY WHPGM;

-- Step 2: which logical files are built over JUCHUM (DSPDBR's own report)?
SELECT WHFILE, WHLIB
  FROM QTEMP.DBRJUCHUM
 ORDER BY WHFILE;

-- Step 3: Step 1 only catches programs that reference JUCHUM BY NAME. A
-- program can depend on JUCHUM one hop removed, through a logical file, and
-- Step 1's WHERE WHFILE = 'JUCHUM' will miss it - this is not hypothetical,
-- it is exactly what happens with JU0300 (its F-spec names JUCHUL1, not
-- JUCHUM at all; see src/legacy/qrpgsrc/ju0300.rpg). For every logical file
-- Step 2 found, re-run Step 1's query with that file's name instead of
-- 'JUCHUM'. Example, once Step 2 has shown JUCHUL1:
SELECT WHPGM, WHLIB, WHFILE, WHFLIB
  FROM QTEMP.PGMREF
 WHERE WHFILE = 'JUCHUL1'
 ORDER BY WHPGM;
-- (repeat for any other logical file Step 2 lists, one WHERE value per file)

-- Step 4: does DSPPGMREF even see a CL program's DCLF? Unlike a runtime
-- command-parameter string (see the note below), DCLF is a compile-time
-- binding - a CL program that DCLFs a file performs a level check against
-- it, which means the compiler must store a reference to that file in the
-- program object. That makes it PLAUSIBLE DSPPGMREF reports it just like an
-- RPG F-spec would, but this repo has not confirmed it against a real
-- OUTFILE dump. Check it directly with solutions/03-09/jucinqc.clp
-- (DCLF FILE(JUCHUM) + RCVF, and nothing else that touches JUCHUM - a
-- cleaner test subject than JU0900C, which also has OVRDBF/DLTOVR lines
-- naming JUCHUM, even though those don't add a distinct dependency beyond
-- the same DCLF). JUCINQC lives in a different library (<USER>1) than this
-- part's legacy system (<USER>2), so re-run Step 1's query scoped to
-- <USER>1 to test it. If JUCINQC shows up, DCLF is visible here and Step 1
-- alone would have caught it. If not, treat DCLF as a real blind spot for
-- this tool and rely on FNDSTRPDM (Step 5) for it instead. Either way, do
-- Step 5 - it costs nothing extra and does not depend on the answer.

-- Step 5: FNDSTRPDM as an independent second check, regardless of what Step
-- 4 finds. Certain, structural blind spots for DSPPGMREF/DSPDBR-style
-- analysis are RUNTIME command-parameter strings, not compile-time bindings:
-- OPNQRYF, OVRDBF TOFILE(), CPYTOIMPF FROMFILE() (see tools/qclsrc/txmigr.clp's
-- own header comment on JUYAKC for this exact class of gap), and any
-- QCMDEXC-built command string. There is no SQL-only substitute for finding
-- these - search the source text directly:
--   FNDSTRPDM FILE(<自分のライブラリー>/QCLSRC) STRING('JUCHUM')
--   FNDSTRPDM FILE(<自分のライブラリー>/QRPGSRC) STRING('JUCHUM')
-- A hit inside a comment (not an operand) is a false positive - read the
-- line, don't just count matches. Also remember: source files a program was
-- compiled from can live in a DIFFERENT library than the compiled *PGM
-- itself (e.g. your own 03-09 JUCINQC, compiled in a different library than
-- this part's legacy system) - re-run both DSPPGMREF and FNDSTRPDM once per
-- library you actually have JUCHUM-touching source or objects in, not just
-- the one you are currently working in.
