**FREE
//=======================================================================
// F0610A - Same order inquiry screen as F0604A, addressed through a
// named indicator data structure (INDDS) instead of numbered
// indicators (Part 6, lesson 06-10).
//
// Purpose of this lesson (work/design/part06-design-v1.md, "06-10"
// entry in section 2): show the SAME screen and the SAME business logic
// as 06-04, once with numbered indicators (F0604A/D0604A) and once with
// INDDS/named indicators (this file/D0610A), so the two can be compared
// side by side. Runtime behavior must be IDENTICAL - this is not a
// redesign, it is the same program addressed a different way. Anywhere
// this file's logic differs from F0604A's, that is a bug, not a design
// choice - see the "deliberately no CF12" and "diff" notes below for
// the only two allowed cosmetic differences (names/header text).
//
// What changed vs. F0604A, and ONLY this:
//   (1) src/qddssrc/d0610s.dspf adds the file-level INDARA keyword
//       (own line, before the R record-format line - the same position
//       ilerpgprogguide75.txt's own worked examples use, e.g. its
//       MAINMENU example: "A ... PRINT(QSYSPRT)" / "A ... INDARA" /
//       "A   R HDRSCN", lines 30777-30807). The CF03(03) keyword itself
//       is UNCHANGED - DDS has no notion of a "named" indicator; DDS
//       still declares indicator 03 by number. Only the RPG side
//       addresses it by name (see below).
//   (2) dcl-f below adds INDDS(dspInds), and a data structure dspInds
//       maps position 3 to the name f3Exit.
//   (3) Every *IN03 reference in F0604A becomes f3Exit here. This is
//       NOT optional or cosmetic: per ilerpgref75.txt page 418 (line
//       27607-27608), "If this keyword [INDDS] is not specified, the
//       *IN array is used to communicate indicator values for all files
//       defined with the DDS keyword INDARA" - which, read the other
//       way around, means that ONCE INDDS IS specified, indicator values
//       for that file route through the named data structure INSTEAD OF
//       the *IN array. *IN03 would simply stay '0' forever in this file
//       if used - F3 would never be able to end the loop. This is the
//       one correctness-critical difference a learner must be told about
//       explicitly, not just a naming preference.
//
// Everything else (screen layout, field names ORDNO1..4/ORDDT1..4,
// TOKCD/TOKNM, the TOKUIM chain, the JUCHUM rewind-and-scan loop, the
// NOTFOUND handling, the 4-row cap) is copied from F0604A unchanged.
// See f0604s.rpgle's own header comment for the full R0408A/R0411A
// cross-reference and the "gap the lesson prose must cover" note about
// CLOSE/OPEN rewinding JUCHUM - all of that applies here identically.
//
// Deliberately NOT added: CF12 (cancel/clear). The 06-10 exercise (add
// an F12 key that clears the screen) asks the learner to add it
// themselves; adding it here would
// make this file's behavior diverge from F0604A's before the learner
// even starts the exercise, which breaks the "compare the two, they
// behave the same" premise of this lesson.
//
// STATUS: hardware-UNTESTED (Part 6 draft, draft/part06 branch). Same
// verification ceiling as F0604A/D0604A: CRTDSPF/CRTBNDRPG compilation
// (V1) is realistically checkable over non-interactive SSH; EXFMT's
// interactive read-from-5250 is not (see R0411A's own hardware note,
// 04-11, "verification range limits", and F0604A's STATUS section).
//
// Verified against work/design/refs/ilerpgref75.txt (the real IBM i 7.5
// ILE RPG Language Reference, 73451 lines) at these locations:
//   INDDS(data_structure_name) keyword,        page 418 (heading at
//     File Description Specification           line 27585; rules at
//     keywords - "lets you associate a data     lines 27587-27608,
//     structure name with the INDARA            including the *IN-vs-DS
//     indicators..."; "If this keyword is       routing rule quoted
//     not specified, the *IN array is used..."  above)
//   Worked INDDS example: "DCL-F Disp WORKSTN   pages 250-251 (Figure
//     INDDS(DispInds);" + "DCL-DS DispInds;     60 "Using an indicator
//     ShowName IND POS(21); Exit IND POS(3);    data structure", lines
//     ...END-DS;" - same shape used below,      16456-16483; the POS(3)
//     just with one subfield (f3Exit) instead   mapping in that example
//     of several                                is itself indicator 3,
//                                               the same number CF03(03)
//                                               uses here)
//   IND data type + POS(n) keyword for a        page 523 (heading at
//     free-form data structure subfield -       line 34504-34521;
//     "DCL-DS indds LEN(99); exit IND           worked example: "DCL-DS
//     POS(3); ...END-DS;" (LEN(99): "The        indds LEN(99); exit IND
//     length of the indicator data structure    POS(3); ...")
//     is always 99" - INDDS keyword rules,
//     page 418, line 27603)
//   DDS INDARA keyword placement (file level,   ilerpgprogguide75.txt,
//     own line, before any R record-format      "MAINMENU" worked
//     line) - ilerpgref75.txt itself only        example, lines 30777-
//     documents INDDS from the RPG side; the    30807 (also lines
//     DDS-side keyword placement was confirmed  11747-11753,
//     against the IBM i 7.5 ILE RPG Programmer's 31036-31041,
//     Guide, which is also in work/design/refs   31663-31669,
//     (ilerpgprogguide75.txt)                    32110-32116)
//=======================================================================

dcl-f d0610a workstn indds(dspInds);
dcl-f tokuim keyed;
dcl-f juchum;

dcl-ds dspInds len(99);
  f3Exit ind pos(3);
end-ds;

dcl-s ordCount packed(3:0);

dow not f3Exit;
  exfmt jucfmt;

  if not f3Exit;
    // Clear the order list before every lookup - see F0604A's header
    // comment for why this is needed (stale rows from a previous
    // customer would otherwise linger on screen).
    ordno1 = *blanks;
    orddt1 = 0;
    ordno2 = *blanks;
    orddt2 = 0;
    ordno3 = *blanks;
    orddt3 = 0;
    ordno4 = *blanks;
    orddt4 = 0;

    // Same CHAIN(TOKUIM) + rewind-and-scan(JUCHUM) port as F0604A - see
    // its header comment for the full R0408A cross-reference and the
    // "unconditional scan" fidelity note.
    chain tokcd tokuim;
    if not %found(tokuim);
      toknm = 'NOTFOUND';
    endif;

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
            // Screen shows only 4 rows - see F0604A's header comment.
        endsl;
      endif;
      read juchum;
    enddo;
  endif;
enddo;

*inlr = *on;
return;
