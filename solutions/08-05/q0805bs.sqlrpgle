**FREE
//=======================================================================
// Q0805B - lesson 08-05b, "characteristics testing" rewrite of the
// legacy ZA0500 (src/legacy/qrpgsrc/za0500.rpg, M1/MR matching-record
// processing over JUCHUD/JUCHUM) as embedded-SQL free-form RPG IV
// (hence Q, not F - part08-design-v1.md section 0.1/2 decision: the
// type-symbol should be Q, not F, since embedded SQL is used), with
// the M1/MR cycle replaced by an explicit TWO-CURSOR FETCH loop that
// manually merges JUCHUD (order lines) and JUCHUM (order headers) on
// JUNO - the manual replacement this lesson's design calls for, not a
// plain SQL JOIN (a JOIN would hide the exact
// mechanics M1/MR itself performs, which is this lesson's own point).
// Business logic (the allocation decision itself) is unchanged from
// za0500.rpg - see that file's own header for its full bug/fix
// history, which this rewrite inherits rather than re-derives.
//
// STATUS: this file has never been compiled or run. JU0900C/ZA0500's
// own golden-master output (12 lines: 10 OK, 2 SHORT, 0 NOTFOUND in
// this repo's real data) is CONFIRMED and recorded verbatim in
// verify/part08-05-legacy-baseline/expected/golden-master.md
// (2026-09-28). This file is the new version to diff against it - not
// yet attempted. F0805A (JU0300's own rewrite, solutions/08-05/
// f0805as.rpgle) hit a real DTAARA(*LDA) syntax error on its own first
// compile attempt (docs/probes.md, part08-05-f0805a) - this file has
// not had the benefit of a real compile yet, so treat every syntax
// choice below as similarly unconfirmed until its own first connection.
//
// TWO-CURSOR MERGE (the M1/MR replacement itself):
// JUCHUD is keyed JUNO(major)/JULINE(minor) - db/v1/juchud.pf - and
// JUCHUM is keyed JUNO alone - db/v1/juchum.pf - so both are already
// naturally ordered by JUNO, exactly the precondition M1 matching
// itself requires (rpg400ref.txt's own matching-record documentation:
// both files must be in ascending sequence on the matching field).
// C1 (JUCHUD, ordered JUNO/JULINE) is the PRIMARY/driving cursor - one
// FETCH per output line, mirroring ZA0500's own primary-file (F-spec
// IP) role for JUCHUD. C2 (JUCHUM, ordered JUNO) only advances when it
// "lags behind" the current C1 row's JUNO (hJuno < lJuno) - since one
// JUCHUM header can match MANY JUCHUD lines (JULINE 1, 2, 3...), C2
// deliberately does NOT re-fetch for every C1 row, only when the
// header's own JUNO is smaller than the line's (i.e. we have moved
// past that header's own line group and need the next header). This
// is the same merge-join principle M1/MR itself implements internally
// - see ju0300.rpg's own header (a different program, but the same
// underlying two-sorted-streams idea, there applied to L1/L2 control
// breaks rather than matching).
//
// UNMATCHED LINES: if a JUCHUD row's JUNO has no matching JUCHUM
// header at all (hJuno <> lJuno after C2 has caught up as far as it
// can), that line is silently skipped - not processed, not printed.
// This matches za0500.rpg's own "01 MR" gate exactly: only a JUCHUD
// record that is ALSO a matched pair (MR on) reaches the allocation
// logic at all; an unmatched line under the ORIGINAL M1/MR cycle would
// never turn MR on and would likewise be skipped. db/data/load_v1.sql
// has no such orphan lines in practice, so this path is not exercised
// by the golden-master data, only by construction.
//
// LOCK-LEAK INHERITED, NOT FIXED: za0500.rpg's own CHAIN never
// releases its lock on the SHORT branch or the found-but-not-*LIVE
// branch (no UNLOCK anywhere in that file at all) - contrast
// solutions/07-05/zaisrv.rpgle's reserve(), which explicitly adds an
// UNLOCK on its own SHORT branch specifically because it found and
// fixed this same class of gap (see that file's own header for the
// full reasoning). This rewrite deliberately does NOT add that fix -
// "characteristics testing" means matching the ORIGINAL's own
// behavior byte-for-byte in its printed output, and adding an UNLOCK
// here would be a functional improvement beyond pure technique
// translation, which is explicitly out of scope for this exercise
// (Capstone-style modernization that also fixes known gaps, if wanted,
// belongs to a later part, not here). Flagged here, not silently
// carried over unremarked, per this repo's own established practice
// for every other inherited quirk (see the array-bounds note in
// f0805as.rpgle for the same reasoning applied to a different quirk).
// Likewise, CHAIN below has no (E) extender, matching za0500.rpg's own
// plain CHAIN exactly (not-found is still detected via %FOUND with no
// extender needed for that; only a genuine lock conflict would behave
// differently, and the original never handled that case either).
//
// RMODE/MINQTY: same *ENTRY-equivalent parameters za0500.rpg's own
// *ENTRY PLIST takes, with the CORRECTED length for MINQTY (5,0, per
// 05-13 ticket 1 - see solutions/05-13/ju0900c-ticket1.clp, which this
// program's own eventual caller must be built from, exactly like
// verify/part08-05-legacy-baseline used).
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f zaikom disk usage(*update) keyed;
dcl-f qsysprt printer(132) usage(*output);

