**FREE
//=======================================================================
// F0605A - Subprocedures and prototypes (Part 6, lesson 06-05).
//
// What this replaces / connects to (RPG III, fixed-form):
//
//   (a) R0402A (04-02, src/qrpgsrc/r0402s.rpg) - tax-inclusive total,
//       Z-ADD1580/Z-ADD1.10/MULT logic ported into a dcl-proc
//       subprocedure. Verify: 1580 x 1.10 = 1738.00 (04-02, hardware-
//       verified 2026-09-25, see docs/part04/04-02-c-spec-arithmetic.md).
//
//   (b) R0409A (04-09, nickname ZAHIK3, src/qrpgsrc/r0409s.rpg) - stock
//       allocation with CHAIN + UPDAT record locking. Called here
//       through a dcl-pr extpgm prototype and CALLP.
//       IMPORTANT: R0409A's own source has NO *ENTRY PLIST at all -
//       PROD ('P00001') and QTY (2) are hardcoded literals inside the
//       program (see r0409s.rpg lines 5-6). This was checked against
//       the real source, not assumed, so the prototype below is
//       intentionally parameterless. This is a DEVIATION from the
//       design note (part06-design-v1.md, 06-05) that says to "match
//       R0409A's parameter types and lengths" - R0409A has no
//       parameters to match. Fixing this properly would mean changing
//       verified Part 4 code, which is out of scope here; flagging for
//       the orchestrator to decide whether that is acceptable.
//       Side effect: calling it really decrements ZAIKOM P00001 from 45
//       to 43 (or reports SHORT if already short). Run <USER>1/TXRESET
//       afterward, same as 04-09 and 06-08 require.
//
//   (c) A job-log observation channel - a new, independent example (NOT
//       the Part 5 ZA0510 MOVEL-chunking technique). Generalized below
//       into a small sendMsg subprocedure, reused as this program's
//       ONLY observation channel (see the DSPLY note below for why).
//       FIXED (2026-09-26, real-hardware CRTBNDRPG/CALL): the task's
//       original QCMDEXC/SNDPGMMSG design (command string built with
//       %TRIM and string concatenation) is categorically broken from
//       RPG - see the FIXED note at sendMsg's own declaration below for
//       the full real-hardware finding and citations. sendMsg now calls
//       QMHSNDPM directly; %TRIM and string concatenation are still
//       exercised (building the message text passed to QMHSNDPM), so
//       this lesson's own BIF-usage point still stands.
//
// Why not DSPLY: ilerpgref75.txt line 55828 states "For a batch job, if
// no message-queue value is specified, the default is QSYSOPR" for
// DSPLY. This program is meant to run non-interactively (SSH/batch,
// same as this repo's verify/ harness), so a bare DSPLY here would
// silently send to QSYSOPR - exactly what style-guide.md's "PUB400
// etiquette" section forbids (no SNDMSG to QSYSOPR/other users).
// QMHSNDPM is used instead for every observable value in this file -
// see sendMsg's own FIXED note for why, and its real-hardware
// confirmation (verify/part06-gen-probe's T0LAD ladder, and this
// program's own connection).
//
// STATUS: hardware-UNTESTED (Part 6 draft). This source has not itself
// been compiled or run on PUB400 yet - only sendMsg's technique has
// been fixed here, based on the real-hardware finding from a sibling
// file (jucutl.rpgle/M0701B, part07-01-modules, 2026-09-26 - see that
// file's own FIXED note and docs/probes.md). This file's own connection
// is still pending (part06-0509-procs-files). Treat every other
// runtime claim below as "should work per the ILE RPG Language
// Reference", not as a verified fact.
//
// Verified against work/design/refs/ilerpgref75.txt (the real IBM i 7.5
// ILE RPG Language Reference, 73451 lines) at approximately these line
// numbers:
//   DCL-PROC / DCL-PI (subprocedure form)      lines 4039-4050, 29446,
//                                               29457-29499, 48738-48759
//   DCL-PI *N (subprocedure interface name)    lines 4046, 29434,
//                                               29483 (all subprocedure
//                                               examples use *N, not the
//                                               procedure's own name -
//                                               this file follows that)
//   VALUE / CONST parameter keywords           lines 29459-29461
//   OPTIONS(*NOPASS)                           lines 32938-33030
//                                               (Figure 135)
//   %PARMS                                     lines 48287-48412
//                                               (Figure 234)
//   DFTACTGRP(*NO) explicit ctl-opt, and why    lines 13422, 25064-25090,
//     it is required for a bound (non-EXTPGM)   25072-25074 ("any call
//     procedure call such as calcTaxTotal        operation in your
//                                                 source must call a
//                                                 program and not a
//                                                 procedure" under
//                                                 DFTACTGRP(*YES))
//   DCL-PR / EXTPGM (call to a program)        lines 29340-29368,
//                                               31307-31326, 48741
//   CALLP                                      lines 52579-52599
//   %CHAR (numeric to character)               lines 44254-44306
//   DSPLY default queue for a batch job        line 55828 (why DSPLY
//                                               is *not* used in this
//                                               file)
//   QMHSNDPM prototype shape (copied from       see verify/part06-gen-probe/
//     T0LAD01's own, already real-hardware-      src/t0lad01.rpgle
//     confirmed declaration)
//
// A program-entry dcl-pi (the free-form replacement for a fixed-form
// *ENTRY PLIST) is intentionally NOT used in this file - see the note
// next to the mainline below. That use of dcl-pi belongs to 06-12
// (the JUCINQ command CPP replacement), not this lesson.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: a prototype for calling an EXTERNAL PROGRAM
// (R0409A, nickname ZAHIK3, 04-09). Zero parameters - see the header
// comment above for why. The name is left unqualified so it resolves
// through *LIBL at run time (style-guide.md: do not hardcode library
// names in source).
//-----------------------------------------------------------------------
dcl-pr r0409a extpgm('R0409A') end-pr;

