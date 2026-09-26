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
// F0605A's/F0606A's sendMsg (the QCMDEXC/SNDPGMMSG-based job-log
// observation channel used because DSPLY defaults to QSYSOPR for a
// batch job - see f0605s.rpgle's own "Why not DSPLY" header note, not
// repeated in full here). Both bodies are ported UNCHANGED from
// src/qrpglesrc/f0605s.rpgle (calcTaxTotal:
// lines 211-228; sendMsg: lines 238-257) - same computation, same
// QCMDEXC prototype and call shape, per this lesson's own teaching
// point: here is logic that was duplicated in Part 6, now properly
// modularized instead of reinvented.
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
// TODO: verify - F0605A's own header already flags that its QCMDEXC-
// based sendMsg is untested at ITS call depth (RPG program -> QCMDEXC).
// Here it goes one level deeper again (M0701A -> bound call into
// M0701B -> QCMDEXC), which is a NEW, not-yet-tested combination on top
// of an already-untested one. Confirm with an actual V1/V2 run before
// treating any sendMsg output from F0701A as observed fact.
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
//   DCL-PR / prototype for QCMDEXC (Figure 275, same        lines 52625-
//     worked example F0605A/F0606A already cite)            52648
//   DFTACTGRP/ACTGRP ctl-opt keywords "valid only if the    lines 24185,
//     CRTBNDRPG command is used" (why this file has no      25080
//     activation-group ctl-opt at all - see m0701s.rpgle
//     for the fuller ACTGRP discussion)
//   DSPLY default queue for a batch job (why sendMsg uses   line 55828
//     QCMDEXC/SNDPGMMSG instead, same reasoning as F0605A/
//     F0606A)
//=======================================================================

ctl-opt nomain;

// /INCLUDE kept upper-case to match ilerpgref75.txt's own worked
// examples of this directive verbatim (lines 7773-7822) - see
// m0701s.rpgle's matching note for why directive case is not guessed.
/INCLUDE jucutlp

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: a prototype for the system API QCMDEXC, needed only
// internally by sendMsg's own implementation below. This is NOT part of
// this module's public interface (callers of sendMsg never see or need
// QCMDEXC), so it is declared privately here rather than placed in
// jucutlp.rpgleinc - copied exactly (types and lengths) from
// ilerpgref75.txt's own worked example at "Figure 275. Calling a
// Prototyped Program Using CALLP" (approx. lines 52637-52644), same as
// F0605A/F0606A's own local copies of this same prototype.
//-----------------------------------------------------------------------
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd    char(200) options(*varsize) const;
  cmdlen packed(15:5) const;
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
// sendMsg: faithful, unmodified port of F0605A's subprocedure of the
// same name (src/qrpglesrc/f0605s.rpgle lines 238-257) - the QCMDEXC/
// SNDPGMMSG-based observation channel reused (not reinvented) here,
// with TOPGMQ(*SAME) and MSGTYPE(*INFO) matching this repo's own
// verify/ harness convention exactly, same as F0605A/F0606A (see those
// files' headers for the full justification, including the TODO:
// verify about this technique's call-depth risk, which now applies one
// level deeper still - see this file's own header above).
//=======================================================================
dcl-proc sendMsg export;
  dcl-pi *n;
    text char(60) const;
  end-pi;

  dcl-s cmdString char(200);

  cmdString = 'SNDPGMMSG MSG(''' + %trim(text)
    + ''') TOPGMQ(*SAME) MSGTYPE(*INFO)';
  callp qcmdexc(cmdString : 200);
end-proc;
