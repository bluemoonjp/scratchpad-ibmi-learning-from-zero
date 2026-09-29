solutions/10-03 - lesson 10-03 (Capstone C and D)
==================================================

STATUS: UNVERIFIED (2026-09-30). The verify batch part10-03-modernize
has not run yet. Do not look at the model answer before you have tried
the skeleton.

Files
-----
za0500s-skeleton.sqlrpgle  starting point for Capstone C (TODO markers,
                           no answer logic)
za0500s.sqlrpgle           model answer: program ZA0500, SQL free-form,
                           two-cursor merge, unlocked peek with get(),
                           reserve() only for '*LIVE' after the margin
                           test passes, no lock leak
tstza0500.rpgle            TESTKIT test case for the new ZA0500 (15
                           assertions, ZAIKOM isolated in QTEMP by
                           RUNTEST)
runtest.clp                RUNTEST: one command, one job, runs
                           TSTJUCSRV, TSTZAISRV, TSTZA0500 and prints
                           PASS and FAIL counts
Rules.mk                   makei rules for a flat clone: ZAISRV and ZA0500
                           (module route; see the NOTE in the file about
                           ctl-opt dftactgrp/actgrp, UNVERIFIED)

Build order (library list: your work library first)
---------------------------------------------------
1. Back up the legacy program first:
     CRTDUPOBJ OBJ(ZA0500) FROMLIB(<work lib>) OBJTYPE(*PGM)
       TOLIB(<backup lib>) NEWOBJ(ZA0ORIG)
2. ZAISRV, ZAISRVBD, TESTKIT, TESTKITBD, JUCSRV, JUCSRVBD must exist in
   the work library (Parts 7 and 8).
3. Build ZA0500 (the source carries ctl-opt bnddir('ZAISRVBD'); CRTSQLRPGI
   has no ACTGRP or BNDDIR keyword):
     CRTSQLRPGI OBJ(<work lib>/ZA0500) SRCFILE(<work lib>/QRPGLESRC)
       SRCMBR(ZA0500) OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)
   From a git checkout (stream file, UTF-8) the design used SRCSTMF plus
   TGTCCSID(*JOB) and BNDDIR on the command line. The command reference
   lists CVTCCSID(*JOB) for the conversion and no such TGTCCSID or BNDDIR
   keyword for CRTSQLRPGI; the batch tries all spellings and records the
   result (UNVERIFIED until it runs).
4. Build TSTZA0500 and RUNTEST:
     CRTBNDRPG PGM(<work lib>/TSTZA0500) SRCFILE(<work lib>/QRPGLESRC)
       SRCMBR(TSTZA0500) DFTACTGRP(*NO) ACTGRP(*NEW)
       BNDDIR((*LIBL/ZAISRVBD) (*LIBL/TESTKITBD))
     CRTCLPGM PGM(<work lib>/RUNTEST) SRCFILE(<work lib>/QCLSRC)
       SRCMBR(RUNTEST)
5. RUNTEST LIB(<work lib>) is not a command; call it:
     CALL PGM(<work lib>/RUNTEST) PARM('<work lib>')
   Read the message: RUNTEST: PASS=0000000038 FAIL=0000000000 (ten
   digits, zero padded). FAIL must be 0.

Run modes (important)
---------------------
Every call of JU0900C must give the run mode:
  CALL PGM(JU0900C) PARM('*TEST' '<work lib>')
A bare call runs '*LIVE' and reduces stock. '*TEST' never touches ZAIKOM.
For a stock comparison with the legacy program use a separate '*LIVE'
pass with TXRESET before and after each run.

Rollback
--------
  DLTPGM PGM(<work lib>/ZA0500)
  CRTDUPOBJ OBJ(ZA0ORIG) FROMLIB(<backup lib>) OBJTYPE(*PGM)
    TOLIB(<work lib>) NEWOBJ(ZA0500)
(CRTDUPOBJ has no REPLACE, so delete first.)

Lint (not automated in this repo)
---------------------------------
rpglint (@halcyontech/rpglint, templates/part08-project/.vscode/
rpglint.json) runs on the learner machine only. The repo CI does not run
it. The expected first result on the shipped solutions is a list of
PrettyComments findings for comments written as //text without a space
(jucsrv, testkit, q0614s, q0805bs): fix them as an exercise. The sources
in this directory use "// " with a space.
