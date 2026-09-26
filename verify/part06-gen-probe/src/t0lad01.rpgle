**FREE
//=======================================================================
// T0LAD01 - P24 feature-ladder rung 1 of 12: **FREE only.
//
// This is the FIRST rung of a CUMULATIVE ladder (work/design/final_probes.json
// "P24"): T0LAD02 = this file + DIM(*AUTO), T0LAD03 = T0LAD02 +
// FOR-EACH/%LIST/IN, ... through T0LAD12 (ASSERT-T, also built as a
// separate SQLRPGLE compile, T0LAD12Q). Each rung keeps 100% of the
// previous rung's source unchanged and adds exactly one new block, so a
// compile failure on rung N points at rung N's new feature specifically,
// not at anything inherited from an earlier rung. See
// verify/part06-gen-probe/manifest.json's "description" field for the
// full rationale, the per-feature ilerpgref75.txt verification citations,
// and PTF/version findings (several of these features carry an explicit
// "compile-time PTF" date in the reference itself, which is the whole
// point of this probe).
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference, 73451 lines):
//   **FREE (fully free-form source)     lines 3810-3813, 3957-3959,
//                                        7531-7535, 23203-23207,
//                                        23280-23297 ("**FREE may only be
//                                        specified in column 1 of the
//                                        first line... the entire source
//                                        member must be free-form")
//
// Observability deviation from the task's literal "QSYSPRT + EXCPT"
// instruction, and why:
//   **FREE has NO fixed-form specs at all once the **FREE directive is
//   used (ilerpgref75.txt lines 23280-23297 above), which means NO
//   O-specs. The classic OPM/fixed-form EXCPT pattern this repo already
//   uses in verify/part05-gen-probe/src/t0eds.rpg depends entirely on
//   O-specs to define the exception-output record - there is no
//   free-form equivalent of EXCPT's own record-definition mechanism.
//   (WRITE to a program-described printer file IS possible in free-form
//   per ilerpgref75.txt lines 66331-66348 - "If name refers to a program
//   described file, the data structure is required and can be any data
//   structure of the same length as the file's declared record length" -
//   but this repo's OWN existing Part 6 **FREE lesson sources already
//   picked a different, already-verified mechanism for this exact
//   problem: src/qrpglesrc/f0605s.rpgle and f0609s.rpgle send messages to
//   the job log via the QMHSNDPM API, explicitly because DSPLY only
//   works from an interactive job. Every rung of this ladder reuses that
//   exact pattern (same prototype shapes, copied verbatim from
//   f0609s.rpgle, which cites ilerpgref75.txt lines 13744-13773 for the
//   QMHSNDPM prototype shape and lines 29060-29072 for the PSDS-adjacent
//   template style used here for the message-file/error-code DS's).
//
//   This also has a concrete benefit for THIS harness specifically:
//   verify/lib/clgen.mjs runs each rung's CALL step inside the CL
//   wrapper's OWN job (via `system "CALL PGM(...)"`), and that wrapper
//   already dumps its own job log to a persistent VFYLOG table and
//   SELECTs it automatically at the end of every connection (see
//   verify/README.md). So every QMHSNDPM/SND-MSG message a rung sends
//   is captured for free, with no extra `collect` step and no dependency
//   on the still-unverified SYSTOOLS.SPOOLED_FILE_DATA path that spooled
//   printer output would have required.
//
// FIXED (part06-gen-probe, 2026-09-26, real-hardware CRTBNDRPG, 3 real
// bugs found across 3 connections - applied to all 13 files in this
// ladder, T0LAD01-12/12Q, which all copy this same QMHSNDPM/
// sendToJobLog block):
//   1. Missing the ctl-opt line below. Without it, DFTACTGRP defaults
//      to *YES, and PUB400 rejected every rung with RNF1520 ("The
//      procedure cannot be defined with DFTACTGRP(*YES)") - a dcl-proc
//      is not allowed in the default activation group. f0609s.rpgle
//      (this file's own cited QMHSNDPM source) already has this exact
//      line; it was simply dropped when copied here.
//   2. Wrong section order: dcl-proc sendToJobLog sat BEFORE the
//      mainline code, not after it. ilerpgref75.txt's own "RPG IV
//      Concepts" chapter (~line 8266) is explicit: "Main source
//      section: the source lines from the first line...up to the
//      first Procedure specification" and "A subprocedure is a
//      procedure defined AFTER the main source section" - i.e. once a
//      Procedure-Begin (dcl-proc) appears, everything from there on is
//      part of the procedure section, so mainline statements placed
//      after end-proc are rejected (RNF0256 "Specification found
//      between procedures", cascading to RNF7023 "Compiler cannot
//      determine how the program can end"). This was NOT just a
//      cascade of bug 1 - fixing ctl-opt alone (2nd connection) left
//      RNF0256/RNF7023 unchanged. f0609s.rpgle already has the correct
//      order (mainline, then *inlr/return, then its dcl-procs); moved
//      sendToJobLog's dcl-proc/end-proc block to the end of every file
//      here to match.
//   3. Wrong statement order WITHIN the mainline itself: each rung's
//      new dcl-s/dcl-ds/dcl-c/dcl-enum was interleaved among earlier
//      rungs' executable statements (e.g. rung 2's "dcl-s ladArr..."
//      sat right after rung 1's sendToJobLog() call), not grouped
//      before them. RNF0724 ("The statement type is out of sequence
//      for the main procedure") at rung 2's dcl-s line, on the 3rd
//      connection (after bugs 1-2 were fixed) - the real-hardware
//      RNF0724 itself is the primary evidence. Confirmed against
//      ilerpgref75.txt lines 23082-23096, Table 99 ("Source Records
//      and Their Order in an RPG IV Source Program"): "The RPG IV
//      source must be entered into the system in the order shown in
//      Table 99" - for the Main Source Section, that order is Control,
//      then File Description/Definition, then Input, then Calculation,
//      then Output; "Fully free-format specifications are allowed for
//      Control, File Description, Definition, and Procedure
//      statements" (~line 23071-23073), i.e. free-form keeps the same
//      section order, just without fixed-column spec letters -
//      Definition (declarations) before Calculation (executable
//      statements). (An earlier draft of this note cited
//      ilerpgprogguide75.txt line 34326, which is actually about
//      CVTRPGSRC placing a /COPY member's converted D-specs below an
//      existing I-spec, not about this rule - corrected.) Reordered
//      every rung's file so ALL of its accumulated declarations come
//      first, then ALL of its accumulated executable statements, then
//      the *inlr/return closer, then the sendToJobLog procedure.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

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
  msgKey         char(4);
  errorCode      likeds(qmhsndpmErrCode);
end-pr;


sendToJobLog('T0LAD01: **FREE rung compiled and ran.');

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
