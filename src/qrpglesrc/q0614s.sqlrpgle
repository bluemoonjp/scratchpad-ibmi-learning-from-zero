**FREE
//==================================================================
// Q0614A - Lesson 06-14: embedded SQL (2): cursor, multi-row FETCH,
//          PREPARE + a parameter marker (dynamic SQL).
//
// Business nickname (used only in the lesson text, never in code):
// JUCINQ4S. This program independently re-implements the order-
// inquiry logic of JUCINQ3 (see docs/part04/04-08-jucinq3-report.md)
// using SQL instead of native CHAIN/READ: given a customer code, it
// prints that customer's name (TOKUIM) and every order for that
// customer (JUCHUM), the same business rule R0408A (JUCINQ3) already
// implements natively and has verified on hardware (04-08 report:
// customer C00001 -> orders J00001/J00003).
//
// IMPORTANT: this program is NOT wired to the JUCINQ command. Lesson
// 06-12 already replaced JUCINQ's CPP with F0612A (business nickname
// JUCINQ4 for that PRTF-based rewrite; F0612A is the real object
// name, per work/design/part06-design-v1.md section 0.1 on
// nickname-vs-object-name and appendix E) -- that CPP slot is taken.
// Q0614A is a standalone, independent comparison example only ("how
// would you do the same lookup in SQL instead of native I/O"), run
// directly with CALL, never through the JUCINQ command.
//
// A static cursor with a host-variable WHERE clause (for example,
// "WHERE JUTOK = :wCustCode" with no PREPARE at all) would also have
// worked for this lookup. This program deliberately uses PREPARE and
// a parameter marker instead, because the point of lesson 06-14 is
// the dynamic-SQL technique itself, not just getting the answer.
//
// Output goes to QSYSPRT (program-described, no Output specifications
// -- see q0613s.sqlrpgle's header for the citation and reasoning),
// not DSPLY, so this program can also be run non-interactively (the
// verify/ harness in work/design/part06-design-v1.md section 5.1
// batch "part06-1314-sql" calls it over SSH).
//
// HARDWARE STATUS: UNTESTED as of 2026-09-26 (Part 6 is a draft
// branch; no probe or verify/ run has compiled this member yet).
// Compile with CRTSQLRPGI.
//
// Primary-source citations (see work/design/refs/):
//  - DECLARE CURSOR FOR a prepared statement, OPEN ... USING
//    (binding the parameter marker to a host variable at OPEN time),
//    and FETCH ... INTO in ILE RPG: rzajp75.txt, "Example: Dynamic
//    SQL in an ILE RPG application that uses SQL" (search that exact
//    heading). This program follows that example's structure
//    (PREPARE S1 FROM :stmt; DECLARE C1 CURSOR FOR S1; OPEN C1
//    USING :hostvar; FETCH C1 INTO ...; CLOSE C1;) almost verbatim,
//    changing only the statement text and adding the multi-row
//    FETCH loop.
//  - End-of-cursor / "not found" is SQLSTATE '02000' (SQLCODE +100):
//    rzajp75.txt, "Handling exception conditions with the WHENEVER
//    statement" (search "Specify NOT FOUND to indicate what you
//    want done when an SQLCODE of +100 or a SQLSTATE of '02000'").
//    This program checks SQLSTATE after each FETCH directly instead
//    of using a WHENEVER statement.
//  - Program-described printer file WRITE with a data structure and
//    no Output specifications: ilerpgref75.txt, "File Operations"
//    (search "The WRITE and UPDATE operations that specify a program
//    described file name in factor 2 must have a data structure name
//    specified in the result field").
//==================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

// All Definition specifications (D-specs) must appear before the
// first Calculation specification (C-spec); every "EXEC SQL ...;"
// statement below compiles down to C-spec-equivalent code. See
// ilerpgref75.txt, "Order of Specifications" (Table 99).
dcl-f qsysprt printer(132) usage(*output);

dcl-ds prtLine len(132);
  prtText char(132) pos(1);
end-ds;

dcl-s wCustCode char(6) inz('C00001');
dcl-s wCustName char(30);

dcl-s wStmt     varchar(200);
dcl-s wOrderNo  char(6);
dcl-s wOrderDt  zoned(8:0);

exec sql SET OPTION commit = *none, naming = *sys;

// --- 1. static SELECT INTO: look up the customer name -------------
// (Same technique as lesson 06-13; kept static here on purpose, to
// contrast with the dynamic lookup below.)
exec sql
  SELECT TOKNM INTO :wCustName
    FROM TOKUIM
    WHERE TOKCD = :wCustCode;

if SQLSTATE = '00000';
  prtText = 'Customer ' + %trim(wCustCode) + ': ' + %trim(wCustName);
else;
  wCustName = 'NOTFOUND';
  prtText = 'Customer ' + %trim(wCustCode) + ': ' + wCustName;
endif;
write qsysprt prtLine;

// --- 2. dynamic SQL: PREPARE + a parameter marker, DECLARE ---------
//        CURSOR, multi-row FETCH loop.
// The customer code is bound to the parameter marker at OPEN time
// (below), not hardcoded into the statement text, so the same
// prepared statement/cursor pair could be reused for any customer
// code.
wStmt = 'SELECT JUNO, JUDATE FROM JUCHUM'
      + ' WHERE JUTOK = ? ORDER BY JUNO';

exec sql PREPARE S1 FROM :wStmt;
exec sql DECLARE C1 CURSOR FOR S1;
exec sql OPEN C1 USING :wCustCode;

exec sql FETCH C1 INTO :wOrderNo, :wOrderDt;
dow SQLSTATE = '00000';
  prtText = '  Order ' + wOrderNo + ' dated ' + %char(wOrderDt);
  write qsysprt prtLine;
  exec sql FETCH C1 INTO :wOrderNo, :wOrderDt;
enddo;

// SQLSTATE '02000' (no more rows) ends the loop normally. Anything
// else left in SQLSTATE at this point would be a real error; this
// demo program does not check for that case separately (lesson
// 06-13 already covers SQLSTATE/GET DIAGNOSTICS error handling in
// depth).
exec sql CLOSE C1;

*inlr = *on;
return;
