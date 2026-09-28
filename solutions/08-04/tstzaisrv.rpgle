**FREE
//=======================================================================
// TSTZAISRV - TESTKIT-based test case for ZAISRV (Part 8, lesson
// 08-04). Runs the 5 boundary-value cases listed in
// work/design/part08-design-v1.md section 2, 08-04, against ZAISRV's
// three exported procedures (solutions/07-05/zaisrv.rpgle: get,
// reserve, release - already CONFIRMED working on real hardware,
// part07-05-checkpoint, docs/probes.md).
//
// ====================================================================
// UNLIKE driver.rpgle: THIS PROGRAM DOES NOT TOUCH THE SHARED ZAIKOM
// TABLE - it is QTEMP-ISOLATED by design (work/design/part08-design-v1.md
// section 2, 08-04, the adopted "QTEMP isolation design"), not by
// anything in this .rpgle file itself. ZAISRV's own internal
// "dcl-f zaikom disk usage(*update) keyed;" (solutions/07-05/zaisrv.rpgle)
// opens whatever object the name ZAIKOM resolves to at that moment; this
// program never overrides it itself. It is the 08-04 VERIFY MANIFEST's
// job to CRTDUPOBJ a QTEMP copy of ZAIKOM (seeded with a value this
// program's own get()/reserve()/release() calls could not otherwise
// have reached, so the resulting TESTRES rows themselves are evidence
// of which file ZAISRV actually opened) and OVRDBF ZAIKOM TOFILE(QTEMP/
// ZAIKOM) BEFORE calling this program, at the wrapper's own call level
// (ZAISRV is ACTGRP(*CALLER), so it activates into this program's own
// activation - the override needs to be in place before ZAISRV's
// module is first activated, not just before this program's mainline
// starts). If the manifest ever fails to set up that override, this
// program's calls fall through to the SAME shared ZAIKOM 04-13/06-07/
// 06-11b/06-15 all depend on - unlike driver.rpgle (07-05), which
// deliberately DOES mutate the shared table and requires
// <USER>2/TXRESET afterward, this program's own design intent is to
// never need TXRESET at all.
// ====================================================================
//
// EACH CASE RESTORES ITS OWN COPY OF ZAIKOM TO ITS OWN STARTING POINT
// BEFORE THE NEXT CASE BEGINS (unlike driver.rpgle, which runs its
// steps as one continuous net-zero sequence) - this keeps every case's
// own "current ZASU" reference (per the design doc's own case 1/2
// wording, "qty = the current ZASU" / "qty = the current ZASU + 1")
// meaningful on its own, independent of what an earlier case did,
// rather than chaining off whatever case 1 happened to leave behind.
// This restore discipline is unrelated to the QTEMP isolation above -
// it would matter even if this program DID run against the real,
// shared ZAIKOM.
//
// WHY EACH ASSERTION IS WRAPPED IN ITS OWN MONITOR/ON-ERROR: same
// reasoning as solutions/08-04/tstjucsrv.rpgle's own header - see that
// file for the full explanation of TESTKIT's *ESCAPE-on-failure design.
// Here it additionally protects the RESTORE step after each case (1C/
// 4C below) from being skipped by an earlier assertion failure in that
// same case - each restore call is its own statement, not gated behind
// the case's own assertions succeeding.
//
// BUILD RECIPE: ZAISRV must already exist (part07-05-checkpoint) and
// TESTKIT must already exist (see src/qrpglesrc/testkit.sqlrpgle)
// before this program is built. Reuses ZAISRVBD (already created by
// solutions/07-05/driver.rpgle's own build recipe) and TESTKITBD (new,
// shared with solutions/08-04/tstjucsrv.rpgle - see that file's header
// for the CRTBNDDIR/ADDBNDDIRE recipe, not repeated here):
//     CRTBNDRPG PGM(<lib>/TSTZAISRV) SRCFILE(<lib>/QRPGLESRC)
//       SRCMBR(TSTZAISRV) DFTACTGRP(*NO) ACTGRP(*NEW)
//       BNDDIR((*LIBL/ZAISRVBD) (*LIBL/TESTKITBD))
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

