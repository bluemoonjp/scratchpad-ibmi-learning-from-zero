**FREE
// =====================================================================
// ZA0500 - lesson 10-03, Capstone C: the modernized stock allocation.
// MODEL ANSWER. The learner starts from za0500s-skeleton.sqlrpgle and
// writes the merge loop, the margin test and the reserve() call.
//
// This is the SQL free-form rewrite of the legacy ZA0500
// (src/legacy/qrpgsrc/za0500.rpg, M1/MR cycle), built from
// solutions/08-05/q0805bs.sqlrpgle (two-cursor merge) and composed
// with ZAISRV (solutions/07-05/zaisrv.rpgle: get / reserve).
// The program name is ZA0500 on purpose: JU0900C calls &LIB/ZA0500
// by name, so this object replaces the legacy program in place.
//
// STATUS: UNVERIFIED (2026-09-30). Nothing here has run on the
// hardware yet. verify/part10-03-modernize is the batch that will.
//
// ENTRY: rmode char(10), minqty packed(5:0). minqty MUST match the
// length and decimals JU0900C passes. After the 05-13 ticket-1 fix
// JU0900C declares &MINQTY as *DEC(5 0). Read the live JU0900C
// before you build (DSPPGMREF or the source); do not assume.
//
// BUSINESS RULE (same as legacy):
//   avail = stock - qty
//   avail < minqty  -> SHORT
//   otherwise       -> OK, and only when rmode = '*LIVE' stock is
//                      reduced by qty.
//   No ZAIKOM row   -> NOTFOUND
// Any rmode other than '*LIVE' is a dry run: ZAIKOM is never touched
// (JU0900C is run with '*TEST' for the golden master).
//
// DESIGN CHOICES (differences from Q0805B):
//   1. The margin test is an UNLOCKED peek: get() reads with no lock.
//      SHORT lines therefore never hold a lock.
//   2. reserve() is called only when the test has passed and rmode is
//      '*LIVE'. reserve() locks, re-checks and updates, and releases
//      its own lock on its SHORT branch (07-05). This program has no
//      lock of its own to leak. Q0805B inherited the legacy missing
//      UNLOCK; this program does not.
//   3. avail >= minqty >= 0 implies stock >= qty, so reserve() is
//      expected to return *on. If it returns *off anyway (another
//      job took the stock between the peek and the lock, or minqty
//      is negative), the line is reported SHORT.
//   4. ZAIKOM is reached only through ZAISRV. There is no dcl-f
//      for ZAIKOM here.
//
// UNVERIFIED: JU0900C opens JUCHUD with OVRDBF SHARE(*YES) and
// OPNQRYF. Whether the embedded SQL cursor below honors that is not
// established. Both cursors use ORDER BY, so the row order does not
// depend on the answer. If the batch shows the cursor cannot open,
// fall back to a native dcl-f on JUCHUD.
//
// BUILD (library list: your work library first; ZAISRVBD must be
// reachable, it is named in the ctl-opt line below). CRTSQLRPGI takes
// neither ACTGRP nor BNDDIR (CPD0043 for ACTGRP is on record and the
// command reference lists no BNDDIR): the ctl-opt line carries both.
// Default COMMIT(*CHG) fails, so give COMMIT(*NONE).
//   CRTSQLRPGI OBJ(<lib>/ZA0500) SRCFILE(<lib>/QRPGLESRC)
//     SRCMBR(ZA0500) OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)
// From a git checkout (UTF-8 stream file) the conversion keyword is
// CVTCCSID(*JOB) in the command reference; the design line with
// TGTCCSID(*JOB) is UNVERIFIED (the batch tries it and records it).
// Back up the legacy program first (CRTDUPOBJ to ZA0ORIG in the
// backup library); rollback is a CRTDUPOBJ back.
// =====================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('ZAISRVBD');

dcl-f qsysprt printer(132) usage(*output);

// ZAISRV exports. EXTPROC names match zaisrv.bnd exactly.
dcl-pr get packed(7:0) extproc('GET');
  prodCode char(6) const;
end-pr;

dcl-pr reserve ind extproc('RESERVE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

dcl-pi *n;
  rmode  char(10);
  minqty packed(5:0);
end-pi;

dcl-ds line len(132) end-ds;

// C1 (JUCHUD, the driver) host variables.
dcl-s lJuno   char(6);
dcl-s lJuline packed(3:0);
dcl-s lJusho  char(6);
dcl-s lJusu   packed(5:0);

// C2 (JUCHUM, the follower) host variable.
dcl-s hJuno char(6);

dcl-s eof1 ind inz(*off);
dcl-s eof2 ind inz(*off);
dcl-s haveHeader ind inz(*off);

dcl-s stock  packed(7:0);
dcl-s avail  packed(7:0);
dcl-s okRes  ind;
dcl-s statusText char(8);

// SET OPTION after every declaration above, before the first
// executable statement (same placement rule as q0805bs.sqlrpgle).
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

exec sql FETCH C1 INTO :lJuno, :lJuline, :lJusho, :lJusu;
if SQLSTATE = '02000';
  eof1 = *on;
endif;

exec sql FETCH C2 INTO :hJuno;
if SQLSTATE = '02000';
  eof2 = *on;
else;
  haveHeader = *on;
endif;

dow not eof1;
  // Advance the header cursor while it lags behind this line.
  dow not eof2 and hJuno < lJuno;
    exec sql FETCH C2 INTO :hJuno;
    if SQLSTATE = '02000';
      eof2 = *on;
      haveHeader = *off;
    endif;
  enddo;

  if haveHeader and hJuno = lJuno;
    processLine();
  endif;
  // else: a line with no header is skipped, as in the legacy MR gate.

  exec sql FETCH C1 INTO :lJuno, :lJuline, :lJusho, :lJusu;
  if SQLSTATE = '02000';
    eof1 = *on;
  endif;
enddo;

exec sql CLOSE C1;
exec sql CLOSE C2;

*inlr = *on;
return;

// =====================================================================
// processLine - one matched order line.
// =====================================================================
dcl-proc processLine;
  dcl-pi *n;
  end-pi;

  // Unlocked peek. -1 means there is no such product.
  stock = get(lJusho);
  if stock = -1;
    statusText = 'NOTFOUND';
    printLine();
    return;
  endif;

  avail = stock - lJusu;
  if avail < minqty;
    // SHORT decided at this layer, on the unlocked value. No lock.
    statusText = 'SHORT';
  else;
    statusText = 'OK';
    if rmode = '*LIVE';
      okRes = reserve(lJusho : lJusu);
      if not okRes;
        // Lost a race or negative minqty: reserve() refused.
        statusText = 'SHORT';
      endif;
    endif;
  endif;

  printLine();
end-proc;

// =====================================================================
// printLine - one detail line, same columns as Q0805B (which matched
// the legacy ZA0500 run text): JUNO at 1, JUSHO at 9, JUSU at 17
// zero-padded, status right-aligned to column 30.
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
// zeroPad - zero-pad a non-negative packed value to a fixed width
// without an edit code (same helper as q0805bs.sqlrpgle).
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
