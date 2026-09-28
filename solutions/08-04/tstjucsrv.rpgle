**FREE
//=======================================================================
// TSTJUCSRV - TESTKIT-based test case for JUCSRV (Part 8, lesson
// 08-04). Runs the 10 cases listed in work/design/part08-design-v1.md
// section 2, 08-04, against JUCSRV's three exported procedures
// (src/qrpglesrc/jucsrv.rpgle: getCustName, countCustOrders,
// pingJucsrv - already CONFIRMED working on real hardware,
// part07-0203-srvpgm/part07-03-signature, docs/probes.md).
//
// STATUS: CONFIRMED (part08-04-testkit, 2026-09-28): all 12 assertions
// below PASS (design's case 9/10 each produce 2 assertions - see their
// own comments), matching db/data/load_v1.sql's real seed data exactly
// - see docs/probes.md's part08-04-testkit section for the full
// connection record. This exact file (without case 00 - see below) has
// not itself been separately recompiled since; the version actually
// compiled and run also carried one extra deliberately-failing case
// (00), used to confirm TESTKIT's own MONITOR/*ESCAPE mechanics work -
// moved out afterward (2026-09-28) to
// verify/part08-04-testkit/src/tstjucsrv-faildemo.rpgle so this shipped
// solution stays a clean, all-passing artifact a learner could actually
// copy. Removing case 00 changes nothing about cases 01-10B below - see
// that file's own header for the full record of what case 00 itself
// confirmed.
//
// EXPECTED VALUES (design doc's own citation): db/data/load_v1.sql's
// real seed data - TOKUIM C00001='ACME TRADING CO'/C00002='NORTH STAR
// LTD'; JUCHUM J00001/J00003 -> C00001, J00002 -> C00002,
// J00004/J00008 -> C00003. This file does not re-derive those numbers;
// it takes them as given from the design doc, which cites
// db/data/load_v1.sql directly.
//
// WHY EACH ASSERTION IS WRAPPED IN ITS OWN MONITOR/ON-ERROR: per
// src/qrpglesrc/testkit.sqlrpgle's header, a failed assertEquals*/
// assertTrue call raises an *ESCAPE targeted at ITS caller (this
// program) before returning. Without MONITOR, the FIRST failure would
// abort this whole test case, leaving the remaining 9 cases unrun and
// TESTRES incomplete. Each call below is wrapped individually so one
// failing case cannot hide the results of the others - the ON-ERROR
// block is intentionally empty (the failure is already logged into
// TESTRES by the time the *ESCAPE fires; there is nothing more to do
// here except let execution continue to the next case).
//
// Cases 9-10 are NOT independent assertions of their own - they are
// ordering/repetition checks built from the SAME assertEqualsNum/
// assertEqualsChar calls used for cases 1-7, just called a second time
// or in a different order, specifically to exercise jucsrv.rpgle's own
// "JUCHUM repositioning" fix (see that file's header): countCustOrders
// closes/reopens JUCHUM on every call precisely so a second call in the
// same activation group does not silently see JUCHUM already at EOF.
//
// BUILD RECIPE: JUCSRV must already exist (part07-0203-srvpgm) and
// TESTKIT must already exist (see src/qrpglesrc/testkit.sqlrpgle) before
// this program is built. A NEW binding directory, TESTKITBD, is needed
// alongside the already-existing JUCSRVBD (07-02's own choice, see
// src/qrpglesrc/jucsrv.rpgle's header) - same reasoning
// solutions/07-05/driver.rpgle's own header gives for creating a
// dedicated ZAISRVBD rather than reusing JUCSRVBD for an unrelated
// service program:
//     CRTBNDDIR BNDDIR(<lib>/TESTKITBD)
//     ADDBNDDIRE BNDDIR(<lib>/TESTKITBD) OBJ((*LIBL/TESTKIT *SRVPGM))
//     CRTBNDRPG PGM(<lib>/TSTJUCSRV) SRCFILE(<lib>/QRPGLESRC)
//       SRCMBR(TSTJUCSRV) DFTACTGRP(*NO) ACTGRP(*NEW)
//       BNDDIR((*LIBL/JUCSRVBD) (*LIBL/TESTKITBD))
//
// ACTGRP(*NEW): a fresh, private, system-named activation group, same
// convention as solutions/07-05/driver.rpgle (dftactgrp(*no)
// actgrp(*new)) - both JUCSRV and TESTKIT are ACTGRP(*CALLER), so both
// activate into THIS program's one activation-group instance for the
// whole run, which is exactly what case 9 below needs (see
// driver.rpgle's own "ACTIVATION GROUP DESIGN" header note for the
// full citation trail on why this must all happen inside one
// execution, not split across two CALLs).
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