//-----------------------------------------------------------------------
// dcl-ds/dcl-pr for QMHSNDPM (Send Program Message API), needed only
// internally by sendMsg's own implementation further below. Same shape
// as verify/part06-gen-probe/src/t0lad01.rpgle's own already
// real-hardware-confirmed declaration. See sendMsg's own FIXED note for
// why this replaced the originally-planned QCMDEXC/SNDPGMMSG.
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
  msgKey         char(4);
  errorCode      likeds(qmhsndpmErrCode);
end-pr;

dcl-s taxTotal1 packed(9:2);
dcl-s taxTotal2 packed(9:2);

//-----------------------------------------------------------------------
// Mainline. This program takes no CL-level parameters, so it has no
// dcl-pi of its own.
//
// NOTE ON THE TWO USES OF DCL-PI: a *subprocedure's* dcl-pi
// (calcTaxTotal/sendMsg, defined below) and a *program's* entry dcl-pi
// (the free-form replacement for a fixed-form *ENTRY PLIST) are two
// different uses of the same DCL-PI keyword. This lesson only shows
// the subprocedure form; the program-entry form is 06-12's job.
//-----------------------------------------------------------------------

// (a) R0402A's tax calculation, ported into a subprocedure.
// Verify: 1580 x 1.10 = 1738.00 (04-02, hardware-verified 2026-09-25).
taxTotal1 = calcTaxTotal(1580);
sendMsg('F0605A: 1580 at default rate = ' + %trim(%char(taxTotal1)));
// TODO: verify on real hardware that taxTotal1 is actually 1738.00
// (V1/V2 not yet run for this program - see STATUS above).

// Same subprocedure, this time passing the *nopass parameter
// explicitly (a different rate), so %parms sees 2 parameters instead
// of 1 and takes the caller's rate instead of the default.
taxTotal2 = calcTaxTotal(1580 : 1.08);
sendMsg('F0605A: 1580 at rate 1.08 = ' + %trim(%char(taxTotal2)));

