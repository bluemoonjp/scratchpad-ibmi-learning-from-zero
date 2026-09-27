**FREE
//=======================================================================
// F0704A - STATIC local variables and activation-group lifetime (Part 7,
// lesson 07-04).
//
// STATUS: hardware-UNTESTED (Part 7 draft, draft/part06 branch). This
// source has not been compiled or run on PUB400 yet. Neither has Part 6,
// which this Part 7 draft otherwise depends on (part07-design-v1.md
// section 0, preamble). Treat every runtime claim below as "should work
// per the cited IBM i 7.5 references", not as a verified fact.
//
// WHAT THIS DEMONSTRATES: a subprocedure-local STATIC variable holds its
// value across repeated calls WITHIN one program activation (ordinary
// STATIC semantics, nothing actgrp-specific yet) - and separately, that
// an activation's static storage is scoped to the ACTIVATION GROUP the
// program is running in, so whether that static value survives ACROSS
// separate CALL PGM(F0704A) invocations depends entirely on which
// activation group F0704A was created to run in, and RCLACTGRP can wipe
// that storage out on demand. This file is deliberately ONE compiled
// object (F0704A cannot simultaneously be ACTGRP(*NEW) and a named
// activation group - ACTGRP is a single create-time attribute), so it is
// compiled into a NAMED, persistent activation group (see the CTL-OPT
// note below) because that is the ONLY one of the three choices
// (*NEW / named / *CALLER) that makes the required "RCLACTGRP resets
// this state" demonstration concrete and testable without a second
// object. The *NEW and *CALLER contrasts are explained here from the
// primary sources instead of separately compiled - see the two notes
// below.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference) and work/design/refs/ileconcepts75.txt (IBM i 7.5
// ILE Concepts) at approximately these line numbers:
//
//   STATIC keyword (local variable, subprocedure-only,   ilerpgref75.txt
//     "hold its value across calls to the procedure in   lines 35122-
//     which it is defined"; "initialized when the        35143
//     program ... is first activated. It is not
//     reinitialized again")
//   ACTGRP control-specification keyword                 ilerpgref75.txt
//     (*STGMDL|*NEW|*CALLER|'activation-group-name'),    lines 24173-
//     valid only with CRTBNDRPG                           24191
//   ACTGRP name CASE-SENSITIVITY note: "The name of the   ilerpgref75.txt
//     activation group ... will have exactly the same     lines 24193-
//     case as the text entered ... RCLACTGRP does not     24197
//     allow lower-case text" - this is why the name below
//     is written 'F0704AG' in upper case, not 'f0704ag'
//   DFTACTGRP defaulting when a free-form CTL-OPT uses    ilerpgref75.txt
//     ACTGRP/BNDDIR/STGMDL: DFTACTGRP(*NO) is assumed     lines 25064-
//     even if not written explicitly (this file writes    25093
//     it explicitly anyway, matching f0609s.rpgle's style)
//   DFTACTGRP(*YES) forbids ACTGRP/BNDDIR/STGMDL and       ilerpgref75.txt
//     requires calling programs, not procedures - same     lines 25073-
//     reason f0609s.rpgle needed DFTACTGRP(*NO)             25074
//     (this file also defines and calls between
//     subprocedures: runCounterDemo, bumpCounter,
//     sendToJobLog)
//   Activation: "Each activation is local to a            ileconcepts75.
//     particular activation group, and each activation     txt lines
//     has its own static storage" / "the space is          1389-1392,
//     allocated from an activation group"                  1432-1436
//   User-named activation group: "created when it is       ileconcepts75.
//     first needed. It is then used by all programs and    txt lines
//     service programs that specify the same activation    1657-1664
//     group name" (persists across separate calls, is
//     NOT auto-deleted on return)
//   System-named activation group (ACTGRP(*NEW)): "create  ileconcepts75.
//     a new activation group whenever the program is       txt lines
//     called" / Figure 18: "For the system-named            1665-1671,
//     activation group ..., a normal return from P1         1797-1801
//     deletes the associated activation group. For the
//     user-named activation group ..., a normal return
//     from P1 does NOT delete the associated activation
//     group."
//   ACTGRP(*CALLER): "the program is activated into the    ileconcepts75.
//     activation group of the calling program ... a new     txt lines
//     activation group is never created" (service-program    1672-1676,
//     wording, same ACTGRP value/semantics for a *PGM per     4929-4942
//     ilerpgref75.txt line 24180 above)
//   RCLACTGRP: deletes a NAMED, NOT-IN-USE, non-default     cl_commands_
//     activation group and frees its resources, including    75.txt
//     "static storage for programs in the activation          lines
//     group"; "An activation group cannot be reclaimed if     12319-12354
//     there are programs or procedures running within the
//     activation group" (so RCLACTGRP can only run from a
//     SEPARATE step, after F0704A itself has returned - it
//     cannot reclaim its own currently-active activation
//     group from inside itself); CPF1653/CPF1654 errors
//     ("not found" / "cannot be deleted")                    lines
//                                                             12439-12443
//   RCLACTGRP job-scope / "controlling program" usage        ileconcepts75.
//     note                                                   txt lines
//                                                             4923-4927
//
// Why SNDPGMMSG/QMHSNDPM and not DSPLY: same reason as f0609s.rpgle
// (DSPLY needs an interactive job; this lesson's V2 verification runs
// non-interactively over SSH/batch). The QMHSNDPM prototype/call pattern
// below (qmhsndpmMsgFile/qmhsndpmErrCode templates, dcl-pr qmhsndpm
// extpgm, sendToJobLog) is copied verbatim in shape from
// src/qrpglesrc/f0609s.rpgle (its own header cites ilerpgref75.txt lines
// 13744-13773 for this exact prototype), per this task's explicit
// instruction to match f0609s.rpgle's technique.
//
// -----------------------------------------------------------------------
// HOW TO OBSERVE THE *NEW vs. NAMED-ACTGRP vs. RCLACTGRP CONTRAST
// (operational note - this is a sequence of SEPARATE CL commands run by
// an operator or the verify/ harness against the ALREADY-COMPILED
// F0704A object; none of this is, or could be, embedded in this RPG
// source itself, since RCLACTGRP cannot target the activation group it
// is itself currently running in - see the RCLACTGRP citation above.
// IMPORTANT FOR WHOEVER WRITES THE verify/part07-04-*/manifest.json FOR
// THIS LESSON: all four steps below MUST run inside the SAME job, or
// the whole contrast collapses (a fresh job's second CALL would show
// 1,2,3 regardless of activation group, indistinguishable from *NEW).
// verify/lib/clgen.mjs (read directly - lines 71-129) compiles every
// "cl"-type step of ONE manifest batch into label/GOTO/MONMSG-connected
// commands inside a SINGLE generated CL wrapper *PGM, which is then run
// with exactly one CALL from one SSH/system() connection - so as long
// as the four steps below are written as separate "cl" steps of ONE
// manifest batch (not split across multiple batches / multiple
// system() calls), the harness's own design already guarantees they
// share one job. This has been checked directly against clgen.mjs's
// source, not assumed.):
//
//   CALL PGM(F0704A)
//     -> job log shows bumpCounter() returning 1, 2, 3 (three calls
//        inside ONE invocation - plain STATIC persistence, no activation
//        group semantics involved yet).
//   CALL PGM(F0704A)              -- second, SEPARATE CALL, same job
//     -> because F0704A is compiled into the NAMED activation group
//        F0704AG (see CTL-OPT below), and a named activation group is
//        NOT deleted when the program returns (Figure 18 citation
//        above), this second invocation reuses the SAME activation, so
//        its static storage was never reinitialized: bumpCounter()
//        returns 4, 5, 6 - CONTINUING, not resetting.
//   RCLACTGRP  ACTGRP(F0704AG)
//     -> deletes the F0704AG activation group and its static storage
//        (must run after the CALL above has returned, per the
//        "not in use" restriction cited above).
//   CALL PGM(F0704A)              -- third CALL, after RCLACTGRP
//     -> a fresh activation is required, so bumpCounter() returns
//        1, 2, 3 again - the counter was reset by RCLACTGRP.
//
//   CONFIRMED (part07-04b-actgrp, 2026-09-27, real hardware, exactly
//   this 4-step sequence in one job): first CALL -> 1,2,3. Second CALL
//   (same job, no RCLACTGRP in between) -> 4,5,6, CONTINUING as
//   predicted. RCLACTGRP ACTGRP(F0704AG) -> "Activation group F0704AG
//   deleted." (a leading RCLACTGRP attempt on the very first CALL of a
//   fresh job, tried defensively, correctly failed with "Activation
//   group F0704AG not found" - confirming named activation groups are
//   per-job, not left over from a previous connection/job). Third CALL
//   (after RCLACTGRP) -> 1,2,3 again, RESET as predicted. Every part of
//   this file's own predicted contrast is now real-hardware confirmed.
//
//   CONTRAST if F0704A had instead been compiled with ACTGRP(*NEW) (not
//   done here, since RCLACTGRP could not then usefully target it - see
//   below): EVERY one of the three CALL PGM(F0704A) invocations above
//   would independently show bumpCounter() returning 1, 2, 3, because a
//   system-named activation group is created fresh for each call and
//   auto-deleted the moment the program returns (ileconcepts75.txt
//   Figure 18, cited above) - there would be nothing left by the time of
//   the SECOND call for static storage to persist in, and RCLACTGRP
//   would have no reachable, still-existing name to reclaim by the time
//   an operator typed it (CPF1653 "Activation group not found").
//
//   ACTGRP(*CALLER) COMPARISON - attempted, blocked by a DIFFERENT,
//   genuine finding (part07-04b-actgrp, 2026-09-27): building a
//   *CALLER-bound comparison object from this same source, via
//   CRTRPGMOD (module only) + CRTPGM ACTGRP(*CALLER) (CRTPGM's own
//   ACTGRP parameter is meant to override whatever a module's ctl-opt
//   said), FAILED at the CRTRPGMOD step itself: "Compilation stopped.
//   Severity 20 errors found in program." This source's own ctl-opt
//   line below includes actgrp('F0704AG') - which this file's own
//   header already cites as "valid only with CRTBNDRPG" - and
//   CRTRPGMOD (unlike CRTBNDRPG) rejects that keyword outright, so a
//   module cannot even be created from this exact source. Getting a
//   *CALLER comparison object would need a SEPARATE copy of this
//   source with the ctl-opt's actgrp(...) keyword removed entirely
//   (dftactgrp(*no) alone) - not yet done; the *CALLER contrast itself
//   remains the one part of this file's predicted behavior that is
//   still unconfirmed, though for a different reason than originally
//   flagged here.
// -----------------------------------------------------------------------
//=======================================================================

