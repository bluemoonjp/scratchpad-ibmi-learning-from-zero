**FREE
//=======================================================================
// JUCUTL (real object name: M0701B) - NOMAIN utility module (Part 7,
// lesson 07-01).
//
// NAMING: this source file's own name (jucutl.rpgle) does NOT match the
// real module object name it compiles to (M0701B). This mismatch is
// intentional and is called out explicitly in part07-design-v1.md
// section 0.2/0.3: JUCUTL is a business nickname used only in lesson
// text and in comments, not a persistent feature name (unlike JUCSRV in
// 07-02, which the design doc's naming table marks as a genuinely
// reused, cross-lesson object). Because JUCUTL is scoped to this one
// lesson, style-guide.md's type+part+lesson+sequence rule applies to
// the real object name: M0701B ("M" = module, part 07, lesson 01,
// sequence B - the second object of the pair, after main module
// M0701A). See docs/style-guide.md's object-naming section and
// docs/appendix/e-naming.md for the two naming registers this repo
// uses, and part07-design-v1.md section 0.2 for the specific YES/NO
// test applied to JUCUTL ("does this object persist across lessons?" -
// NO for JUCUTL, so it gets a type-coded name; YES for JUCSRV/ZAISRV/
// JUYAKL, so those keep their feature names as real object names).
//
// WHAT THIS MODULE IS: a NOMAIN module - one or more subprocedures with
// NO main procedure at all (ctl-opt nomain below). This is the first
// consolidation, in this whole repo, of logic that Part 6 had to
// duplicate: F0605A's calcTaxTotal (R0402A's tax-inclusive total) and
// F0605A's/F0606A's sendMsg (a job-log observation channel used because
// DSPLY defaults to QSYSOPR for a batch job - see f0605s.rpgle's own
// "Why not DSPLY" header note, not repeated in full here). calcTaxTotal
// is ported UNCHANGED from src/qrpglesrc/f0605s.rpgle (lines 211-228).
// sendMsg's own IMPLEMENTATION changed on all three files (F0605A/
// F0606A/here) after this module's own real-hardware connection found
// its original QCMDEXC/SNDPGMMSG body categorically broken - see the
// FIXED note further down, at the current sendMsg. Its call signature
// (text char(60) const) is unchanged, so this remains a faithful port
// from the caller's point of view - here is logic that was duplicated
// in Part 6, now properly modularized instead of reinvented.
//
// NOMAIN and CRTBNDRPG: ilerpgref75.txt lines 25473-25480 state, of the
// NOMAIN keyword: "It also means that the module in which it is coded
// cannot be a program-entry module. Consequently, if NOMAIN is
// specified, then you cannot use the CRTBNDRPG command to create a
// program. Instead you must either use the CRTPGM command to bind the
// module with NOMAIN specified to another module that has a program
// entry procedure or you must use the CRTSRVPGM command." This module
// is bound with CRTPGM in this lesson (07-02 will show the CRTSRVPGM
// alternative). Because CRTBNDRPG is categorically impossible for a
// NOMAIN module, this file has NO /IF DEFINED(*CRTBNDRPG) ctl-opt block
// at all - unlike m0701s.rpgle, where that idiom documents "this would
// still work if someone compiled the main module alone with CRTBNDRPG."
// For jucutl.rpgle that condition can never be true, so such a block
// would be genuinely dead code, not merely inactive under this lesson's
// chosen build path.
//
// TWO-STAGE BUILD (see m0701s.rpgle's header for the fuller
// explanation of why, and the exact CRTRPGMOD/CRTPGM commands):
//   CRTRPGMOD MODULE(<USER>1/M0701B) SRCFILE(<USER>1/QRPGLESRC)
//     SRCMBR(JUCUTL)
//   (then CRTPGM binds this module together with M0701A - see
//   m0701s.rpgle)
//
// EXPORT and the self-include of jucutlp.rpgleinc: this module both
// EXPORTs calcTaxTotal/sendMsg (ilerpgref75.txt lines 38494-38503: "The
// specification of the EXPORT keyword allows the procedure to be
// called by another module in the program... If the EXPORT keyword is
// not specified, the procedure can only be called from within the
// module") and /includes the same jucutlp.rpgleinc prototypes that
// m0701s.rpgle (the caller) also includes. See jucutlp.rpgleinc's own
// header for the full discussion of why this is RECOMMENDED (an
// explicit Tip in ilerpgref75.txt) rather than strictly REQUIRED by the
// compiler - the practical effect here is that the compiler checks
// calcTaxTotal's and sendMsg's actual dcl-pi against this member's own
// declared "public" signature, not just the caller's copy of it.
//
// STATUS: hardware-UNTESTED (Part 7 draft; Part 6, which this logic is
// ported from, is itself not yet hardware-verified - SSH to PUB400 is
// rate-limited as of 2026-09-26). Treat every runtime claim here as
// "should work per the ILE RPG Language Reference", not a verified
// fact.
// FIXED (part07-01-modules, 2026-09-26, real-hardware CRTPGM/CALL):
// sendMsg's original QCMDEXC/SNDPGMMSG body failed with CPD0031
// ("Command SNDPGMMSG not allowed in this setting"). This was NOT the
// "call depth" risk this note used to flag - confirmed against
// QCMDEXC's own IBM Docs page (rbam6/execp.htm): "commands that can
// only be used in CL procedures or programs cannot be run by the
// QCMDEXC program," and SNDPGMMSG's own reference page states its
// allowed environments as "Compiled CL program or interpreted REXX"
// only - never RPG, at ANY call depth, via QCMDEXC or otherwise. This
// means F0605A/F0606A's own direct (one-level) use of the same pattern
// is equally broken, not just this module's deeper nesting - both
// already flagged their own risk correctly, just not this precisely.
// Replaced with QMHSNDPM (Send Program Message API), the same
// technique already hardware-confirmed in this repo's T0LAD ladder
// (verify/part06-gen-probe) and already used directly (no QCMDEXC) in
// this same Part's F0702A-F0704A (07-02/07-03/07-04). CURRICULUM NOTE
// for whoever writes 06-05/06-06's lesson prose (P4): work/design/
// part06-design-v1.md places QMHSNDPM as new syntax first introduced in
// 06-09, and SND-MSG as first introduced in 06-11 (f0611s.rpgle's own
// header) - using QMHSNDPM here (07-01, which claims to port F0605A/
// F0606A's sendMsg "unchanged") means F0605A/F0606A must ALSO switch to
// QMHSNDPM (done - see their own files), which surfaces QMHSNDPM before
// its planned 06-09 slot. This is a real curriculum-sequencing question
// this fix does not resolve on its own; flag it for the design-review
// panel before finalizing 06-05/06-06/06-09's lesson text.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference, 73451 lines):
//   NOMAIN keyword / "cannot use CRTBNDRPG... must use    lines 25471-
//     CRTPGM... or CRTSRVPGM"                              25484
//   NOMAIN Module (RPG IV Concepts overview)               lines 8830-8845
//   Free-form DCL-PROC ... EXPORT; example                 lines 4039-4050
//   EXPORT keyword definition (Procedure specification)    lines 38494-
//                                                            38503
//   /COPY or /INCLUDE (self-include Tip - see also         lines 7773-7822
//     jucutlp.rpgleinc's own header)
//   DFTACTGRP/ACTGRP ctl-opt keywords "valid only if the    lines 24185,
//     CRTBNDRPG command is used" (why this file has no      25080
//     activation-group ctl-opt at all - see m0701s.rpgle
//     for the fuller ACTGRP discussion)
//   DSPLY default queue for a batch job (why sendMsg does   line 55828
//     not use it, same reasoning as F0605A/F0606A)
//   QMHSNDPM prototype shape (copied from T0LAD01's own,     see
//     already real-hardware-confirmed declaration -          verify/part06-gen-probe/
//     verify/README.md's "P24" ladder)                       src/t0lad01.rpgle
//=======================================================================

