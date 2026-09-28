**FREE
//=======================================================================
// F0609A - Exception handling with MONITOR/ON-ERROR/ON-EXIT (Part 6,
// lesson 06-09).
//
// What this replaces / connects to (RPG III, fixed-form):
//
//   R0412A (04-12, src/qrpgsrc/r0412s.rpg, hardware-verified 2026-09-25,
//   see docs/part04/04-12-debugging-runtime-errors.md) protected a
//   division by zero by CHECKING THE DIVISOR FIRST:
//       C           ZERO      COMP 0                        60
//       C  N60      NUM       DIV  ZERO      ANSWER  30
//       C   60                MOVEL'DIV0ERR' MSG    10
//   ("forbid the dangerous operation from ever running" - RPG III had no
//   way to run the DIV and recover afterward; result indicators on DIV
//   only report the SIGN of the result and do not prevent RPG0102).
//
//   This file ports the SAME numbers (NUM=10, ZERO=0, matching R0412A's
//   Z-ADD10/Z-ADD0) to the OPPOSITE strategy: let the division run
//   inside a MONITOR group, and catch the resulting error in an
//   ON-ERROR block instead of pre-checking the divisor. Per the design
//   (work/design/part06-design-v1.md, 06-09 section), the *primary*
//   worked example for this lesson is this single-session zero-division
//   case, NOT the R0409A/ZAHIK3 two-session record-lock scenario (that
//   was demoted to a manual 5250x2 exercise outside the automated
//   verify/ pipeline - see the design doc's 06-09 section and its note
//   on why the two-session record-lock scenario cannot be reproduced by
//   the verify/ harness: a single connection, a single sequential job).
//
//   WHAT IS ACTUALLY NEW HERE (corrected from an earlier draft of this
//   comment): RPG III (RPG/400) ALSO had a program status data
//   structure with the same predefined layout (STATUS at 11-15, the
//   failing statement number at 21-28, ROUTINE at 29-36) - see
//   work/design/refs/rpg400ref.txt lines 3368-3465. So a PSDS itself is
//   NOT new. What IS new is that RPG III could only read its PSDS
//   inside *PSSR, a single global error subroutine for the WHOLE
//   program; RPG IV's MONITOR/ON-ERROR lets a handler be scoped to one
//   small block of code, right at the point of risk, matching the
//   design's core concept (1) for this lesson.
//
// Why SNDPGMMSG/QMHSNDPM and NOT DSPLY:
//   DSPLY can only be CALLed from an interactive job (see final_policy.md
//   and 06-05's f0605s.rpgle, which flags this same limitation in a
//   TODO next to its own DSPLY calls). This lesson's V2 verification
//   runs non-interactively (SSH/batch), so the caught error is
//   reported to the JOB LOG via the QMHSNDPM API instead - this is a
//   hard design requirement for this file, not a style preference.
//
// PSDS (program status data structure):
//   Declared below to show that a MONITOR/ON-ERROR handler can inspect
//   predefined PSDS subfields to report WHICH operation/line failed and
//   with what status code, from inside the handler itself.
//
// ON-EXIT and why the demo logic lives in a subprocedure:
//   ilerpgref75.txt line 61187-61189 explicitly states: "ON-EXIT is not
//   allowed in a cycle-main procedure. Move the logic for the
//   cycle-main procedure into another procedure that is called by the
//   cycle-main procedure, ...". This file's mainline is a plain
//   cycle-main procedure (see the program-entry dcl-pi note below), so
//   the MONITOR/ON-ERROR/ON-EXIT demonstration lives in an ordinary
//   subprocedure, runDivideDemo, called once from the mainline.
//
// STRDBG / STRSRVJOB (V3, NOT exercised by this source file):
//   STRDBG PGM(...) and STRSRVJOB are interactive-only debugging tools.
//   Per style-guide.md's V1/V2/V3 scheme, they are V3 (5250 interactive
//   operation) and will be covered in this lesson's prose (the
//   docs/part06/06-09 page, not yet written), the same way 04-12
//   covered STRDBG as description-only. This .rpgle file does not
//   call, reference, or depend on either of them in any way.
//
// Program-entry dcl-pi: this program takes no CL-level parameters, so
// it has none (contrast with 06-12's F0612A, which does).
//
// dftactgrp(*no)/actgrp(*new): required because this file defines
// subprocedures (runDivideDemo, sendToJobLog) and calls one of them
// (sendToJobLog) from another - ilerpgref75.txt lines 25073-25074:
// under DFTACTGRP(*YES), "any call operation in your source must call
// a program and not a procedure". Matches 06-05's f0605s.rpgle, which
// needed the same option for the same reason.
//
// STATUS: CONFIRMED (part06-0509-procs-files, 2026-09-27): CRTBNDRPG
// Highest Severity 00, CALL produced the expected sequence -
// "Attempt made to divide by zero for fixed point operation." (the
// underlying MCH1211-class exception text) -> "F0609A: caught status
// 102 in F0609A at line/stmt 00023600 - division by zero was caught,
// not pre-checked." -> "F0609A: runDivideDemo ended normally
// (MONITOR/ON-ERROR already handled any error)." - MONITOR/ON-ERROR
// correctly caught the zero-divide and let the program end normally
// (V2, confirmed by reading the connection's raw run-section text).
// See docs/probes.md's part06-0509-procs-files section. This confirms
// only the MONITOR/ON-ERROR path (the lesson's primary exercise) - the
// STRDBG/STRSRVJOB and 2-session lock-competition material described
// below remains V3 (interactive-only), per this lesson's own design.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference, 73451 lines) at approximately these line numbers:
//   MONITOR (Begin a Monitor Group)             line 58399 (definition),
//                                                lines 41087-41156
//                                                (worked example with
//                                                ON-ERROR 1216 / 121 /
//                                                *ALL blocks)
//   ON-ERROR (On Error)                         line 38874 (syntax),
//                                                same worked example
//   Status code 00102 = "Divide by zero"        lines 12843-12844
//                                                (Program Status Codes
//                                                table)
//   ON-EXIT (On Exit), incl. the cycle-main      lines 61099-61229
//     restriction and the "abnormal end"
//     indicator parameter
//   PSDS keyword (free-form)                    lines 29060-29072
//                                                ("DCL-DS pgm_stat
//                                                PSDS; status *STATUS;
//                                                routine *ROUTINE;
//                                                library CHAR(10)
//                                                POS(81); END-DS;")
//   PSDS predefined subfields (*PROC, *STATUS,   lines 12531-12621
//     *ROUTINE, and the unnamed line/statement   (Table 84: "Contents
//     -number subfield at positions 21-28,       of the Program Status
//     which has no reserved keyword and must     Data Structure")
//     be picked up with an explicit POS(21))
//   OPTION(*SRCSTMT) effect on the PSDS line-    lines 12561-12571
//     number subfield (statement number instead
//     of source line number)
//   QMHSNDPM prototype + call (worked example,   lines 13744-13773
//     "Procedure to send a generic exception")   (this is the
//                                                reference's OWN
//                                                worked example, not
//                                                a guess at the API
//                                                shape)
//   RPG III (RPG/400) also had a PSDS, with the  rpg400ref.txt, lines
//     same STATUS/statement-number/ROUTINE       3368-3465
//     layout (used to correct an earlier,
//     inaccurate draft of the comment above)
//   *ROUTINE is unreliable outside the normal    lines 12613-12616
//     RPG IV cycle (why pgmStatRtn is declared
//     but not printed - see the comment next
//     to its declaration below)
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt);

