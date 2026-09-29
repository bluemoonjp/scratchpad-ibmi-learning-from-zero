**FREE
// =====================================================================
// ZA0500 - lesson 10-03 SKELETON (starting point for Capstone C).
// Copy this file into your own work area, rename it, and fill in every
// TODO. The model answer is za0500s.sqlrpgle (do not open it first).
//
// Goal: replace the legacy ZA0500 (M1/MR cycle) with this program,
// same name, same parameters, same printed lines.
//
// Rules you must keep:
//   avail = stock - qty
//   avail < minqty  -> SHORT   (decided by an UNLOCKED read)
//   otherwise       -> OK, and only when rmode = '*LIVE' stock is
//                      reduced by qty
//   no ZAIKOM row   -> NOTFOUND
//   A dry run (rmode other than '*LIVE') must never touch ZAIKOM.
//   A SHORT line must never leave a lock behind.
//
// What is given: declarations, prototypes, the two cursors, and the
// two print helpers. What you write: the merge loop, the margin test,
// the reserve() call, and closing the cursors.
//
// STATUS: UNVERIFIED (2026-09-30).
// =====================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('ZAISRVBD');

dcl-f qsysprt printer(132) usage(*output);

// ZAISRV exports (07-05). EXTPROC names match zaisrv.bnd.
dcl-pr get packed(7:0) extproc('GET');
  prodCode char(6) const;
end-pr;

dcl-pr reserve ind extproc('RESERVE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

// TODO 1: check the entry parameters against the live JU0900C. They
//   must equal what it passes (length AND decimals). A mismatch is
//   the 05-13 ticket-1 bug again.
dcl-pi *n;
  rmode  char(10);
  minqty packed(5:0);
end-pi;

dcl-ds line len(132) end-ds;

dcl-s lJuno   char(6);
dcl-s lJuline packed(3:0);
dcl-s lJusho  char(6);
dcl-s lJusu   packed(5:0);
dcl-s hJuno   char(6);

dcl-s eof1 ind inz(*off);
dcl-s eof2 ind inz(*off);
dcl-s haveHeader ind inz(*off);

dcl-s stock  packed(7:0);
dcl-s avail  packed(7:0);
dcl-s okRes  ind;
dcl-s statusText char(8);

exec sql SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;

exec sql
  DECLARE C1 CURSOR FOR
    SELECT JUNO, JULINE, JUSHO, JUSU
      FROM JUCHUD
      ORDER BY JUNO, JULINE;

exec sql
  DECLARE C2 CURSOR FOR
    SELECT JUNO
      FROM JUCHUM
      ORDER BY JUNO;

exec sql OPEN C1;
exec sql OPEN C2;

// TODO 2: two-cursor merge (08-05b). C1 drives, one FETCH per line.
//   C2 only advances while its JUNO is smaller than the line's JUNO.
//   Call processLine() only for a line that has a matching header.
//   Watch the end-of-data test (SQLSTATE '02000') on both cursors.

// TODO 3: close both cursors.

*inlr = *on;
return;

// =====================================================================
// processLine - one matched order line.
// =====================================================================
dcl-proc processLine;
  dcl-pi *n;
  end-pi;

  // TODO 4: unlocked peek. get() returns -1 when the product is
  //   missing: print NOTFOUND and return.

  // TODO 5: margin test on the peeked value. Below the margin the
  //   status is SHORT and NOTHING is locked or changed.

  // TODO 6: margin passed: status OK. Only when rmode = '*LIVE' call
  //   reserve(). If reserve() answers *off, what should you print?
  //   (avail >= minqty >= 0 implies stock >= qty, so think about when
  //   it can still fail.)

  printLine();
end-proc;

// =====================================================================
// printLine - given. Columns match the legacy run text.
// =====================================================================
dcl-proc printLine;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:1:6)  = lJuno;
  %subst(line:9:6)  = lJusho;
  %subst(line:17:5) = zeroPad(lJusu:5);
  %subst(line:31 - %len(%trimr(statusText)):%len(%trimr(statusText)))
    = %trimr(statusText);
  write qsysprt line;
end-proc;

// =====================================================================
// zeroPad - given.
// =====================================================================
dcl-proc zeroPad;
  dcl-pi *n char(10);
    val   packed(15:0) const;
    width int(5) const;
  end-pi;

  dcl-s digits varchar(15);
  dcl-s zeros char(15) inz('000000000000000');
  dcl-s padded char(15);

  digits = %trimr(%char(val));
  padded = %subst(zeros:1:width - %len(digits)) + digits;
  return %subst(padded:1:width);
end-proc;