ctl-opt dftactgrp(*no) actgrp('F0704AG') option(*srcstmt);

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: QMHSNDPM prototype, copied field-for-field from
// src/qrpglesrc/f0609s.rpgle (which in turn copied it from
// ilerpgref75.txt's own worked example, lines 13744-13773).
//-----------------------------------------------------------------------
dcl-ds qmhsndpmMsgFile qualified template;
  *n char(10) inz('QCPFMSG');
  *n char(10) inz('*LIBL');
end-ds;

dcl-ds qmhsndpmErrCode template;
  bytesProvided int(10) inz(0);
  bytesAvailable int(10);
  msgId char(7);
  *n char(1);
end-ds;

dcl-pr qmhsndpm extpgm;
  msgId          char(7) const;
  msgFile        likeds(qmhsndpmMsgFile) const;
  msgData        char(1000) const;
  dataLen        int(10) const;
  msgType        char(10) const;
  callStackEntry char(10) const;
  callStackCtr   int(10) const;
  msgKey         char(4) const;
  errorCode      likeds(qmhsndpmErrCode);
end-pr;

//-----------------------------------------------------------------------
// Mainline: plain cycle-main procedure, same shape as f0609s.rpgle (no
// program-entry dcl-pi - this program takes no CL-level parameters).
//
// DOES *inlr = *on RESET bumpCounter's static "counter"? No - this is
// the obvious question a learner would ask, so it is answered directly
// here, not left implicit: ilerpgref75.txt lines 14831-14833 state, of
// a cycle module: "the value changes on the next call to the cycle-
// main procedure if LR was on at the end of the last call [but this is
// about GLOBAL definitions cycling]. However, local static variables
// will not get reinitialized because of LR in the cycle-main
// procedure." bumpCounter's "counter" is a LOCAL static variable inside
// a subprocedure (not a global definition), so this citation applies
// directly: *inlr = *on below does not reset it.
//-----------------------------------------------------------------------
runCounterDemo();