// (b) Call R0409A (ZAHIK3) exactly as 04-09 does on its own, but
// through a prototype and CALLP instead of a bare 5250 CALL command.
// CLEANUP: this really changes shared data (ZAIKOM P00001: 45 -> 43).
// Run <USER>1/TXRESET after trying this lesson, same as 04-09/06-08.
callp r0409a();
sendMsg('F0605A: R0409A (ZAHIK3) called via CALLP.');

*inlr = *on;
return;

//=======================================================================
// calcTaxTotal: port of R0402A's C-spec logic (Z-ADD1580 / Z-ADD1.10 /
// MULT) into a dcl-proc subprocedure.
//
// amount is VALUE: the subprocedure gets its own copy (RPG III had no
// such concept - a called RPG III subroutine/program always shared the
// caller's actual field and could change it in place).
//
// rate is CONST + OPTIONS(*NOPASS): read-only reference, and optional.
// This is the "*nopass" exercise from the design (06-05 asks the
// reader to remove OPTIONS(*NOPASS), recompile, and read the resulting
// compile-time diagnostic when calcTaxTotal is then called with only
// one argument, since a parameter that is not the last one - or is
// required - cannot simply be left off).
// TODO: verify the exact message ID once this is actually compiled;
// do not guess it here.
//=======================================================================
dcl-proc calcTaxTotal;
  dcl-pi *n packed(9:2);
    amount packed(7:2) value;
    rate   packed(3:2) const options(*nopass);
  end-pi;

  dcl-s appliedRate packed(3:2) inz(1.10);  // R0402A's RATE (Z-ADD1.10)

  // %parms: how many parameters were actually passed on *this* call.
  // RPG III had no equivalent - a called subroutine or program always
  // saw a fixed, compile-time-known parameter list, with no way to ask
  // at run time how many arguments the caller actually supplied.
  if %parms >= 2;
    appliedRate = rate;
  endif;

  return amount * appliedRate;
end-proc;

//=======================================================================
// sendMsg: this program's only observation channel (see the "Why not
// DSPLY" note in the header).
//
// FIXED (2026-09-26, real-hardware CRTBNDRPG/CALL, found via this
// module's own port into jucutl.rpgle/M0701B, part07-01-modules): the
// original body built a SNDPGMMSG command string with %TRIM and string
// concatenation and ran it through QCMDEXC. This fails with CPD0031
// ("Command SNDPGMMSG not allowed in this setting") - confirmed against
// QCMDEXC's own IBM Docs page (rbam6/execp.htm): "commands that can
// only be used in CL procedures or programs cannot be run by the
// QCMDEXC program," and SNDPGMMSG's own reference page states its
// allowed environments as "Compiled CL program or interpreted REXX"
// only - never RPG, regardless of call depth or how QCMDEXC is reached.
// Replaced with QMHSNDPM (Send Program Message API), already
// real-hardware-confirmed in this repo's T0LAD ladder
// (verify/part06-gen-probe) and already used directly in this Part's
// F0702A-F0704A (07-02/07-03/07-04). %TRIM and string concatenation are
// still exercised, just building the message text passed to QMHSNDPM
// instead of a CL command string.
//=======================================================================
dcl-proc sendMsg;
  dcl-pi *n;
    text char(60) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);

  // 60, not %len(%trimr(text)): text's own full declared length,
  // same "trailing blank padding is fine" reasoning the original
  // cmdString version used for its own literal 200 - msgData is plain
  // text, not a parsed command, so padding costs nothing and this
  // avoids reaching for a BIF this lesson does not otherwise need.
  qmhsndpm('CPF9898' : msgFile : text : 60
             : '*INFO' : '*' : 0 : msgKey : errCode);
end-proc;
