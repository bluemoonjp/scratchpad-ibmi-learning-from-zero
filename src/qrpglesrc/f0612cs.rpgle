**FREE
//=======================================================================
// F0612C - JUCLST4 (same business object as F0611A, 06-11's order list),
// with option 5 fixed to actually pass the selected row's customer code
// to F0612B (this lesson's parameterized copy of F0604A - see that
// file's own header for the full naming/history rationale). Lesson
// 06-12, where program-entry dcl-pi is first taught
// (work/design/part06-design-v1.md, decision B1-16).
//
// WHY A NEW OBJECT, NOT AN EDIT TO F0611A ITSELF: 06-11's lesson text is
// already written and teaches F0611A's option 5 as "call F0604A, no
// customer code passed - retype it on the next screen" (a documented,
// deliberate limitation at that point in the curriculum, since F0604A
// had no parameter to receive one yet - see f0611s.rpgle's own
// "DEPENDENCY ON F0604A" header note). That lesson's worked example must
// keep matching its own shipped source. This file is a SEPARATE compiled
// object (F0612C) that starts from F0611A's exact logic, with only the
// option-5 CALLP changed. Naming follows docs/appendix/e-naming.md
// section 3.1, lettered under 06-12's own number (after F0612A/F0612B).
//
// REUSES D0611A UNCHANGED: this program's subfile screen is byte-for-
// byte the same layout 06-11 already built - only the RPG-side option-5
// handler changes, so there is no new DDS object here; dcl-f d0611a
// below opens the EXISTING, already-confirmed D0611A display file (see
// d0611s.dspf).
//
// WHAT CHANGED FROM F0611A (see that file's own header for everything
// else - load-all, message subfile, %EOF-takes-the-file-name, etc., all
// identical, copied verbatim below): the dcl-pr for the called program
// now takes ONE parameter (custCode char(6) const options(*nopass)) and
// names it extpgm('F0612B') - F0612B, not F0604A, since F0604A itself
// was never given a parameter (see F0612B's own header for why). The
// option-5 CALLP now passes JUTOK (this row's customer code, filled by
// READC via the same-name auto-match trick F0611A's own header already
// describes), so the learner no longer retypes a code already visible
// on this screen.
//
// STATUS: NOT YET COMPILED (draft/part06 branch, 2026-09-28). An earlier
// session compiled this exact shape (JUTOK-passing CALLP, parameterized
// dcl-pr) under the name F0611A/extpgm('F0604A') in part06-decisions-1
// (commit ef7e330, later reverted) - Highest Severity 00 there. Renaming
// both the calling object (F0612C) and the called program's prototype
// (extpgm('F0612B'), not 'F0604A') means that prior compile does not
// carry over as-is; a fresh V1 compile-check under these exact names is
// still needed before this counts as CONFIRMED. Track this alongside
// 06-12's other pending real-hardware items (docs/probes.md). NOTE for
// the P7-9-driven 07-02 work: F0611A/D0611A themselves are untouched by
// this file, so P7-9's "do not edit D0611A/F0611A for JUCSRV's
// getCustName integration" restriction is unaffected either way.
//
// Verified against work/design/refs/ilerpgref75.txt at the same
// citations f0611s.rpgle's own header already gives for SFILE/READC/
// CHAIN/%EOF/%FOUND/DCL-PR/EXTPGM (not re-cited here) - nothing new
// syntactically is used in this file beyond what F0611A/F0612B already
// use.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f d0611a workstn sfile(sfl1:rrn1);
dcl-f juchum disk;

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: one-parameter prototype for F0612B (this lesson's
// parameterized copy of F0604A/order inquiry). See the header note above
// for why this targets F0612B, not F0604A.
//-----------------------------------------------------------------------
dcl-pr f0612b extpgm('F0612B');
  custCode char(6) const options(*nopass);
end-pr;

dcl-s rrn1 packed(4:0) inz(0);

//-----------------------------------------------------------------------
// Mainline. Loop shape matches F0611A's own EXFMT loop exactly - see
// that file's header for the full rationale (load-all, empty-subfile
// edge case, message subfile, etc.).
//-----------------------------------------------------------------------

pgmq = '*';

read juchum;
dow not %eof(juchum);
  rrn1 += 1;
  opt = *blanks;
  write sfl1;
  read juchum;
enddo;

if rrn1 = 0;
  rrn1 = 1;
  opt = *blanks;
  juno = *blanks;
  jutok = *blanks;
  judate = 0;
  jutan = *blanks;
  write sfl1;
endif;

more = 'BOTTOM';

dow not *in03;
  write sfl1ftr;
  exfmt sfl1ctl;

  if not *in03;
    readc sfl1;
    dow not %eof(d0611a);
      select;
        when opt = '5';
          // FIXED (this file's whole reason for existing - see header):
          // JUTOK, this row's customer code (filled by READC via the
          // same-name auto-match trick), is now actually passed.
          callp f0612b(jutok);
        when opt = ' ';
          // Blank OPT reaching here means the user typed a space and
          // then backspaced/cleared it - a genuine "changed to blank"
          // case, not the common case. No action needed either way.
        other;
          sendInvalidOpt();
      endsl;
      readc sfl1;
    enddo;
  endif;
enddo;

*inlr = *on;
return;

dcl-proc sendInvalidOpt;
  dcl-pi *n;
  end-pi;

  snd-msg *diag 'Invalid option - use 5 for order inquiry, blank to'
    + ' skip.' %target(*self);
  write msgctl;
end-proc;