*inlr = *on;
return;

//=======================================================================
// runCounterDemo: calls bumpCounter three times WITHIN this one
// invocation and reports each result. This alone proves ordinary STATIC
// semantics (ilerpgref75.txt lines 35133-35139 cited above) - it says
// nothing about activation groups by itself. The activation-group part
// of the story (does the counter start over on the NEXT separate CALL
// PGM(F0704A), or continue?) can only be observed by running this
// program itself multiple times and comparing job logs across those
// separate invocations - see the "HOW TO OBSERVE" note in the header.
//=======================================================================
dcl-proc runCounterDemo;
  dcl-pi *n;
  end-pi;

  dcl-s msgText char(200);
  dcl-s i       int(5);
  dcl-s v       packed(5:0);

  for i = 1 to 3;
    v = bumpCounter();
    msgText = 'F0704A: bumpCounter() call #' + %char(i)
                + ' in this invocation returned counter=' + %char(v)
                + ' (STATIC keyword - ilerpgref75.txt lines 35133-35139).';
    sendToJobLog(msgText);
  endfor;

  return;
end-proc;

//=======================================================================
// bumpCounter: the STATIC local variable itself. "counter" is
// initialized to 0 ONLY the first time F0704A's CURRENT ACTIVATION is
// activated (ilerpgref75.txt lines 35137-35139: "initialized when the
// program ... is first activated. It is not reinitialized again"), and
// keeps incrementing across every call made against that SAME
// activation - whether those calls come from within one runCounterDemo
// invocation (as below) or from separate CALL PGM(F0704A) invocations
// that happen to land in the same still-alive activation group (see the
// header's "HOW TO OBSERVE" note).
//=======================================================================
dcl-proc bumpCounter;
  dcl-pi *n packed(5:0);
  end-pi;

  // Keyword order matters: ilerpgref75.txt line 28980 ("Free-Form
  // Standalone Field Definition"): "If a data-type keyword is
  // specified, it must be the first keyword" (its own worked example,
  // line 28984-28987, shows PACKED before INZ for the same reason) - so
  // packed(5:0) must precede static/inz(0) below, not follow it.
  dcl-s counter packed(5:0) static inz(0);

  counter += 1;
  return counter;
end-proc;

//-----------------------------------------------------------------------
// sendToJobLog: wraps QMHSNDPM, copied unchanged (in shape and in the
// choice of '*INFO' over the reference's own '*ESCAPE' example) from
// src/qrpglesrc/f0609s.rpgle - see that file's own header comment for
// the same note on '*INFO' not being directly shown in
// ilerpgref75.txt's worked example.
//-----------------------------------------------------------------------
dcl-proc sendToJobLog;
  dcl-pi *n;
    msg char(200) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);

  qmhsndpm('CPF9898' : msgFile : msg : %len(%trimr(msg))
             : '*INFO' : '*' : 0 : msgKey : errCode);
end-proc;
