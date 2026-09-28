**FREE
//=======================================================================
// F0612B - order inquiry screen (same business object as F0604A/JUCINQ4D,
// 06-04), extended with a program-entry parameter so a caller (F0612C,
// below) can pre-fill the customer code instead of making the learner
// retype one already visible on another screen. Lesson 06-12, where
// program-entry dcl-pi is first taught (work/design/part06-design-v1.md,
// decision B1-16) - see f0604s.rpgle's own header ("STATUS" note) and
// f0611s.rpgle's own header ("DEPENDENCY ON F0604A") for the full history
// of why this fix could not simply be an in-place edit of either file.
//
// WHY A NEW OBJECT, NOT AN EDIT TO F0604A ITSELF: 06-04's lesson text is
// already written and teaches F0604A as a self-contained, parameterless
// screen (CALL PGM(F0604A), no PARM) - that lesson's own worked example
// and any learner who already completed it must keep working exactly as
// documented. This file is a SEPARATE compiled object (F0612B) that
// happens to start from F0604A's exact logic, plus the one parameter
// this lesson adds. Naming follows docs/appendix/e-naming.md section 3.1
// (part+lesson+variant-letter; the fix is owned by 06-12, per the design
// decision above, so it is lettered under 06-12's own number, continuing
// after F0612A/JUCINQ4's report program already used in this same
// lesson).
//
// REUSES D0604A UNCHANGED: this program's screen is byte-for-byte the
// same interactive layout 06-04 already built (customer code + order
// list, up to 4 rows) - only the RPG-side logic gains a parameter, so
// there is no new DDS object here at all; dcl-f d0604a below opens the
// EXISTING, already-confirmed D0604A display file (see d0604s.dspf).
//
// WHAT CHANGED FROM F0604A (see that file's own header for everything
// else - the CHAIN/READ porting from R0408A, the CLOSE+OPEN-per-lookup
// rewind, the 4-row cap - all identical, copied verbatim below):
//   A program-entry dcl-pi with ONE optional parameter, custCode
//   char(6) const options(*nopass). OPTIONS(*NOPASS) keeps a bare
//   CALL PGM(F0612B) (no PARM) working exactly like F0604A's own
//   parameterless CALL - %parms tells the mainline whether an argument
//   was actually passed. When one was (and it is not blank), TOKCD is
//   pre-filled from it BEFORE the first EXFMT, so the caller's chosen
//   customer code shows up immediately - the learner still presses
//   Enter once to see the order list (EXFMT/WORKSTN cannot be skipped),
//   but never has to retype a code the caller (F0612C) already knew.
//
// STATUS: CONFIRMED V1 (compile-check, part06-b7-bundle, 2026-09-28):
// CRTBNDRPG Highest Severity 00, under this exact object name (F0612B).
// Same WORKSTN/EXFMT limitation as every other Part 6 screen - V1
// (compile-check) is the realistic ceiling; interactive behavior (V3)
// is still untested.
//
// Verified against work/design/refs/ilerpgref75.txt at the same
// citations f0604s.rpgle's own header already gives for DCL-F/WORKSTN/
// EXFMT/%FOUND/%EOF/CLOSE/OPEN (not re-cited here), plus:
//   Free-Form Procedure Interface Definition,        ~line 29405-29439
//     OPTIONS(*NOPASS) on a parameter, %PARMS to
//     tell how many were actually passed
//=======================================================================

dcl-pi *n;
  custCode char(6) const options(*nopass);
end-pi;

dcl-f d0604a workstn;
dcl-f tokuim keyed;
dcl-f juchum;

dcl-s ordCount packed(3:0);

// Pre-fill TOKCD from the caller's parameter, if one was passed, BEFORE
// the first EXFMT - see header note above.
if %parms >= 1 and custCode <> *blanks;
  tokcd = custCode;
endif;

dow not *in03;
  exfmt jucfmt;

  if not *in03;
    // Clear the order list before every lookup - see f0604s.rpgle's own
    // header for why (a previous customer's rows must not linger).
    ordno1 = *blanks;
    orddt1 = 0;
    ordno2 = *blanks;
    orddt2 = 0;
    ordno3 = *blanks;
    orddt3 = 0;
    ordno4 = *blanks;
    orddt4 = 0;

    chain tokcd tokuim;
    if not %found(tokuim);
      toknm = 'NOTFOUND';
    endif;

    // Rewind JUCHUM before each scan - see f0604s.rpgle's own header
    // ("A GAP THE LESSON PROSE MUST COVER") for why this is required.
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
            // Screen shows only 4 rows - a 5th+ order for the same
            // customer is silently not displayed (same cap F0604A has).
        endsl;
      endif;
      read juchum;
    enddo;
  endif;
enddo;

*inlr = *on;
return;
