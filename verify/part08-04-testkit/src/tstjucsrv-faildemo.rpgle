**FREE
//=======================================================================
// TSTJUCSRV-FAILDEMO - verify-only variant of solutions/08-04/
// tstjucsrv.rpgle, with ONE addition: case 00, a deliberately-wrong
// assertion. Same pattern as verify/part06-1314-sql/src/q0613v.sqlrpgle
// (Q0613V, a verify-only variant of q0613s.sqlrpgle with one line
// different) - NOT a curriculum artifact; a learner never sees this
// file. Compiled AS TSTJUCSRV by this batch's own manifest, so it is
// what actually ran in the part08-04-testkit connections. Case 00 was
// originally written directly into solutions/08-04/tstjucsrv.rpgle for
// the 1st and 2nd connections, then moved here afterward (2026-09-28)
// so the shipped solution stays a clean, all-passing artifact a
// learner could actually copy - see that file's own header for why.
//
// PURPOSE: case 00 is what actually let this connection observe
// TESTKIT's FAIL/*ESCAPE path at all. Every one of the design doc's
// real 10 cases (01-10B below) is expected to PASS if JUCSRV/TESTKIT
// both work correctly, so without a guaranteed-wrong assertion,
// TESTKIT's MONITOR/callStackCtr mechanics (src/qrpglesrc/
// testkit.sqlrpgle's own "WHY VOID, NOT ind" header note) would never
// run on the first connection that compiles any of this.
//
// STATUS: CONFIRMED (part08-04-testkit, 2nd connection, 2026-09-28):
// case 00 logged RESULT='FAIL' (EXPECTED=999, ACTUAL=2) and ALL 12
// real assertions below (cases 01-10B) still logged their own PASS
// rows afterward in the SAME run - direct proof that MONITOR lets
// execution continue past a failed assertion to the next statement,
// exactly as testkit.sqlrpgle's design assumes. See docs/probes.md's
// part08-04-testkit section for the full connection record.
//
// See solutions/08-04/tstjucsrv.rpgle for everything else (the real
// 10 cases' own header comments, the build recipe, the activation-
// group reasoning) - not repeated here.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-pr getCustName char(30) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-pr countCustOrders zoned(5:0) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-pr pingJucsrv ind extproc(*dclcase);
end-pr;

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

// --- 00: DELIBERATELY WRONG expected value - verify-only, see header.
//-----------------------------------------------------------------------
monitor;
  assertEqualsNum('00-DELIBERATE-FAIL-DEMO' : 999 : countCustOrders('C00001'));
on-error;
endmon;

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