//-----------------------------------------------------------------------
// PSDS: program status data structure. *PROC/*STATUS/*ROUTINE are
// predefined subfields (the reserved word is used IN PLACE OF a
// data-type keyword, per ilerpgref75.txt around line 29062-29063 - no
// separate CHAR/ZONED type is coded for them). The failing
// statement/line number (positions 21-28 in the PSDS layout, Table 84)
// has NO reserved keyword of its own, so it is picked up with an
// explicit POS(21) and an explicit CHAR(8) type, exactly the way the
// reference's own example picks up a non-keyword subfield with
// CHAR(10) POS(81) for "library".
//
// pgmStatRtn (*ROUTINE) is declared but deliberately NOT printed by
// sendToJobLog below: ilerpgref75.txt lines 12613-12616 state
// "*ROUTINE is not valid unless you use the normal RPG IV cycle" and
// that logic taking the program out of the normal cycle "may cause
// *ROUTINE to reflect an incorrect value". This program's error
// actually happens inside an ordinary subprocedure (runDivideDemo),
// not the cycle-main routines *ROUTINE enumerates (*INIT/*DETL/etc.),
// so its value here would not be trustworthy - kept only to show the
// full predefined-subfield shape, not used in the reported message.
//-----------------------------------------------------------------------
dcl-ds pgmStat psds;
  pgmStatProc *proc;
  pgmStatSts  *status;
  pgmStatLine char(8) pos(21);
  pgmStatRtn  *routine;   // declared for completeness, NOT reported
end-ds;

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: prototype for the QMHSNDPM ("Send Program Message")
// API, copied field-for-field from ilerpgref75.txt's own worked example
// (lines 13744-13773, procedure "sendException"). This is a system API,
// not an RPG IV language feature, so this exact shape is taken directly
// from the reference rather than guessed at.
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
  msgKey         char(4) const;   // CONST here, exactly as coded in the
                                   // reference's own prototype (line
                                   // 13767) for this API - not something
                                   // this file changed or guessed at.
  errorCode      likeds(qmhsndpmErrCode);
end-pr;

