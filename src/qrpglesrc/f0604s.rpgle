**FREE
//=======================================================================
// F0604A - Order inquiry screen, JUCINQ3's logic ported to **FREE
// (Part 6, lesson 06-04). Business nickname: JUCINQ4D.
//
// Design background (work/design/part06-design-v1.md, section 0.3 and
// the "06-04" entry in section 2): the draft syllabus assumed a
// "JUCINQ3D" RPG III screen version already existed and just needed
// porting. It does not exist - no lesson in Part 4 ever built a screen
// for the order-inquiry business object. 04-11 (R0411A) built a DIFFERENT
// screen (a plain TOKUIM name lookup, no orders). So this lesson does
// two things in one file: (a) design a brand-new screen using the DDS
// technique 04-11 taught, and (b) port R0408A's CHAIN+READ business
// logic into it. There is no prior *screen* to diff against - only
// R0408A's C-spec logic and 04-11's DDS conventions.
//
// What this replaces / connects to (RPG III, fixed-form):
//
//   R0408A (04-08, nickname JUCINQ3, src/qrpgsrc/r0408s.rpg,
//   hardware-verified 2026-09-25: <USER>2 CRTRPGPGM Highest Severity 00,
//   CALL produced "ACME TRADING CO   J00001  20260901" /
//   "ACME TRADING CO   J00003  20260905" for CUST = 'C00001', see
//   docs/part04/04-08-jucinq3-report.md). Its logic, ported here exactly
//   (same fields, same filter, same two-file shape):
//     MOVEL'C00001'  CUST    6        -> here CUST comes from the screen
//                                        (TOKCD), not a literal
//     CUST      CHAINTOKUIM       99  -> chain tokcd tokuim; %found()
//     99        MOVEL'NOTFOUND'TOKNM  -> if not %found(tokuim);
//                                        toknm = 'NOTFOUND'; endif;
//     LOOP TAG / READ JUCHUM  98      -> read juchum; dow not %eof(juchum)
//     98        GOTO ENDLP            -> (the dow condition itself)
//     JUTOK     IFEQ CUST             -> if jutok = tokcd;
//     EXCPT (print one line)          -> fill the next ORDNOn/ORDDTn pair
//     GOTO LOOP / ENDLP TAG           -> read juchum; / enddo;
//   IMPORTANT FIDELITY POINT: R0408A's JUCHUM scan is UNCONDITIONAL - it
//   runs even when the TOKUIM chain fails (see the lesson's own exercise
//   3: a nonexistent customer code shows TOKNM = NOTFOUND, but the scan
//   still runs and simply finds zero matching orders). This file
//   preserves that: the JUCHUM scan below is not wrapped in
//   "if %found(tokuim)".
//
//   R0411A (04-11, src/qrpgsrc/r0411s.rpg + src/qddssrc/r0411s.dspf,
//   hardware-verified 2026-09-25 for compile only - see its own
//   "hardware notes" section: EXFMT/WORKSTN interactive execution
//   cannot be checked over non-interactive SSH). This lesson's DDS
//   (d0604s.dspf) follows R0411A's conventions closely:
//     - DSPSIZ(24 80 *DS3), a single record format, CF03(03) for exit.
//     - TOKCD 6A input, TOKNM 30A output - SAME names/lengths as
//       TOKUIM's own fields, so CHAIN's result shows up on screen with
//       no explicit assignment (the same "same-name auto-display" trick
//       R0411A relies on - see its "why F3=Exit line uses MOVEL and not
//       a DDS conditioning indicator" hardware note: conditioning
//       indicators on DDS field/constant lines did NOT compile for that
//       lesson author, CPD7410/CPD7606/CPD5238, so this file avoids them
//       too and only ever overwrites TOKNM's *content* from RPG, exactly
//       like R0411A does for the NOTFOUND case).
//     - EXFMT-then-check-*IN03 loop shape (dow not *in03 / exfmt / if
//       not *in03 ... endif / enddo), same as R0411A's
//       "*IN03 DOWEQ*OFF / EXFMT / N03 ... / ENDDO".
//   DEVIATION FROM R0411A noted here for the lesson author: the order
//   list needs its own rows, which R0411A's single-field screen never
//   had to deal with. See "screen layout" below for how that was solved,
//   and "F3=Exit" was moved from row 5 (R0411A) to row 12, below the
//   order list, since this screen has more content than R0411A's.
//
// Screen layout (src/qddssrc/d0604s.dspf), new design (see the header
// note above - there was no existing screen to preserve):
//   Row 1:  Customer code: [TOKCD, 6A input]
//   Row 3:  Name: [TOKNM, 30A output - same name/length as TOKUIM.TOKNM]
//   Row 5:  Orders: (header text)
//   Row 6:  Order no / Order date (column headers)
//   Row 7-10: up to 4 rows, ORDNO1..4 (6A) / ORDDT1..4 (8S 0, matching
//     JUCHUM.JUDATE's own type/length exactly - see db/v1/juchum.pf).
//     4 rows is a deliberate, generous margin: as of this writing
//     db/data/load_v1.sql's JUCHUM sample rows give any one customer at
//     most 2 orders (C00001: J00001/J00003; C00003: J00004/J00008). A
//     5th+ order for the same customer would silently not be shown
//     (the SELECT/OTHER branch below is deliberately empty) - flag this
//     cap explicitly in the lesson prose.
//   Row 12: F3=Exit
//   ORDNO1..4/ORDDT1..4 are program-described screen-only fields (they
//   do NOT share JUCHUM's field names) because the "same-name
//   auto-display" trick only works for ONE variable per name - it
//   cannot fill 4 different screen rows from one JUNO/JUDATE pair. They
//   are filled explicitly below instead.
//
// A GAP THE LESSON PROSE MUST COVER (flagged for the 06-04 author, not
// silently absorbed into the "5 new syntax items" budget in
// work/design/part06-design-v1.md's 06-04 section): R0408A is a
// straight-through BATCH program - it opens JUCHUM once and scans it
// exactly once per CALL. This program is INTERACTIVE - it can look up
// several different customer codes in one run (that is the whole point
// of the EXFMT loop, and of this lesson's own NOTFOUND exercise, which
// implies trying at least two codes in the same session). JUCHUM must
// therefore be repositioned to the beginning before every scan, or the
// second and later lookups would see end-of-file immediately and always
// report zero orders. CLOSE + OPEN (both plain RPG IV opcodes, neither
// of them new BIFs) is used below for this. This is NOT listed in the
// design doc's "new syntax" count for 06-04 and was not requested by
// the task brief; it is added here because leaving it out would make
// the ported program silently wrong on the second customer code, which
// matters more than staying inside the syntax quota. The 06-04 lesson
// text should either explain CLOSE/OPEN briefly or restructure around
// this constraint - see docs/part04/04-08-jucinq3-report.md for why
// R0408A itself never needed this (single CALL = single scan).
//
// STATUS: CONFIRMED V1 (compile-check, part06-decisions-1,
// 2026-09-27): CRTBNDRPG Highest Severity 00, after adding the
// optional custCode entry parameter (see the header note above).
// Per R0411A's own hardware note (04-11, "verification range limits"):
// CRTDSPF/CRTBNDRPG compilation (V1) IS realistically checkable over
// non-interactive SSH, but EXFMT's interactive read-from-5250 cannot be
// - CALLing a WORKSTN/EXFMT program over non-interactive SSH just hangs
// waiting for a device that is not there. So V1 (compile only) is the
// realistic ceiling for this file's own verification; the interactive
// behavior (V3) is left to a learner's real 5250 session, exactly as
// R0411A's own hardware note says for itself.
//
// Verified against work/design/refs/ilerpgref75.txt (the real IBM i 7.5
// ILE RPG Language Reference, 73451 lines) at these locations:
//   DCL-F free-form syntax, DISK defaults to    "Free-Form File
//     DISK(*EXT)/USAGE(*INPUT) when no device   Definition Statement",
//     keyword is given at all                   page 394 (line ~26045-
//                                                26047; example
//                                                "DCL-F file1a;" at
//                                                line 26073)
//   WORKSTN defaults to USAGE(*INPUT:*OUTPUT)    Table 106, page 396
//     ("Combined Full-procedural" row); example  (line 26169; example
//     "DCL-F file4 WORKSTN;"                     at line 26077)
//   EXFMT (Write/Then Read Format), free-form    page 857 (heading at
//     syntax "EXFMT{(E)} format-name             line 56811; worked
//     {data-structure}"                          example with
//                                                dow not *in03 / exfmt
//                                                / select at line
//                                                56856-56881)
//   %FOUND (Return Found Condition) - set by     page 700 (heading at
//     CHAIN, opposite of the old "no record      line 45999); table
//     found NR" indicator                        summary at line 39629
//   %EOF (Return End or Beginning of File         page 695 (heading at
//     Condition) - set by READ, NOT by CHAIN      line 45622); the
//     (confirmed explicitly: "the following        exact "READ INREC;
//     operations...set %EOF(filename) off...      IF %EOF; ENDIF;"
//     CHAIN...OPEN...SETGT...SETLL" - line         shape is Figure 209,
//     45638-45644)                                 line 45664-45669
//   CLOSE (Close Files) / OPEN (Open File for     pages 814 / 925
//     Processing) - "the programmer can reopen    (headings at lines
//     the file with the OPEN operation and the    53862 / 61289; reopen
//     USROPN keyword...is not required" (i.e.     rule at line 61308-
//     no USROPN needed for this CLOSE-then-OPEN   61312)
//     pattern)
//=======================================================================

