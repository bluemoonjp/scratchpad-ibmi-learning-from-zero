**FREE
//=======================================================================
// F0611AP - JUCLST4, PAGE-AT-A-TIME variant of F0611A (06-11). See
// f0611s.rpgle's own "PAGE-AT-A-TIME CONVERSION NOTE" header comment for
// the full rationale (B1-16: load-all taught first as the basic form,
// page-at-a-time here as the optimization built on top of it) - this
// file only implements the four concrete steps that note lists, against
// the companion DDS variant src/qddssrc/d0611ps.dspf (object D0611AP,
// SFLSIZ(4)/SFLPAG(3) - see that file's own header for why SFLPAG is
// deliberately small).
//
// HARDWARE STATUS: CONFIRMED V1 (compile-check, part06-b6-batch,
// 2026-09-27): CRTBNDRPG Highest Severity 00. V1 (compile-check) is
// the realistic ceiling - same WORKSTN/EXFMT limitation as every other
// Part 6 screen.
//
// WHAT'S DIFFERENT FROM F0611A (see that file for everything else -
// message subfile, option 5, %EOF/%FOUND-takes-the-file-name fix, etc.
// - all identical, including "callp f0604a()" staying parameterless
// here too, matching F0611A's own current state; the JUTOK-passing fix
// is owned by 06-12, not by either 06-11 variant):
//   1. loadNextPage() (below) WRITEs at most PAGESIZE (3) JUCHUM rows
//      per call, tracking end-of-file across calls in the module-scope
//      eofReached indicator - contrast with F0611A's own single load
//      loop, which WRITEs every row in one pass before the first EXFMT.
//   2. The mainline calls loadNextPage() ONCE before the first EXFMT
//      (loading only the first page), then again each time indicator 25
//      (ROLLUP/PAGEDOWN) fires with eofReached still *off - continuing
//      RRN1 across calls, never restarting from 0.
//   3. MORE (SFL1FTR) shows 'MORE...' while eofReached is *off, 'BOTTOM'
//      once JUCHUM is exhausted - recomputed after every loadNextPage()
//      call, same plain-output-field technique F0611A already uses
//      (stands in for SFLEND, which this repo does not use - see
//      d0611ps.dspf's own header for why).
//   4. JUCHUM is opened once (implicit, no USROPN) and NEVER
//      closed/reopened mid-program - the whole point of page-at-a-time
//      is that JUCHUM's read position must survive across EXFMT calls,
//      the opposite of f0604s.rpgle's own CLOSE+OPEN-per-lookup pattern
//      (which rewinds on purpose, for an unrelated reason - see that
//      file's header).
//
// Verified against work/design/refs/ilerpgref75.txt at the same
// citations f0611s.rpgle's own header already gives for SFILE/READC/
// CHAIN/%EOF/%FOUND (not re-cited here) - nothing new syntactically is
// used in this file beyond what F0611A/F0604A already use.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f d0611ap workstn sfile(sfl1:rrn1);
dcl-f juchum disk;

dcl-pr f0604a extpgm('F0604A') end-pr;

dcl-c PAGESIZE 3;

dcl-s rrn1 packed(4:0) inz(0);
dcl-s eofReached ind inz(*off);

//-----------------------------------------------------------------------
// Mainline. Loop shape matches F0611A's own EXFMT loop, except for the
// loadNextPage()-on-ROLLUP step inserted right after EXFMT (point 2
// above).
//-----------------------------------------------------------------------
pgmq = '*';

loadNextPage();

if rrn1 = 0;
  // Empty-subfile edge case (F0611A's own header note) - JUCHUM has 8
  // sample rows as of this writing, so this should not trigger in
  // practice, but is handled rather than assumed away.
  rrn1 = 1;
  opt = *blanks;
  juno = *blanks;
  jutok = *blanks;
  judate = 0;
  jutan = *blanks;
  write sfl1;
endif;

more = 'MORE...';
if eofReached;
  more = 'BOTTOM';
endif;

dow not *in03;
  write sfl1ftr;
  exfmt sfl1ctl;

  if not *in03;
    if *in25 and not eofReached;
      loadNextPage();
      more = 'MORE...';
      if eofReached;
        more = 'BOTTOM';
      endif;
    endif;

    readc sfl1;
    dow not %eof(d0611ap);
      select;
        when opt = '5';
          callp f0604a();
        when opt = ' ';
          // Blank OPT reaching here means the user typed something and
          // then cleared it back to blank - genuine "changed to blank",
          // no action needed either way.
        other;
          sendInvalidOpt();
      endsl;
      readc sfl1;
    enddo;
  endif;
enddo;

*inlr = *on;
return;

//=======================================================================
// loadNextPage: WRITEs up to PAGESIZE (3) more JUCHUM rows into SFL1,
// continuing RRN1 from wherever it left off. Sets eofReached *on the
// moment JUCHUM's own %EOF fires, so the caller never asks for another
// page after that.
//
// UNVERIFIED, DOCUMENTED INTERACTION (see docs/part06/06-11-subfiles-page-message.md's
// own hardware notes section for the learner-facing version of this same note):
// RRN1 (the SFILE(SFL1:RRN1) field) is also written by READC whenever
// the caller reads a selected row (ilerpgref75.txt's own SFILE keyword
// description: the RRN of a row retrieved by READC/CHAIN is placed
// into the rrnfield). If a row is selected (READC overwrites RRN1)
// and ROLLUP fires before the next EXFMT, this proc's `rrn1 += 1`
// would continue from the selected row's RRN rather than the true
// load position - interactive-only to test (WORKSTN/EXFMT cannot run
// non-interactively in this harness), so this has not been confirmed
// either way.
//=======================================================================
dcl-proc loadNextPage;
  dcl-pi *n;
  end-pi;

  dcl-s pageCount packed(4:0) inz(0);

  dow pageCount < PAGESIZE and not eofReached;
    read juchum;
    if %eof(juchum);
      eofReached = *on;
    else;
      rrn1 += 1;
      opt = *blanks;
      write sfl1;
      pageCount += 1;
    endif;
  enddo;
end-proc;

//-----------------------------------------------------------------------
// sendInvalidOpt: unchanged from F0611A - see that file's header for
// the SND-MSG/%TARGET(*SELF) rationale.
//-----------------------------------------------------------------------
dcl-proc sendInvalidOpt;
  dcl-pi *n;
  end-pi;

  snd-msg *diag 'Invalid option - use 5 for order inquiry, blank to'
    + ' skip.' %target(*self);
  write msgctl;
end-proc;