//-----------------------------------------------------------------------
// Mainline. Plain cycle-main procedure (everything up to the first
// Procedure specification/dcl-proc - ilerpgref75.txt line 8660): no
// program-entry dcl-pi (this program takes no parameters), and no
// MONITOR/ON-ERROR/ON-EXIT logic directly here (ON-EXIT is not allowed
// in a cycle-main procedure - see the header comment above), so the
// mainline is a single call into runDivideDemo.
//-----------------------------------------------------------------------
runDivideDemo();

*inlr = *on;
return;

//=======================================================================
// runDivideDemo: the MONITOR/ON-ERROR/ON-EXIT demonstration itself.
// Ordinary subprocedure (not the mainline), so it is allowed to have an
// ON-EXIT section (ilerpgref75.txt line 61187-61189 forbids ON-EXIT in
// a cycle-main procedure specifically).
//=======================================================================
dcl-proc runDivideDemo;
  dcl-pi *n;
  end-pi;

  dcl-s num    packed(3:0) inz(10);   // R0412A's NUM (Z-ADD10)
  dcl-s zero   packed(3:0) inz(0);    // R0412A's ZERO (Z-ADD0) - deliberate
  dcl-s answer packed(3:0);           // R0412A's ANSWER (same 3,0 length)
  dcl-s msgText char(200);
  dcl-s abnormalEnd ind;              // ON-EXIT's status indicator

  // NOTE: %CHAR and %TRIMR are formally introduced as new syntax in
  // 06-06, not this lesson. As 06-05's f0605s.rpgle already does with
  // %TRIM/%CHAR ahead of their formal introduction, they are used here
  // ahead of that too, because building a one-line job-log message
  // needs them; nothing about MONITOR/ON-ERROR/PSDS/ON-EXIT/QMHSNDPM
  // (this lesson's actual new material) depends on that ordering.

  // R0412A's protection was "COMP 0 before DIV". Here, instead, the DIV
  // is allowed to run inside a MONITOR group, and the resulting error
  // (status 00102, "Divide by zero" - ilerpgref75.txt lines 12843-12844)
  // is caught in an ON-ERROR block.
  monitor;
    answer = num / zero;

    // Only reached if the division above did NOT fail.
    msgText = 'F0609A: ' + %char(num) + ' / ' + %char(zero)
                + ' = ' + %char(answer) + ' (no error).';
    sendToJobLog(msgText);

  on-error 102;
    // Caught exactly the way R0412A's COMP-before-DIV check prevented -
    // except here the PSDS tells us WHERE it happened, which RPG III
    // could only have told us from inside a single, whole-program
    // *PSSR subroutine (see the header comment's correction above).
    msgText = 'F0609A: caught status ' + %char(pgmStatSts)
                + ' in ' + %trimr(pgmStatProc)
                + ' at line/stmt ' + %trimr(pgmStatLine)
                + ' - division by zero was caught, not pre-checked.';
    sendToJobLog(msgText);
  endmon;

  return;

  // ON-EXIT: runs every time this procedure ends, whether normally or
  // abnormally (ilerpgref75.txt lines 61106-61121). In THIS program the
  // MONITOR/ON-ERROR block above always catches the divide-by-zero, so
  // control always reaches the RETURN above and abnormalEnd is always
  // *OFF here; abnormalEnd would only turn *ON if some OTHER, unhandled
  // exception escaped this procedure - which is exactly the case the
  // reference's own ON-EXIT example demonstrates (lines 61210-61229).
  on-exit abnormalEnd;
    if abnormalEnd;
      sendToJobLog('F0609A: runDivideDemo ended ABNORMALLY.');
    else;
      sendToJobLog('F0609A: runDivideDemo ended normally '
                     + '(MONITOR/ON-ERROR already handled any error).');
    endif;
end-proc;

//-----------------------------------------------------------------------
// sendToJobLog: wraps QMHSNDPM so runDivideDemo can log a plain message
// the same way SNDPGMMSG would from CL, without repeating the
// message-file/error-code plumbing at every call site. CPF9898 is the
// standard "send arbitrary replacement text" escape/informational
// message in QCPFMSG, used the same way ilerpgref75.txt's own example
// uses it (line 13771: "QMHSNDPM ('CPF9898' : msgFile : msg : ...)").
// callStackEntry '*' with callStackCtr 0 targets THIS procedure's own
// call stack entry, so the message lands in this job's own job log.
//
// NOTE ON '*INFO': the reference's own worked example (line 13772)
// passes '*ESCAPE' for msgType. This file uses '*INFO' instead (an
// informational message, since the error was already handled and the
// program is NOT ending), which is a well-established, widely
// documented QMHSNDPM message-type value but is NOT itself shown in
// ilerpgref75.txt's worked example - flagged here as the one part of
// this QMHSNDPM usage not directly confirmed against a primary source
// fetched into this repo.
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