//-----------------------------------------------------------------------
// Prototypes for ZAISRV's three exported procedures. EXTPROC names
// match zaisrv.bnd's EXPORT SYMBOL entries exactly ('GET'/'RESERVE'/
// 'RELEASE') - same shape as solutions/07-05/driver.rpgle's own
// prototypes (copied from there, not reinvented).
//-----------------------------------------------------------------------
dcl-pr get packed(7:0) extproc('GET');
  prodCode char(6) const;
end-pr;

dcl-pr reserve ind extproc('RESERVE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

dcl-pr release ind extproc('RELEASE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

//-----------------------------------------------------------------------
// Prototypes for TESTKIT's four exported procedures - see
// src/qrpglesrc/testkit.sqlrpgle for the implementation.
//-----------------------------------------------------------------------
dcl-pr testInit extproc(*dclcase);
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

dcl-s prod     char(6) inz('P00001');   // same probe product as
                                         // driver.rpgle's own choice
dcl-s notFound char(6) inz('P99999');   // same NOTFOUND probe code as
                                         // driver.rpgle/04-09's exercise 2
dcl-s smallQty packed(7:0) inz(3);

dcl-s startQty packed(7:0);
dcl-s stockQty packed(7:0);
dcl-s stockQty2 packed(7:0);
dcl-s beforeQty packed(7:0);
dcl-s afterQty  packed(7:0);
dcl-s ok  ind;
dcl-s ok2 ind;

testInit();

// --- 1: reserve EXACTLY the current stock -> boundary SUCCESS -------
// zaisrv.rpgle's reserve() uses "zaikomRec.zasu < qty" (strict) for
// SHORT, so a qty EQUAL to the current stock does not trigger SHORT -
// this is the boundary the design doc's case 1 asks for.
//-----------------------------------------------------------------------
startQty = get(prod);

monitor;
  ok = reserve(prod : startQty);
  assertTrue('1-RESERVE-EXACT-OK' : ok);
on-error;
endmon;

monitor;
  stockQty = get(prod);
  assertEqualsNum('1B-STOCK-ZERO' : 0 : stockQty);
on-error;
endmon;

// Restore immediately, outside the assertion's own MONITOR block, so a
// failed assertion above cannot skip this cleanup.
ok = release(prod : startQty);

// --- 2: reserve current stock + 1 -> SHORT, stock unchanged ---------
stockQty = get(prod);   // re-peek; should equal startQty after restore

monitor;
  ok2 = reserve(prod : stockQty + 1);
  assertTrue('2-RESERVE-SHORT-OFF' : not ok2);
on-error;
endmon;

monitor;
  stockQty2 = get(prod);
  assertEqualsNum('2B-STOCK-UNCHANGED' : stockQty : stockQty2);
on-error;
endmon;

// --- 3: reserve a product code that does not exist -------------------
monitor;
  ok = reserve(notFound : 1);
  assertTrue('3-RESERVE-NOTFOUND-OFF' : not ok);
on-error;
endmon;

monitor;
  // get() distinguishes NOTFOUND (-1) from a real, insufficient ZASU -
  // see zaisrv.rpgle's own get() header for why -1 is a safe sentinel.
  assertEqualsNum('3B-GET-NOTFOUND' : -1 : get(notFound));
on-error;
endmon;

// --- 4: release gives QTY back -----------------------------------
beforeQty = get(prod);

monitor;
  ok = release(prod : smallQty);
  assertTrue('4-RELEASE-OK' : ok);
on-error;
endmon;

monitor;
  afterQty = get(prod);
  assertEqualsNum('4B-STOCK-INCREASED' : beforeQty + smallQty : afterQty);
on-error;
endmon;

// Restore immediately (release()'s own effect has no upper-bound check
// to fail on, so the restoring reserve() below is expected to succeed
// - see zaisrv.rpgle's release() header, "KNOWN LIMITATION", for why
// this restore step itself is never the thing under test here).
ok = reserve(prod : smallQty);

// --- 5: reserve/release round trip nets zero -------------------------
beforeQty = get(prod);

monitor;
  ok  = reserve(prod : smallQty);
  assertTrue('5A-RESERVE-OK' : ok);
on-error;
endmon;

monitor;
  ok2 = release(prod : smallQty);
  assertTrue('5B-RELEASE-OK' : ok2);
on-error;
endmon;

monitor;
  afterQty = get(prod);
  assertEqualsNum('5C-NET-ZERO' : beforeQty : afterQty);
on-error;
endmon;

*inlr = *on;
return;
