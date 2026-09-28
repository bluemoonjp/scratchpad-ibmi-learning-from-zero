**FREE
//=======================================================================
// TESTKIT - a small, self-written test-assertion *SRVPGM (Part 8,
// lesson 08-04). NOT RPGUnit (this repo has no RPGUnit installed or
// confirmed - see work/design/part08-design-v1.md section 2, 08-04:
// RPGUnit is "introduced but not adopted"). TESTKIT demonstrates the SAME idea
// RPGUnit is built on - an assertion that logs its result and raises an
// exception on failure, so a caller can either let a failure abort the
// run (no MONITOR) or catch it and continue to the next assertion (with
// MONITOR/ON-ERROR) - using only techniques this curriculum has already
// confirmed on real hardware: embedded SQL (06-13/06-14,
// src/qrpglesrc/q0613s.sqlrpgle) and QMHSNDPM (06-09,
// src/qrpglesrc/f0609s.rpgle).
//
// DEVIATION FROM work/design/part08-design-v1.md's file list, FLAGGED:
// that design lists this file as "src/qrpglesrc/testkit.rpgle" (plain
// RPGLE, not embedded SQL). This file is .sqlrpgle (CRTSQLRPGI,
// embedded SQL) instead, for one concrete reason: TESTKIT needs to
// INSERT rows into a TESTRES table from inside RPG, and the only two
// candidate techniques for doing that from **FREE RPG are (a) embedded
// SQL (EXEC SQL INSERT ...), already hardware-confirmed in this repo
// (q0613s.sqlrpgle, part06-1314-sql), or (b) QCMDEXC calling the CL
// command RUNSQL. (b) is NOT a safe default here: this repo already
// found ONE QCMDEXC restriction the hard way (SNDPGMMSG cannot run via
// QCMDEXC from any HLL at any call depth - CPF0031, see
// src/qrpglesrc/f0605bs.rpgle's own header and docs/probes.md's
// part07-01-modules section) precisely because it looked plausible and
// was not checked against IBM's own "Where allowed to run" restriction
// first. Whether RUNSQL is similarly restricted is NOT confirmed
// anywhere in this repo's primary-source corpus (work/design/refs/ has
// no RUNSQL "where allowed to run" table), so betting TESTKIT's whole
// logging mechanism on an unverified QCMDEXC+RUNSQL combination would
// repeat exactly the mistake that already bit this repo once. Embedded
// SQL has no such open question - CRTSQLRPGI's own OBJTYPE parameter
// explicitly supports *MODULE (rzajp75.txt, cl_commands_75.txt, same
// citation q0613s.sqlrpgle already gives), so this NOMAIN module can
// still be precompiled with CRTSQLRPGI and then bound into a *SRVPGM
// with CRTSRVPGM exactly like an ordinary CRTRPGMOD'd module.
//
// BUILD RECIPE (two-step, same shape as JUCSRV/ZAISRV -
// src/qrpglesrc/jucsrv.rpgle / solutions/07-05/zaisrv.rpgle):
//     CRTSQLRPGI OBJTYPE(*MODULE) OBJ(<lib>/TESTKIT)
//       SRCFILE(<lib>/QRPGLESRC) SRCMBR(TESTKIT)
//       COMMIT(*NONE) CLOSQLCSR(*ENDMOD)
//     CRTSRVPGM SRVPGM(<lib>/TESTKIT) MODULE(<lib>/TESTKIT)
//       EXPORT(*SRCFILE) SRCFILE(<lib>/QSRVSRC) SRCMBR(TESTKIT)
//       ACTGRP(*CALLER)
// (See src/qsrvsrc/testkit.bnd for the binder source. ACTGRP(*CALLER)
// matches ZAISRV's own reasoning - a test-assertion library should run
// in whichever activation group the test CASE program chose, not force
// one of its own.)
//
// PROCEDURES (all VOID - see "WHY VOID, NOT ind" below):
//   testInit()
//   assertEqualsChar(testName: char(30) const,
//                     expected: char(30) const,
//                     actual:   char(30) const)
//   assertEqualsNum(testName: char(30) const,
//                    expected: packed(15:5) const,
//                    actual:   packed(15:5) const)
//   assertTrue(testName: char(30) const, actual: ind const)
//
// assertEqualsNum takes packed(15:5), wide enough to hold any of this
// curriculum's numeric return types (JUCSRV's countCustOrders is
// zoned(5:0), ZAISRV's get/reserve/release use packed(7:0)) - a CONST
// parameter lets the compiler convert any narrower numeric argument at
// the call site automatically, so one procedure covers every numeric
// case tested in this lesson instead of one per source type.
//
// TESTRES (the result table, created by testInit() below - not shipped
// as a separate .sql file, since work/design/part08-design-v1.md's own
// file list for 08-04 has none):
//   SEQ      INT              row order (GENERATED ALWAYS AS IDENTITY)
//   TESTNM   VARCHAR(30)      the testName argument, as given
//   EXPECTED VARCHAR(30)      expected value, formatted as text
//   ACTUAL   VARCHAR(30)      actual value, formatted as text
//   RESULT   VARCHAR(4)       'PASS' or 'FAIL'
//
// WHY VOID, NOT ind: an earlier draft of this file had every assert
// procedure RETURN an ind (pass/fail), on the assumption a caller might
// want to branch on it directly. Dropped because it invites a race
// against the *ESCAPE mechanism below: on failure, this procedure sends
// an *ESCAPE message targeted at its OWN caller (callStackCtr 1) before
// it returns - per the primary-source worked example this pattern is
// built on (ilerpgref75.txt lines 13744-13773, "Procedure to send an
// exception", QMHSNDPM call quoted verbatim in sendException() there),
// an unhandled *ESCAPE aimed at the caller's call level activates once
// control actually returns there, before that caller's own next
// statement runs - so a caller that reads this procedure's return value
// on the failure path would, in the unwrapped (no MONITOR) case, never
// actually reach the statement that reads it. Rather than design around
// an interaction this repo has not yet run on real hardware, this file
// drops the return value entirely: PASS is "execution continued past
// this call", FAIL is "an escape condition interrupted the caller
// (unless it wrapped the call in MONITOR/ON-ERROR, in which case it
// catches the escape and can inspect TESTRES for what failed)". This
// exact interaction (does execution actually reach a caller's next
// statement on the *ESCAPE path, or does the caller need MONITOR even
// to see its OWN following line skipped) is flagged as the single
// biggest unconfirmed assumption in this file - the 08-04 verify
// manifest's very first cases should include one deliberately-failing
// assertion, wrapped in MONITOR, specifically to observe this.
//
// callStackCtr 1 (not 0): ilerpgref75.txt's own sendException() example
// takes this as a caller-supplied parameter (stackOffsetToRpg) rather
// than hardcoding it, because the right value depends on how many
// procedure calls sit between the QMHSNDPM call itself and the call
// level that should receive the escape. Every assert procedure below
// calls QMHSNDPM directly (no extra local helper in between), so
// offset 0 would target the assert procedure's OWN call level (compare
// src/qrpglesrc/f0609s.rpgle's sendToJobLog, which uses '*' : 0 for
// exactly that reason - it wants the message to land on ITSELF, since
// it sends *INFO, not *ESCAPE) and offset 1 targets whatever called
// THIS procedure - the test-case code in TSTJUCSRV/TSTZAISRV, which is
// what should receive the exception. Confirmed by inspection only (this
// file has not yet been compiled or run) - flagged alongside the WHY
// VOID note above as something the first 08-04 connection must settle.
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt nomain;

