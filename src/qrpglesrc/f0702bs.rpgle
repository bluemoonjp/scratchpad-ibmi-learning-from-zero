**FREE
//=======================================================================
// F0702B - "JUCLST4, JUCSRV version" (nickname, lesson prose only): a
// load-all subfile listing JUCHUM (Part 7, lesson 07-02, ADVANCED/
// OPTIONAL exercise - NOT part of 07-02's own mandatory verification;
// see work/design/decisions-2026-09.md, entry P7-9, and the lesson's
// own real-hardware notes section for why this is scoped as optional).
//
// WHAT THIS DEMONSTRATES: a SECOND, independent real caller of JUCSRV's
// getCustName (the first is F0702A, this lesson's own required worked
// example) - one that calls it from inside a load-all subfile's own
// loop, once per row, instead of once for a single CL-supplied
// parameter. This is the concrete "before/after" this exercise exists
// to show: JUCHUM alone (as D0611A/F0611A, 06-11, already lists it)
// has no customer name to show; JUCSRV lets a SECOND, independent
// program add that column without duplicating TOKUIM's own CHAIN logic
// (which stays inside JUCSRV, written exactly once).
//
// D0611A/F0611A (06-11) are NOT edited by this exercise - per this
// lesson's own design decision, this is a brand-new, parallel object
// pair (D0702A/F0702B) that does not touch 06-11's own graded work.
//
// STRUCTURAL TEMPLATE: this file is a close copy of
// src/qrpglesrc/f0611s.rpgle (F0611A, 06-11) - same workstn/sfile
// declaration, same load-all read loop shape, same empty-subfile
// placeholder-row handling, same "write sfl1ftr before every EXFMT
// sfl1ctl" discipline (see f0611s.rpgle's own header for the CPD7812
// footer-split rationale this file reuses unchanged). Per the P7-9
// decision, this exercise deliberately drops what F0611A has that this
// one does not need:
//   - OPT / the option-5 CALL F0604A branch and READC loop - this
//     exercise's whole point is a second real caller of getCustName,
//     not option-5 machinery. With no OPT field, there is nothing for
//     READC to report, so the EXFMT loop below simply repeats EXFMT
//     until *IN03 (F3) - the system handles ROLLUP/ROLLDOWN paging
//     within the already-loaded subfile entirely on its own, exactly
//     as F0611A's own header describes for load-all.
//   - MSGSFL/MSGCTL/sendInvalidOpt - with no OPT field there is no
//     invalid-option case to report.
//
// NEW: JUNM is filled by calling JUCSRV's getCustName(jutok) for each
// row, BEFORE that row's WRITE (not after) - this program never
// UPDATEs a subfile row once written (no SFLRCDNBR/RRN-based rewrite,
// same simplification F0611A's own header already documents for OPT),
// so JUNM must already hold the right value at WRITE time.
//
// BINDING: same ctl-opt shape as F0702A (dftactgrp(*no) actgrp(*new)
// bnddir('JUCSRVBD')) and the same dcl-pr for getCustName, copied
// verbatim from f0702s.rpgle - see that file's own header for the full
// EXTPROC(*DCLCASE) rationale (not repeated here).
//
// STATUS: V1-only (compile-check only), NOT YET compiled on real
// hardware - a future connection will confirm this. Per the P7-9
// decision, this exercise's verification is V1 (compile-check) plus
// the learner's own manual V3 test (a real 5250 session); it is
// deliberately NOT part of 07-02's own mandatory/automated
// verification manifest.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('JUCSRVBD');

dcl-f d0702a workstn sfile(sfl1:rrn1);
dcl-f juchum disk;

//-----------------------------------------------------------------------
// dcl-pr / EXTPROC(*DCLCASE): prototype for JUCSRV's getCustName,
// copied verbatim from f0702s.rpgle (per this lesson's own task scope -
// do not invent a different prototype shape).
//-----------------------------------------------------------------------
dcl-pr getCustName char(30) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-s rrn1 packed(4:0) inz(0);

//-----------------------------------------------------------------------
// Load-all: WRITE every JUCHUM row into SFL1, same as F0611A's own load
// loop (JUNO/JUTOK/JUDATE/JUTAN auto-match from JUCHUM's own field
// names - db/v1/juchum.pf). JUNM is NOT a JUCHUM field, so it needs an
// explicit assignment - the one addition this exercise makes: a call to
// JUCSRV's getCustName for every row, resolved via JUCSRVBD/*LIBL
// exactly like F0702A's own single call.
//-----------------------------------------------------------------------
read juchum;
dow not %eof(juchum);
  rrn1 += 1;
  junm = getCustName(jutok);
  write sfl1;
  read juchum;
enddo;

if rrn1 = 0;
  // Empty-subfile edge case - see F0611A's own header (IBM's SFLDSP
  // reference: an output op to a never-activated subfile errors).
  rrn1 = 1;
  juno = *blanks;
  jutok = *blanks;
  judate = 0;
  jutan = *blanks;
  junm = getCustName(jutok);   // jutok is blank here - expect 'NOTFOUND'
  write sfl1;
endif;

// Load-all has nothing left to fetch once the WRITE loop above ends -
// same reasoning as F0611A's own header.
more = 'BOTTOM';

dow not *in03;
  // FTR must be (re)WRITEn before every EXFMT SFL1CTL - same OVERLAY/
  // CPD7812 discipline as F0611A (see d0702s.dspf's own header).
  write sfl1ftr;
  exfmt sfl1ctl;
enddo;

*inlr = *on;
return;