ctl-opt nomain;

// /INCLUDE kept upper-case to match ilerpgref75.txt's own worked
// examples of this directive verbatim (lines 7773-7822) - see
// m0701s.rpgle's matching note for why directive case is not guessed.
/INCLUDE jucutlp

//-----------------------------------------------------------------------
// dcl-ds/dcl-pr for QMHSNDPM (Send Program Message API), needed only
// internally by sendMsg's own implementation below. Not part of this
// module's public interface, so declared privately here rather than in
// jucutlp.rpgleinc. Same shape as verify/part06-gen-probe/src/
// t0lad01.rpgle's own already real-hardware-confirmed declaration.
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

//=======================================================================
// calcTaxTotal: faithful, unmodified port of F0605A's subprocedure of
// the same name (src/qrpglesrc/f0605s.rpgle lines 211-228). See that
// file's own header comment for the full derivation (R0402A's C-spec
// logic: Z-ADD1580 / Z-ADD1.10 / MULT) and the primary-source citations
// for VALUE, CONST, OPTIONS(*NOPASS), and %PARMS (ilerpgref75.txt lines
// 29459-29461, 32938-33030, 48287-48412 respectively - not re-cited in
// full here since the logic, and therefore the justification for its
// syntax, is unchanged from F0605A).
//
// amount is VALUE: this procedure gets its own copy of the caller's
// argument. rate is CONST + OPTIONS(*NOPASS): read-only reference,
// optional - %PARMS below detects whether the caller actually supplied
// it.
//=======================================================================
dcl-proc calcTaxTotal export;
  dcl-pi *n packed(9:2);
    amount packed(7:2) value;
    rate   packed(3:2) const options(*nopass);
  end-pi;

  dcl-s appliedRate packed(3:2) inz(1.10);  // R0402A's RATE (Z-ADD1.10)

  if %parms >= 2;
    appliedRate = rate;
  endif;

  return amount * appliedRate;
end-proc;

//=======================================================================
// sendMsg: same call signature as F0605A's/F0606A's subprocedure of the
// same name - see this file's header FIXED note for why the body now
// calls QMHSNDPM directly instead of QCMDEXC/SNDPGMMSG (real-hardware
// CPD0031, confirmed categorically broken from RPG regardless of call
// depth).
//=======================================================================
dcl-proc sendMsg export;
  dcl-pi *n;
    text char(60) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);

  // 60, not %len(%trimr(text)): text's own full declared length - see
  // f0605s.rpgle's identical sendMsg for the full reasoning (this body
  // is ported unchanged from there, per 07-01's own teaching point).
  qmhsndpm('CPF9898' : msgFile : text : 60
             : '*INFO' : '*' : 0 : msgKey : errCode);
end-proc;