dcl-pi *n;
  rmode  char(10);
  minqty packed(5:0);
end-pi;

dcl-ds line len(132) end-ds;

// C1 (JUCHUD) host variables.
dcl-s lJuno   char(6);
dcl-s lJuline packed(3:0);
dcl-s lJusho  char(6);
dcl-s lJusu   packed(5:0);

// C2 (JUCHUM) host variable.
dcl-s hJuno char(6);

dcl-s eof1 ind inz(*off);
dcl-s eof2 ind inz(*off);
dcl-s haveHeader ind inz(*off);

dcl-s avail packed(7:0);
dcl-s statusText char(8);

// SET OPTION must come AFTER every D-spec above (same rule
// testkit.sqlrpgle's own header documents in detail, confirmed
// working there, part08-04-testkit) and BEFORE the first executable
// statement - q0613s.sqlrpgle/q0614s.sqlrpgle's own established
// placement (right after the last dcl-s, before the first EXEC SQL
// DECLARE CURSOR/PREPARE) is followed here exactly; an earlier draft
// of this file had it too early (between dcl-pi and the remaining
// dcl-ds/dcl-s lines below), which would have put several D-specs
// after this C-spec-equivalent statement - fixed before this file's
// own first compile attempt.
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
  // Advance the header cursor while it still lags behind this line's
  // JUNO - see header, "TWO-CURSOR MERGE".
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
  // else: unmatched line, silently skipped - see header.

  exec sql FETCH C1 INTO :lJuno, :lJuline, :lJusho, :lJusu;
  if SQLSTATE = '02000';
    eof1 = *on;
  endif;
enddo;

exec sql CLOSE C1;
exec sql CLOSE C2;

*inlr = *on;
return;

//=======================================================================
// processLine - the matched-pair allocation logic itself, unchanged
// from za0500.rpg (AVAIL = ZASU - JUSU; SHORT if AVAIL < MINQTY; else
// OK, and if RMODE = *LIVE, ZASU := AVAIL). See header for why no
// UNLOCK is added on the SHORT/not-*LIVE paths.
//=======================================================================
dcl-proc processLine;
  dcl-pi *n;
  end-pi;

  chain lJusho zaikom;
  if not %found(zaikom);
    statusText = 'NOTFOUND';
    printLine();
    return;
  endif;

  avail = zasu - lJusu;
  if avail < minqty;
    statusText = 'SHORT';
  else;
    statusText = 'OK';
    if rmode = '*LIVE';
      zasu = avail;
      update zaikor;
    endif;
  endif;

  printLine();
end-proc;

//=======================================================================
// printLine - one DTL line. Column positions (empirically derived from
// verify/part08-05-legacy-baseline/expected/golden-master.md, see that
// file's own note on the +1 offset from za0500.rpg's own O-spec end
// columns): JUNO@2(6) JUSHO@10(6) JUSU@18(5, UNEDITED - zero-padded,
// NOT zero-suppressed, matching za0500.rpg's own O-spec, which applies
// no edit code to JUSU at all) statusText right-justified ending at
// column 31 (its own length varies: NOTFOUND=8 chars @24, SHORT=5
// chars @27, OK=2 chars @30 - za0500.rpg's own three O-spec constants
// share the same END column but each has its own length, not one
// fixed-width field).
//=======================================================================
dcl-proc printLine;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:2:6)  = lJuno;
  %subst(line:10:6) = lJusho;
  %subst(line:18:5) = zeroPad(lJusu:5);
  %subst(line:32 - %len(%trimr(statusText)):%len(%trimr(statusText)))
    = %trimr(statusText);
  write qsysprt line;
end-proc;

//=======================================================================
// zeroPad - zero-pads a non-negative packed value to a fixed character
// width, WITHOUT using an edit code (no %EDITC code in this repo's own
// primary-source-confirmed set - 'A'-'D','J'-'Q','X'-'Z','1'-'9' - is
// documented as leaving leading zeros in place; 'X' in particular DOES
// zero-suppress, per ilerpgref75.txt's own edit-code table, so it
// cannot be used here). Built from %CHAR + string concatenation
// instead, both already-established techniques (06-06).
//=======================================================================
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
