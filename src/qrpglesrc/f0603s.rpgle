**FREE
// F0603A - **FREE rewrite of R0405A (04-05, RPG III structured
// opcodes: IFxx/ANDxx/DOWxx/EXSR-BEGSR-ENDSR). Uses the same test
// data (SCORE=82, running total of 1..5), so GRADE='A' and SUM=15
// match R0405A's verified result (04-05 hardware memo, printed as
// "A             SUM= 00015"). This file's own print line is NOT
// laid out byte-for-byte like R0405A's O-spec output (that quote
// even puts 'A' at column 1, while r0405s.rpg's own O-spec says
// GRADE ends at column 10 -- the two do not agree, so only the
// grade/sum VALUES are comparable, not the column layout). This
// file's own expected 23-byte line is:
//   A  SUM=00015 MID  00015
// (outgrade='A', outfill='  SUM=', outsum=00015 (from DOW), outcat=
// ' ', outsumlabel='MID ' (sum=15 falls in "when sum <= 20"),
// outsep=' ', outsum2=00015 (from FOR, computed independently)).
//
// CONFIRMED on real hardware (part06-0103-freeform, 2026-09-26): CRTBNDRPG
// Highest Severity 00, CALL printed the expected 23-byte line (read
// directly from the connection's raw run section text, not from
// WRKSPLF/DSPSPLF -- this harness's non-interactive SSH jobs don't create
// a real spool file for QSYSPRT output). See
// docs/part06/06-03-free-form-basics.md and docs/probes.md.
//
// Verified vs work/design/refs/ilerpgref75.txt (approx line refs):
// - **FREE must be alone in column 1 of line 1: near line 23295.
// - ctl-opt syntax: near line 24060-24090. (DFTACTGRP itself is
//   06-05's new concept, so it is deliberately NOT used here; see
//   OPTION(*NODEBUGIO) below instead, near line 24089, 25584.)
// - dcl-s/dcl-c, CHAR/PACKED/ZONED/IND, INZ, LIKE: near line
//   28713-28870 (dcl-s/dcl-c), 30408 (CHAR), 31803 (IND), 31812
//   (INZ), 31981 (LIKE), 34448 (PACKED), 35442 (ZONED).
// - IFxx is "not allowed - use the IF operation code" in free-form:
//   near line 57492. DOWxx is likewise "not allowed - use the DOW
//   operation code": near line 55651. Plain IF/DOW take a boolean
//   expression instead of a comparand pair.
// - SELECT/WHEN/OTHER/ENDSL: near line 63492-63567.
// - FOR/ENDFOR: near line 57095-57170.
// - EXSR/ENDSR are unchanged from RPG III, still valid as free-form
//   statements: near line 42352-42420. BEGSR's opcode-then-name order
//   ("begsr prtout;") is the reverse of RPG III's name-then-opcode
//   Factor-1 form ("PRTOUT BEGSR" in R0405A) -- same spot in the file,
//   just read the operand order off the actual syntax there.
// - *INLR is a named indicator, assignable directly: near line
//   16424, 16494, 16583 (*INLR = *ON;).
// - += compound assignment (replaces ADD, "not allowed" in free
//   form): near line 42812-42818, 51465, 51803.
//
// No %-BIFs are used here (out of scope for this lesson; see
// 06-01b/06-06). dcl-f/dcl-ds are used only as unavoidable output
// plumbing so the result is checkable: **FREE cannot contain
// O-specs at all (near line 23295-23300), and this lesson does not
// yet cover %-BIFs or externally described printer files. dcl-f and
// dcl-ds are not among 06-03's own nine new-concept items; they are
// formally introduced in 06-04 and 06-07 respectively.
//
// (Earlier drafts of this comment said this file was untested and had
// not been compiled -- that was already stale by the time 06-03 was
// written: part06-0103-freeform had settled the compile/run result
// above.) One remaining unconfirmed detail: the last byte of a raw
// (unedited) zoned field can print as a non-digit letter for NEGATIVE
// values; SUM/SUM2 here are always zero or positive, so this file's
// own run does not exercise that case. The reference's own text on
// the X edit code (near line 22350: "the X edit code ensures a
// hexadecimal F sign for positive fields... because the system does
// this, you normally do not have to specify this code") indicates
// positive zoned values already carry an F-zone sign nibble, which
// prints as a plain digit -- consistent with what this run actually
// printed, though the negative case itself remains untested here.

ctl-opt option(*nodebugio);

dcl-f qsysprt printer(23);

dcl-c lowscore 80;
dcl-c hiscore 100;

dcl-s score packed(3:0) inz(82);
dcl-s sum packed(5:0) inz(0);
dcl-s sum2 like(sum) inz(0);
dcl-s idx zoned(3:0) inz(1);
dcl-s idx2 like(idx) inz(1);
dcl-s grade char(1) inz(' ');
dcl-s validscore ind inz(*on);
dcl-s sumlabel char(4) inz(' ');

dcl-ds outrec;
  outgrade char(1);
  outfill char(6) inz('  SUM=');
  outsum zoned(5:0);
  outcat char(1) inz(' ');
  outsumlabel char(4);
  outsep char(1) inz(' ');
  outsum2 zoned(5:0);
end-ds;

// IF/ELSE: same decision as R0405A's IFGE 80 / ANDLE 100 / ELSE / ENDIF.
if score >= lowscore and score <= hiscore;
  grade = 'A';
else;
  grade = 'B';
endif;

// Named ind (validscore): extends 04-05's exercise 3 (ORxx for
// out-of-range scores). Not exercised by the default test data
// (82 is in range), but shows the ind type and the pattern.
if score < 0 or score > hiscore;
  validscore = *off;
  grade = 'X';
endif;

// DOW: same running total as R0405A's DOWLE5/ENDDO.
dow idx <= 5;
  sum += idx;
  idx += 1;
enddo;

// FOR: the same total, computed the other structured-loop way.
for idx2 = 1 to 5;
  sum2 += idx2;
endfor;

// SELECT/WHEN/OTHER: classify the total. OTHER is written even
// though it is optional (06-03's core concept 3).
select;
  when sum < 10;
    sumlabel = 'LOW ';
  when sum <= 20;
    sumlabel = 'MID ';
  other;
    sumlabel = 'HIGH';
endsl;

// Read the named indicator back: an out-of-range score overrides
// the classification above (never triggered by the default test
// data, since 82 is in range -- see the ind declaration above).
if not validscore;
  sumlabel = 'BAD ';
endif;

exsr prtout;

*inlr = *on;

begsr prtout;
  outgrade = grade;
  outsum = sum;
  outsumlabel = sumlabel;
  outsum2 = sum2;
  write qsysprt outrec;
endsr;
