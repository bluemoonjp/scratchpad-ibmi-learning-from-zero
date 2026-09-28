**FREE
//=======================================================================
// F0611A - JUCLST4: order list (JUCHUM), load-all subfile with a
// row-selection option (5 = call F0604A, order inquiry). Lesson 06-11.
// Companion display file: src/qddssrc/d0611s.dspf (object D0611A) - see
// its header for the full DDS-side rationale (SFL/SFLCTL/message-
// subfile column positions, house pattern reused from
// src/legacy/qddssrc/tk0100d.dspf and tools/gen/dspf.mjs). This header
// only covers the RPG-side half of that same contract.
//
// CONFIRMED V1 (compile-check, part06-screens-compile, 2026-09-26):
// CRTBNDRPG Highest Severity 00, this exact parameterless-option-5
// form. (A later session briefly compiled a JUTOK-passing version in
// part06-decisions-1 - reverted, see "DEPENDENCY ON F0604A" below for
// why that fix is deferred to 06-12 instead of landing here.)
// Interactive subfile/EXFMT execution (V3) is still untested - SSH
// non-interactive batches cannot drive a real 5250 device (same
// WORKSTN/EXFMT limitation as 04-11, tk0100.rpg, and f0604s.rpgle).
// Verify with a real 5250 session before relying on this file's
// interactive behavior.
//
// LOAD-ALL (primary/documented form): per work/design/part06-design-
// v1.md's B1-16 disposition, load-all is taught first as the basic
// subfile-loading strategy, page-at-a-time second as an optimization.
// This program WRITEs every JUCHUM row into SFL1 in one pass, BEFORE
// the first EXFMT of SFL1CTL. Once loaded, SFLPAG/ROLLUP/ROLLDOWN
// paging within the subfile is handled entirely by the system - no
// "load more on scroll" logic is needed here (contrast with the
// page-at-a-time conversion note below).
//
// EMPTY-SUBFILE EDGE CASE: d0611s.dspf's SFLDSP/SFLDSPCTL on SFL1CTL
// are unconditioned (always on), matching tk0100d.dspf's own no-DDS-
// conditioning-indicator policy (04-11's CPD7410/CPD7606/CPD5238
// failure - see d0611s.dspf's header). IBM's SFLDSP reference warns
// that an output operation to an unconditioned SFLDSP errors if the
// subfile was never "activated" (by adding at least one record, or by
// SFLINZ). If JUCHUM has zero rows, the load loop below would WRITE
// zero SFL1 records - so this program always WRITEs at least one SFL1
// record (a blank placeholder row when the JUCHUM scan finds nothing),
// exactly as d0611s.dspf's own header describes this as the
// "header-only WRITE" case.
//
// PAGE-AT-A-TIME: implemented as a separate object pair, F0611AP/D0611AP
// (f0611ps.rpgle/d0611ps.dspf) - CONFIRMED V1 (compile-check,
// part06-b6-batch, 2026-09-27). See that RPG file's own header for the
// actual loadNextPage()/eofReached design (SFLSIZ(4)/SFLPAG(3), not
// SFLPAG(14)/SFLSIZ(15) as an earlier draft of this note sketched).
//
// MESSAGE SUBFILE: an "invalid option" diagnostic is sent through
// MSGSFL/MSGCTL (d0611s.dspf) whenever OPT is neither blank nor '5'.
// tk0100.rpg's own header states it never actually drives TK0100D's
// SFL1/MSGSFL (it only exercises INQFMT); this program is this repo's
// first RPG source to actually drive a message subfile end-to-end, via
// the free-form SND-MSG operation with %TARGET(*SELF) instead of a
// hand-written QMHSNDPM prototype (contrast with f0609s.rpgle, which
// DOES hand-write a QMHSNDPM prototype because it targets the job log,
// not a display file's own message queue). PGMQ (d0611s.dspf's MSGCTL
// field, paired with SFLPGMQ) is set to '*' once, at program start, per
// d0611s.dspf's header note that '*' tells SFLINZ to rebuild MSGSFL
// from "the program message queue of the program that has this display
// file open" (IBM SFLPGMQ reference) - i.e. this program's own message
// queue, which is exactly where SND-MSG %TARGET(*SELF) places messages
// (ilerpgref75.txt, "SND-MSG": "If the message type is *INFO, the
// default is %TARGET(*SELF)... the message is sent to the current
// procedure" - *DIAG defaults to %TARGET(*CALLER) instead, so
// %TARGET(*SELF) is passed explicitly below to redirect it here).
// UNCONFIRMED DETAIL (flagged, not silently assumed): SND-MSG's exact
// interaction with a WORKSTN file's SFLPGMQ-driven message subfile (as
// opposed to the job log) is not spelled out anywhere in
// ilerpgref75.txt in as many words - the reference only documents (a)
// SND-MSG placing messages on a call-stack entry's message queue
// ("the joblog"), and (b) SFLINZ/SFLPGMQ pulling from "the program
// message queue of the program that has this display file open"
// (tk0100d.dspf's own citation for that half). This program combines
// the two on the reasonable assumption that a program's own call-stack
// message queue - the "PGMQ" - is the same thing as its own "job log"
// entry, which is standard IBM i terminology (SNDPGMMSG/QMHSNDPM to the
// caller's own call stack entry). Verify this combination compiles AND
// actually displays a message (V1 and V3) before treating it as
// confirmed; it is the one part of this file's SND-MSG usage not
// directly walked through in a primary-source worked example.
//
// SFLNXTCHG: deliberately NOT used on SFL1 (contrast with
// tk0100d.dspf's MSGSFL/SFL1, which sets it unconditionally on
// purpose, defeating READC's normal changed-only filtering, per that
// file's own header). This program wants the normal, default READC
// behavior - only rows where the terminal user actually typed
// something into OPT come back from READC - so SFLNXTCHG is omitted
// here on purpose, not by oversight.
//
// RRN/SFLRCDNBR: RRN1 (the SFILE keyword's RRN field, an RPG-only
// variable, no DDS field) is a plain incrementing counter for the load
// loop. SFLRCDNBR is not used (same "not needed here" reasoning as
// d0611s.dspf/tk0100d.dspf) - this means OPT is never cleared/rewritten
// back into the subfile after a selection is processed (doing that
// would need either SFLRCDNBR or a result data structure to recover
// the just-read row's RRN for a CHAIN/UPDATE pair). Left as a known,
// documented simplification for this V1/compile-check lesson, not a
// silently swallowed gap - a natural follow-up exercise is "clear OPT
// after processing a row, using CHAIN(rrn):SFL1 + UPDATE".
//
// DEPENDENCY ON F0604A (real bug, fix DEFERRED to 06-12 - see below):
// F0604A has no *ENTRY PLIST/dcl-pi at all (dcl-f d0604a workstn; with
// zero parameters) - a fully self-contained interactive screen that
// prompts for its OWN customer code via TOKCD on its own JUCFMT record
// format, so it cannot receive a passed customer code from this list.
// This is a genuine bug (the task brief's "call F0604A passing that
// row's customer code" silently does not happen), not a design choice
// - but giving F0604A a program-entry dcl-pi belongs to 06-12
// (part06-design-v1.md's own B1-16 disposition explicitly defers
// program-entry dcl-pi there, where it is actually taught as new
// syntax; a brief attempt to fix this directly in 06-04/06-11's own
// files was reverted for exactly that reason - see f0604s.rpgle's own
// header for the same reversion note). This program calls F0604A with
// a zero-parameter dcl-pr extpgm('F0604A') prototype - the same shape
// f0605s.rpgle already uses for R0409A, which likewise has no *ENTRY
// PLIST - and a plain parameterless CALLP; the learner will retype the
// customer code on F0604A's own screen after it comes up. RESOLVED
// (2026-09-28 design correction): the fix does NOT edit F0604A or this
// file - it lives in new 06-12-owned objects, F0612B/F0612C
// (src/qrpglesrc/f0612bs.rpgle/f0612cs.rpgle, reusing D0604A/D0611A's
// DDS unchanged), CONFIRMED (part06-b7-bundle, 2026-09-28). F0604A and
// this file (F0611A) stay exactly as written here - the learner still
// retypes the customer code when going through F0604A/F0611A
// themselves. NOTE for the P7-9-driven 07-02 work: this is a
// separate, unrelated concern (P7-9 forbids editing D0611A/F0611A for
// JUCSRV's getCustName integration specifically) - do not conflate the
// two.
//
// STATUS: CONFIRMED V1 (compile-check, part06-screens-compile,
// 2026-09-26). Interactive/EXFMT behavior (V3) is still untested -
// treat runtime claims about the SCREEN'S interactive behavior as
// "should work per the ILE RPG Language Reference", not as verified.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference) at these locations:
//   SFILE(recformat:rrnfield) keyword          ~line 28400-28437
//   READC (Read Next Changed Record),          ~line 62000-62029
//     free-form syntax + DOW %EOF worked         (worked example: READC
//     example                                    SFCUSR / DOW %EOF =
//                                                 *OFF / CHAIN (E) /
//                                                 IF NOT %ERROR)
//   CHAIN search-argument forms, N extender    ~line 53190-53235
//   UPDATE (no intervening ops between lock     ~line 65809-65898
//     read and UPDATE)
//   DELETE (usage(*update)/(*delete) needed)   ~line 55181-55232
//   UNLOCK (release the most recently locked   ~line 65693-65761
//     record for an update disk file)
//   SND-MSG (Send a Message to the Joblog),    ~line 64132-64221
//     message types *DIAG/*INFO, %TARGET
//     special values *SELF/*CALLER
//   DCL-F free-form defaults (DISK defaults to ~line 26045-26079
//     USAGE(*INPUT) with no device keyword;
//     WORKSTN defaults to USAGE(*INPUT:*OUTPUT))
//   DCL-PR / EXTPGM (call to an external        ~line 8730-8756,
//     program), zero-parameter form              matches f0605s.rpgle's
//                                                 own citation
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f d0611a workstn sfile(sfl1:rrn1);
dcl-f juchum disk;

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: zero-parameter prototype for F0604A (06-04, order
// inquiry). See the "DEPENDENCY ON F0604A" header note above for why
// this is parameterless - F0604A's own dcl-f has no *ENTRY PLIST to
// receive an argument (fix deferred to 06-12). Same shape as
// f0605s.rpgle's r0409a prototype.
//-----------------------------------------------------------------------
dcl-pr f0604a extpgm('F0604A') end-pr;

dcl-s rrn1 packed(4:0) inz(0);

//-----------------------------------------------------------------------
// sendInvalidOpt: SND-MSG *DIAG, targeted at *SELF (not the default
// *CALLER for *DIAG - see header note on %TARGET), then WRITE MSGCTL so
// the message subfile overlay refreshes immediately, without waiting
// for the next EXFMT. PGMQ must already be '*' (set once in the
// mainline below) for SFLINZ to pull from this program's own message
// queue - see d0611s.dspf's MSGCTL header note.
//-----------------------------------------------------------------------
//-----------------------------------------------------------------------
// Mainline. Loop shape (dow not *in03 / exfmt / if not *in03 ...
// endif / enddo) matches f0604s.rpgle's and R0411A's own EXFMT loop,
// per this repo's established convention.
//-----------------------------------------------------------------------

// PGMQ ('*' = this program's own message queue) is a MSGCTL field-
// level SFLPGMQ keyword's companion (d0611s.dspf). Set once, before
// any WRITE/EXFMT touches MSGCTL.
pgmq = '*';

//-----------------------------------------------------------------------
// Load-all: WRITE every JUCHUM row into SFL1 before the first EXFMT.
// JUCHUM's own field names (JUNO/JUTOK/JUDATE/JUTAN) match SFL1's
// fields exactly (db/v1/juchum.pf), so the same-name auto-match trick
// (R0408A/R0411A/f0604s.rpgle all rely on it too) fills them with no
// explicit assignment - only OPT (this screen's own field, not in
// JUCHUM) needs to be set explicitly.
//-----------------------------------------------------------------------
read juchum;
dow not %eof(juchum);
  rrn1 += 1;
  opt = *blanks;
  write sfl1;
  read juchum;
enddo;

if rrn1 = 0;
  // Empty-subfile edge case - see header note. One blank placeholder
  // row keeps SFLDSP valid (IBM's SFLDSP reference: an output op to a
  // never-activated subfile errors).
  rrn1 = 1;
  opt = *blanks;
  juno = *blanks;
  jutok = *blanks;
  judate = 0;
  jutan = *blanks;
  write sfl1;
endif;

// Load-all has nothing left to fetch once the WRITE loop above ends -
// there is no "more records waiting in JUCHUM" state to report, unlike
// page-at-a-time (see header conversion note).
more = 'BOTTOM';

dow not *in03;
  // FIXED (part06-screens-compile prep, 2026-09-26): d0611s.dspf's
  // SFL1CTL used to also carry the MORE/F3=Exit footer directly, which
  // CPD7812's on real hardware forbids (see tk0100d.dspf's confirmed
  // fix, docs/probes.md). The footer now lives in its own SFL1FTR
  // record format, and SFL1CTL carries OVERLAY - so it must be WRITEn
  // first, every pass, before SFL1CTL is (re)EXFMT'd on top of it.
  write sfl1ftr;
  exfmt sfl1ctl;

  if not *in03;
    readc sfl1;
    // FIXED (part06-screens-compile, 2026-09-26, real-hardware
    // CRTBNDRPG): %EOF takes the WORKSTN FILE name (d0611a), not the
    // subfile RECORD FORMAT name (sfl1) - RNF0391 ("Parameter SFL1 is
    // not valid for built-in function %EOF"). Confirmed against
    // ilerpgref75.txt line 45624: "%EOF{(file_name)}".
    dow not %eof(d0611a);
      select;
        when opt = '5';
          callp f0604a();
        when opt = ' ';
          // Blank OPT reaching here means the user typed a space and
          // then backspaced/cleared it - a genuine "changed to blank"
          // case, not the common case (READC does not return rows the
          // user never touched at all). No action needed either way.
        other;
          sendInvalidOpt();
      endsl;
      readc sfl1;
    enddo;
  endif;
enddo;

*inlr = *on;
return;

// FIXED (2026-09-26, repo-wide sweep after part06-gen-probe's
// connection-2 finding): sendInvalidOpt used to sit BEFORE the
// mainline above. ilerpgref75.txt's RPG IV Concepts chapter is
// explicit that a subprocedure must be defined AFTER the main source
// section (the mainline) - see docs/probes.md's part06-gen-probe
// section for the full citation. Moved here to match.
dcl-proc sendInvalidOpt;
  dcl-pi *n;
  end-pi;

  snd-msg *diag 'Invalid option - use 5 for order inquiry, blank to'
    + ' skip.' %target(*self);
  write msgctl;
end-proc;