//-----------------------------------------------------------------------
// QMHSNDPM plumbing - identical shape to src/qrpglesrc/f0609s.rpgle's
// own qmhsndpmMsgFile/qmhsndpmErrCode/qmhsndpm declarations (copied,
// not reinvented - see that file's header for the ilerpgref75.txt
// citation, lines 13744-13773).
//-----------------------------------------------------------------------
dcl-ds qmhsndpmMsgFile qualified template;
  *n char(10) inz('QCPFMSG');
  *n char(10) inz('*LIBL');
end-ds;

dcl-ds qmhsndpmErrCode template;
  bytesProvided int(10) inz(0);
  bytesAvailable int(10);
  msgId char(7);
  *n char(1);
end-ds;

dcl-pr qmhsndpm extpgm;
  msgId          char(7) const;
  msgFile        likeds(qmhsndpmMsgFile) const;
  msgData        char(1000) const;
  dataLen        int(10) const;
  msgType        char(10) const;
  callStackEntry char(10) const;
  callStackCtr   int(10) const;
  msgKey         char(4) const;
  errorCode      likeds(qmhsndpmErrCode);
end-pr;

// SET OPTION placed here, after every module-level D-spec above (the
// qmhsndpmMsgFile/qmhsndpmErrCode/qmhsndpm declarations) and before the
// first procedure - see src/qrpglesrc/q0613s.sqlrpgle's own header for
// why: "All Definition specifications ... must appear before the first
// Calculation specification" (ilerpgref75.txt, "Order of
// Specifications"), and SET OPTION itself "compiles down to C-spec-
// equivalent code" (same file's header). UNCONFIRMED: q0613s.sqlrpgle's
// own file has a single cycle-main mainline, not a NOMAIN module with
// multiple dcl-proc blocks - whether a module-level SET OPTION is even
// valid sitting here, outside every dcl-proc, in a NOMAIN module has
// not been checked against any primary source in this repo. This is
// the placement most consistent with the one rule this repo HAS
// confirmed (D-specs before the first C-spec); the first 08-04
// connection settles whether it is also sufficient on its own.
exec sql SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;