//-----------------------------------------------------------------------
// Prototypes for JUCSRV's three exported procedures. EXTPROC(*DCLCASE)
// matches jucsrv.rpgle's own dcl-pi keyword exactly (see that file's
// header for why *DCLCASE, not a bare EXTPROC, is required here).
//-----------------------------------------------------------------------
dcl-pr getCustName char(30) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-pr countCustOrders zoned(5:0) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-pr pingJucsrv ind extproc(*dclcase);
end-pr;

//-----------------------------------------------------------------------
// Prototypes for TESTKIT's four exported procedures - see
// src/qrpglesrc/testkit.sqlrpgle for the implementation.
//-----------------------------------------------------------------------
dcl-pr testInit extproc(*dclcase);
end-pr;

dcl-pr assertEqualsChar extproc(*dclcase);
  testName char(30) const;
  expected char(30) const;
  actual   char(30) const;
end-pr;

dcl-pr assertEqualsNum extproc(*dclcase);
  testName char(30) const;
  expected packed(15:5) const;
  actual   packed(15:5) const;
end-pr;

dcl-pr assertTrue extproc(*dclcase);
  testName char(30) const;
  actual   ind const;
end-pr;

testInit();

// --- 1-3: getCustName ---------------------------------------------
monitor;
  assertEqualsChar('01-GETNAME-C00001' : 'ACME TRADING CO'
    : getCustName('C00001'));
on-error;
endmon;

monitor;
  assertEqualsChar('02-GETNAME-C00002' : 'NORTH STAR LTD'
    : getCustName('C00002'));
on-error;
endmon;

monitor;
  assertEqualsChar('03-GETNAME-NOTFOUND' : 'NOTFOUND'
    : getCustName('Z99999'));
on-error;
endmon;

// --- 4-7: countCustOrders -------------------------------------------
monitor;
  assertEqualsNum('04-CNT-C00001' : 2 : countCustOrders('C00001'));
on-error;
endmon;

monitor;
  assertEqualsNum('05-CNT-C00002' : 1 : countCustOrders('C00002'));
on-error;
endmon;

monitor;
  assertEqualsNum('06-CNT-C00003' : 2 : countCustOrders('C00003'));
on-error;
endmon;

monitor;
  assertEqualsNum('07-CNT-NOTFOUND' : 0 : countCustOrders('Z99999'));
on-error;
endmon;

// --- 8: pingJucsrv ---------------------------------------------------
monitor;
  assertTrue('08-PING' : pingJucsrv());
on-error;
endmon;

// --- 9: countCustOrders called TWICE in a row, same activation group -
// See jucsrv.rpgle's own header, "JUCHUM repositioning": without the
// close/open fix, this SECOND call would see JUCHUM already at EOF
// (left there by case 4's own call above) and silently return 0
// instead of 2.
//-----------------------------------------------------------------------
monitor;
  assertEqualsNum('09-CNT-TWICE-A' : 2 : countCustOrders('C00001'));
on-error;
endmon;

monitor;
  assertEqualsNum('09-CNT-TWICE-B' : 2 : countCustOrders('C00001'));
on-error;
endmon;

// --- 10: call-order swap (getCustName then countCustOrders) ---------
// TOKUIM (CHAIN-only) and JUCHUM (sequential READ) are separate files
// with separate access patterns - this case confirms interleaving a
// getCustName call between two countCustOrders calls does not disturb
// either file's own state.
//-----------------------------------------------------------------------
monitor;
  assertEqualsChar('10A-GETNAME-C00002' : 'NORTH STAR LTD'
    : getCustName('C00002'));
on-error;
endmon;

monitor;
  assertEqualsNum('10B-CNT-C00002' : 1 : countCustOrders('C00002'));
on-error;
endmon;

*inlr = *on;
return;
