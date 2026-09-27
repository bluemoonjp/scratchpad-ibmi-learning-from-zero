**FREE
//=======================================================================
// Q0615A - Stock inquiry checkpoint (06-15), SQL half. Reproduces
// R0413A's (04-13) and F0607A's (06-07) LOWSTOCK judgment (ZASU <
// SHOHAT), replacing R0413A's native CHAIN with an embedded SQL cursor
// JOIN across ZAIKOM/SHOHIM (06-13/06-14's own embedded-SQL technique)
// - this checkpoint introduces NO new syntax at all
// (part06-design-v1.md's own 06-15 section). This is the SQL half of
// the checkpoint; see d0615s.dspf/f0615s.rpgle for the SUBFILE half
// (an interactive, read-only browse using 06-11's technique).
//
// Unlike the subfile half (WORKSTN/EXFMT, V1-only), this program is a
// plain batch report to QSYSPRT with no interactive I/O at all - same
// shape as R0413A itself - so it CAN be confirmed non-interactively
// over SSH (V2), by comparing its printed output directly against the
// grading table below.
//
// WARM-UP CHECK (lesson text must state this): this checkpoint reads
// SHOHIM, which 06-11b's own maintenance screen (F0611BA) can add/
// change/delete. Before running this checkpoint, confirm 06-11b's own
// TXRESET cleanup has already been done (part06-design-v1.md:338) -
// otherwise this checkpoint's LOWSTOCK judgment may not match the
// grading table below, through no fault of this program.
//
// GRADING TABLE (confirmed real hardware, F0607A, docs/probes.md's
// part06-0509-procs-files section, fresh/reset ZAIKOM+SHOHIM): 6 rows
// total, exactly 2 are LOWSTOCK - P00002 (OFFICE CHAIR, qty 3, reorder
// point 5) and P00005 (USB CABLE, qty 12, reorder point 50). The other
// 4 (P00001/P00003/P00004/P00006) print with no LOWSTOCK flag.
//
// COLUMN LAYOUT (deliberately matches R0413A's own O-specs exactly,
// src/qrpgsrc/r0413s.rpg, so this program's output is directly
// comparable to R0413A's original spool output): R0413A's O-spec
// column numbers are END positions (right-justified fields) - ZASHO
// ends at column 8 (6 chars, so columns 3-8), SHONM ends at 42 (30
// chars, columns 13-42), ZASU ends at 55 (unedited 7 digits, columns
// 49-55), LOWSTOCK ends at 70 (8 chars, columns 63-70).
//
// SQL JOIN replacing R0413A's CHAIN: ZAIKOM's key is ZASHO, SHOHIM's
// key is SHOCD (different names, same product-code concept -
// db/v1/zaikom.pf + db/v1/shohim.pf) - the join condition below
// (Z.ZASHO = S.SHOCD) is the SQL-side equivalent of R0413A's own
// "ZASHO CHAINSHOHIM" cross-field-name CHAIN. An INNER JOIN is used
// (not LEFT JOIN) because every ZAIKOM row is expected to have a
// matching SHOHIM row (same assumption R0413A's own design makes) -
// this repo has no referential-integrity enforcement, so a genuinely
// orphaned ZAIKOM row would simply not appear in this report, unlike
// f0615s.rpgle's subfile half, which defensively prints "UNKNOWN
// PRODUCT" for that case instead of skipping the row. This is a
// deliberate, documented difference between the two halves, not an
// oversight - the SQL half's job is to be the simplest possible JOIN.
// JOIN is already-taught material (docs/part02/02-06-sql-inquiry.md),
// not new here. The LOWSTOCK judgment itself is computed in RPG below
// (if wZasu < wShohat), NOT with a SQL CASE expression - CASE is not
// taught anywhere in this repo, and this checkpoint's own design
// section states its content as "no new syntax at all".
//
// SQLSTATE-vs-SQLCODE convention: same as q0613s.sqlrpgle/
// q0614bs.sqlrpgle - the FETCH loop tests SQLSTATE = '00000' to
// continue, and the initial cursor OPEN checks SQLCODE < 0 (a real
// error) rather than SQLSTATE = '00000' (which would also flag benign
// warnings as failures).
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f qsysprt printer(132) usage(*output);

dcl-ds prtLine len(132);
  prtText char(132) pos(1);
end-ds;

dcl-s wZasho  char(6);
dcl-s wShonm  char(30);
dcl-s wZasu   zoned(7:0);
dcl-s wShohat zoned(5:0);
dcl-s wStatus char(8);

dcl-s numTxt varchar(10);
dcl-s padded char(7);

exec sql SET OPTION commit = *none, naming = *sys;

exec sql DECLARE C1 CURSOR FOR
  SELECT Z.ZASHO, S.SHONM, Z.ZASU, S.SHOHAT
    FROM ZAIKOM Z
    JOIN SHOHIM S ON Z.ZASHO = S.SHOCD
    ORDER BY Z.ZASHO;

exec sql OPEN C1;

if SQLCODE < 0;
  prtText = 'OPEN C1 failed, SQLCODE=' + %char(SQLCODE);
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;

exec sql
  FETCH C1 INTO :wZasho, :wShonm, :wZasu, :wShohat;

dow SQLSTATE = '00000';
  // LOWSTOCK judgment computed here in RPG, not in the SQL SELECT
  // above - see the "SQL JOIN" header note.
  if wZasu < wShohat;
    wStatus = 'LOWSTOCK';
  else;
    wStatus = *blanks;
  endif;

  clear prtLine;
  %subst(prtText:3:6)   = wZasho;
  %subst(prtText:13:30) = wShonm;

  // Zero-pad ZASU to 7 digits (e.g. "0000043"), matching R0413A's own
  // unedited numeric O-spec output - same technique f0608s.rpgle's
  // report line already uses (not %EDITC, which is not on this
  // checkpoint's "no new syntax" list).
  numTxt = %char(wZasu);
  if %len(numTxt) < 7;
    padded = %subst('0000000' : 1 : 7 - %len(numTxt)) + numTxt;
  else;
    padded = numTxt;
  endif;
  %subst(prtText:49:7) = padded;

  %subst(prtText:63:8) = wStatus;
  write qsysprt prtLine;

  exec sql
    FETCH C1 INTO :wZasho, :wShonm, :wZasu, :wShohat;
enddo;

exec sql CLOSE C1;

*inlr = *on;
return;