dcl-f d0604a workstn;
dcl-f tokuim keyed;
dcl-f juchum;

// FIXED (Part 6 source cleanup, 06-11's F0611A option 5 depends on this):
// an optional entry parameter lets a caller pre-fill TOKCD instead of
// making the learner retype a customer code already visible on another
// screen. OPTIONS(*NOPASS) keeps the old zero-parameter CALL PGM(F0604A)
// (bare 5250 test, no PARM) working exactly as before - see the mainline
// below, which only touches TOKCD when a code was actually passed.
dcl-pi *n;
  custCode char(6) const options(*nopass);
end-pi;

dcl-s ordCount packed(3:0);

// Pre-fill TOKCD from the caller's parameter, if one was passed, BEFORE
// the first EXFMT - the learner still presses Enter once to see the
// order list (EXFMT/WORKSTN screens cannot be skipped), but never has to
// retype a code the caller already knew.
if %parms >= 1 and custCode <> *blanks;
  tokcd = custCode;
endif;

dow not *in03;
  exfmt jucfmt;

  if not *in03;
    // Clear the order list before every lookup. R0408A never needed
    // this (one CALL = one scan = one set of printed lines); this
    // interactive version reuses the same screen fields across
    // multiple lookups, so a previous customer's rows must not linger.
    ordno1 = *blanks;
    orddt1 = 0;
    ordno2 = *blanks;
    orddt2 = 0;
    ordno3 = *blanks;
    orddt3 = 0;
    ordno4 = *blanks;
    orddt4 = 0;

    // R0408A: MOVEL'C00001' CUST 6 / CUST CHAIN TOKUIM 99 / 99 MOVEL...
    // TOKCD doubles as both the search argument (typed on the screen)
    // and TOKUIM's own key field name, so CHAIN's result (TOKUIM.TOKNM)
    // shows up on screen automatically - the same technique R0411A uses
    // for its own TOKCD/TOKNM pair.
    chain tokcd tokuim;
    if not %found(tokuim);
      toknm = 'NOTFOUND';
    endif;

    // R0408A: LOOP TAG / READ JUCHUM 98 / 98 GOTO ENDLP / JUTOK IFEQ
    // CUST / EXCPT / ENDIF / GOTO LOOP / ENDLP TAG - ported to dow/if,
    // not goto/tag, per the task instructions for this lesson.
    // Deliberately UNCONDITIONAL (not "if %found(tokuim)"): R0408A scans
    // JUCHUM regardless of whether the TOKUIM chain found a name, so a
    // nonexistent customer code still runs the scan and correctly finds
    // zero matching orders (see this lesson's own NOTFOUND exercise).
    //
    // Rewind JUCHUM before each scan - see the header comment's "gap"
    // note for why this is required here and was never needed in
    // R0408A's single-pass batch version.
    close juchum;
    open juchum;

    ordCount = 0;
    read juchum;
    dow not %eof(juchum);
      if jutok = tokcd;
        ordCount = ordCount + 1;
        select;
          when ordCount = 1;
            ordno1 = juno;
            orddt1 = judate;
          when ordCount = 2;
            ordno2 = juno;
            orddt2 = judate;
          when ordCount = 3;
            ordno3 = juno;
            orddt3 = judate;
          when ordCount = 4;
            ordno4 = juno;
            orddt4 = judate;
          other;
            // Screen shows only 4 rows (see header comment) - a 5th+
            // order for the same customer is silently not displayed.
        endsl;
      endif;
      read juchum;
    enddo;
  endif;
enddo;

*inlr = *on;
return;
