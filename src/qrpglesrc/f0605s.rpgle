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
//   (c) QCMDEXC / SNDPGMMSG - a new, independent example (NOT the
//       Part 5 ZA0510 MOVEL-chunking technique). The command string is
//       built directly with %TRIM and string concatenation, per the
//       task instructions for this lesson. Generalized below into a
//       small sendMsg subprocedure, reused as this program's ONLY
//       observation channel (see the DSPLY note below for why).
//
// Why not DSPLY: ilerpgref75.txt line 55828 states "For a batch job, if
// no message-queue value is specified, the default is QSYSOPR" for
// DSPLY. This program is meant to run non-interactively (SSH/batch,
// same as this repo's verify/ harness), so a bare DSPLY here would
// silently send to QSYSOPR - exactly what style-guide.md's "PUB400
// etiquette" section forbids (no SNDMSG to QSYSOPR/other users).
// SNDPGMMSG via QCMDEXC is used instead for every observable value in
// this file, with TOPGMQ(*SAME) and MSGTYPE(*INFO) specified explicitly
// - this exact combination (not *EXT) is what this repo's own verify/
// harness already relies on: verify/lib/clgen.mjs's generated CL
// wrapper (lines 106, 120, 125) sends its own step-result messages with
// `SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA(...) TOPGMQ(*SAME)
// MSGTYPE(*INFO)`, a pattern the wrapper's own comment (clgen.mjs line
// 2) says follows tools/qclsrc/txsetup.clp's already hardware-verified
// convention. That wrapper then reads the WHOLE job's log back with
// `SELECT ... FROM TABLE(QSYS2.JOBLOG_INFO('*'))` (clgen.mjs line 115)
// at its DONE/FAILSAFE labels, so a message sent this way should be
// picked up by the harness's existing VFYLOG capture with no extra
// "collect" step needed. The one difference from the harness's own
// proven usage: there, SNDPGMMSG runs directly in CL at the wrapper's
// own (outermost) call level; here, it runs one call level deeper,
// from inside a CALLed RPG program, via QCMDEXC rather than directly
// from CL. That specific combination is NOT yet hardware-verified -
// see the TODO below.
//
// STATUS: hardware-UNTESTED (Part 6 draft; SSH access is rate-limited
// as of this writing, 2026-09-26). This source has not been compiled
// or run on PUB400 yet. Treat every runtime claim below as "should
// work per the ILE RPG Language Reference", not as a verified fact.
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
//   QCMDEXC prototype (exact primary-source    lines 52625-52648
//     worked example - "Figure 275. Calling    (this is the reference's
//     a Prototyped Program Using CALLP")       OWN example for QCMDEXC,
//                                               not a guess)
//   %CHAR (numeric to character)               lines 44254-44306
//   DSPLY default queue for a batch job        line 55828 (why DSPLY
//                                               is *not* used in this
//                                               file)
//
// Cross-checked against a second primary source, work/design/refs/
// ilerpgprogguide75.txt (the ILE RPG Programmer's Guide, a different
// manual in the same refs/ directory): its own QCMDEXC prototype
// (Figures 69 and 73, lines 13982-13990 and 14437-14445) confirms the
// same shape (cmd CONST OPTIONS(*VARSIZE), cmdlen 15P 5 CONST), though
// it declares cmd as 3000A rather than ilerpgref75.txt's 200A - both
// are valid; 200A is kept here since it comfortably fits every command
// string actually built in this file.
//
// Also grounded against this repo's own verify/ harness (not the ILE
// RPG reference, since SNDPGMMSG itself is a CL command, not an RPG
// construct):
//   TOPGMQ(*SAME) / MSGTYPE(*INFO) and the    verify/lib/clgen.mjs
//     QSYS2.JOBLOG_INFO capture technique     lines 106, 115, 120, 125
//
// TODO: verify - the harness's own SNDPGMMSG usage (cited above) is
// itself only a *convention this repo already trusts* (inherited from
// tools/qclsrc/txsetup.clp), not something confirmed by a primary
// source in work/design/refs/ - SNDPGMMSG is not documented in either
// cl_commands_75.txt or ilerpgprogguide75.txt in that directory (both
// checked, zero matches). More importantly, this file calls SNDPGMMSG
// one call level deeper than the harness's own proven usage (from
// inside a CALLed RPG program via QCMDEXC, not directly from the CL
// wrapper), which has not been hardware-verified. Confirm with an
// actual V1/V2 run, and adjust TOPGMQ if messages sent from this depth
// do not show up in QSYS2.JOBLOG_INFO.
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
// dcl-pr / EXTPGM: a prototype for the system API QCMDEXC. Copied
// exactly (types and lengths) from ilerpgref75.txt's own worked example
// at "Figure 275. Calling a Prototyped Program Using CALLP" (approx.
// lines 52637-52644). This is a system API, not an RPG IV language
// feature, but this exact declaration is the reference's own text, so
// no TODO: verify is needed for the prototype shape itself.
//-----------------------------------------------------------------------
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd    char(200) options(*varsize) const;
  cmdlen packed(15:5) const;
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
// DSPLY" note in the header). Builds one SNDPGMMSG command with %TRIM
// and string concatenation and runs it through QCMDEXC - this is task
// (c) for this lesson, generalized into a small subprocedure so every
// demonstrated value in this program can be observed the same, safe
// way instead of repeating the command-building code three times.
//=======================================================================
dcl-proc sendMsg;
  dcl-pi *n;
    text char(60) const;
  end-pi;

  dcl-s cmdString char(200);

  // '' inside a string literal is how RPG IV escapes a literal single
  // quote inside a character constant. TOPGMQ(*SAME)/MSGTYPE(*INFO)
  // match this repo's own verify/ harness convention exactly (see the
  // header comment above) rather than being invented here.
  cmdString = 'SNDPGMMSG MSG(''' + %trim(text)
    + ''') TOPGMQ(*SAME) MSGTYPE(*INFO)';
  // The full declared length (200), not %len(%trim(cmdString)): CL
  // command parsing tolerates trailing blank padding after a complete
  // command, and this keeps the BIF list in this file to exactly what
  // task (c) asked for (%trim and concatenation) without also reaching
  // for %len.
  callp qcmdexc(cmdString : 200);
end-proc;