//=======================================================================
// testInit - ensure TESTRES exists (idempotent: a real CREATE TABLE is
// attempted every call, and SQLSTATE 42710 "object already exists" is
// the one error this procedure tolerates - see below), then DELETE all
// existing rows so each test run starts from an empty table. Call this
// ONCE at the start of a test-case program's mainline, before any
// assertEquals*/assertTrue call.
//=======================================================================
dcl-proc testInit export;
  dcl-pi *n extproc(*dclcase);
  end-pi;

  exec sql
    CREATE TABLE TESTRES (
      SEQ      INT GENERATED ALWAYS AS IDENTITY,
      TESTNM   VARCHAR(30),
      EXPECTED VARCHAR(30),
      ACTUAL   VARCHAR(30),
      RESULT   VARCHAR(4),
      PRIMARY KEY (SEQ)
    );
  // SQLSTATE 42710 = "already exists" (same tolerated-failure idea as
  // verify/lib/clgen.mjs's own ensure-log-table step, which likewise
  // attempts CREATE TABLE every run and ignores the already-exists
  // case rather than checking for the object first). Any OTHER
  // SQLSTATE here is a real problem this procedure has no way to
  // report (TESTRES itself may not exist yet), so it is not checked
  // further - a caller whose testInit() silently did nothing useful
  // will find out from the very next assertEquals*/assertTrue call,
  // whose own INSERT would then fail loudly instead.

  exec sql DELETE FROM TESTRES;

  return;
end-proc;

//=======================================================================
// logResult - shared helper (NOT exported): inserts one row into
// TESTRES. Called by every assertEquals*/assertTrue procedure below, so
// the INSERT statement and its column list are written exactly once.
//=======================================================================
dcl-proc logResult;
  dcl-pi *n;
    testName char(30) const;
    expected char(30) const;
    actual   char(30) const;
    passed   ind const;
  end-pi;

  dcl-s result varchar(4);

  if passed;
    result = 'PASS';
  else;
    result = 'FAIL';
  endif;

  exec sql
    INSERT INTO TESTRES (TESTNM, EXPECTED, ACTUAL, RESULT)
      VALUES (:testName, :expected, :actual, :result);

  return;
end-proc;

//=======================================================================
// raiseFail - shared helper (NOT exported): sends the *ESCAPE message
// described in this file's header ("callStackCtr 1"). Called only from
// inside an assertEquals*/assertTrue procedure's own body (never
// through any deeper helper), so callStackCtr 1 always means "whatever
// called the assert procedure" - see the header note for why this
// would need to change if a future edit adds another layer of call
// indirection.
//=======================================================================
dcl-proc raiseFail;
  dcl-pi *n;
    testName char(30) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);
  dcl-s  msgText char(200);

  msgText = 'TESTKIT: assertion failed - ' + %trimr(testName);

  qmhsndpm('CPF9898' : msgFile : msgText : %len(%trimr(msgText))
             : '*ESCAPE' : '*' : 1 : msgKey : errCode);

  return;
end-proc;

//=======================================================================
// assertEqualsChar - compares two char(30) values.
//=======================================================================
dcl-proc assertEqualsChar export;
  dcl-pi *n extproc(*dclcase);
    testName char(30) const;
    expected char(30) const;
    actual   char(30) const;
  end-pi;

  if expected = actual;
    logResult(testName : expected : actual : *on);
  else;
    logResult(testName : expected : actual : *off);
    raiseFail(testName);
  endif;

  return;
end-proc;

//=======================================================================
// assertEqualsNum - compares two numeric values. packed(15:5) is wide
// enough to hold zoned(5:0) (countCustOrders) and packed(7:0)
// (ZAISRV's get/reserve/release, via a CONST-parameter implicit
// conversion at the call site) without a separate procedure per type -
// see the header note "assertEqualsNum takes packed(15:5)".
//=======================================================================
dcl-proc assertEqualsNum export;
  dcl-pi *n extproc(*dclcase);
    testName char(30) const;
    expected packed(15:5) const;
    actual   packed(15:5) const;
  end-pi;

  dcl-s expectedTxt char(30);
  dcl-s actualTxt   char(30);

  expectedTxt = %char(expected);
  actualTxt   = %char(actual);

  if expected = actual;
    logResult(testName : expectedTxt : actualTxt : *on);
  else;
    logResult(testName : expectedTxt : actualTxt : *off);
    raiseFail(testName);
  endif;

  return;
end-proc;

//=======================================================================
// assertTrue - checks a single indicator is *on. Expected/actual in
// TESTRES are recorded as 'Y'/'N' text for readability.
//=======================================================================
dcl-proc assertTrue export;
  dcl-pi *n extproc(*dclcase);
    testName char(30) const;
    actual   ind const;
  end-pi;

  dcl-s actualTxt char(30);

  if actual;
    actualTxt = 'Y';
    logResult(testName : 'Y' : actualTxt : *on);
  else;
    actualTxt = 'N';
    logResult(testName : 'Y' : actualTxt : *off);
    raiseFail(testName);
  endif;

  return;
end-proc;
