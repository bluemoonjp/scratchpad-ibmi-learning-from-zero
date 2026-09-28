**FREE
//=======================================================================
// M0701A - main module (Part 7, lesson 07-01: ILE overview and modules).
//
// GOAL OF THIS LESSON'S PAIR OF SOURCE FILES: show that a single *PGM
// object (F0701A) can be built from TWO separately compiled *MODULE
// objects - this one (M0701A, has a main procedure) and M0701B (see
// src/qrpglesrc/jucutl.rpgle, a NOMAIN utility module, business
// nickname "JUCUTL") - and prove the two are genuinely bound together,
// not just compiled side by side unused, by having M0701A actually call
// two procedures that now live only in M0701B: calcTaxTotal and
// sendMsg. Both were duplicated across F0605A and F0606A in Part 6 -
// this is the first time they are consolidated into one reusable place
// instead of copy-pasted per program.
//
// ENTRY-POINT STYLE CHOSEN: a plain cycle-main mainline (the default
// RPG program cycle - everything before the first Procedure
// specification, with *inlr = *on; return; at the end), the SAME style
// F0605A/F0606A already use, with NO program-entry dcl-pi of its own
// (this program takes no CL-level parameters). This is a deliberate
// choice over a linear-main module (ctl-opt main(...) - ilerpgref75.txt
// lines 25404-25460, "Linear Main Module"): 07-01's three new core
// concepts (per part07-design-v1.md's 07-01 entry) are (1) two-stage
// compilation, (2) only one module in a *PGM may have a main procedure,
// and (3) which side (module ctl-opt vs. CRTPGM command) actually
// decides the resulting *PGM's activation group - none of these need
// the linear-main/cycle-main distinction to teach, and reusing the
// already-familiar F0605A/F0606A mainline style keeps this lesson's new
// syntax list focused on the module/CRTPGM mechanics instead of
// introducing a second, unrelated "what kind of main procedure is this"
// concept at the same time.
//
// TWO-STAGE BUILD - CRTRPGMOD then CRTPGM, NOT CRTBNDRPG. This is the
// whole point of this lesson (contrast with every Part 6 program, which
// used the one-step CRTBNDRPG). M0701B (jucutl.rpgle) cannot use
// CRTBNDRPG at all, since it is a NOMAIN module (see that file's own
// header, citing ilerpgref75.txt lines 25473-25480) - so a consistent
// build recipe for this pair of modules requires the two-step path even
// for M0701A, which COULD have been built with CRTBNDRPG on its own:
//
//   CRTRPGMOD MODULE(<USER>1/M0701A) SRCFILE(<USER>1/QRPGLESRC)
//     SRCMBR(M0701S)
//   CRTRPGMOD MODULE(<USER>1/M0701B) SRCFILE(<USER>1/QRPGLESRC)
//     SRCMBR(JUCUTL)
//   CRTPGM PGM(<USER>1/F0701A) MODULE(M0701A M0701B) ACTGRP(*NEW)
//
// (cl_commands_75.txt: CRTRPGMOD's MODULE/SRCFILE/SRCMBR parameters,
// lines 8598-8630; CRTPGM's PGM/MODULE/ACTGRP parameters, lines 7815-
// 7930.) DSPPGM DETAIL(*MODULE) on the resulting F0701A afterward shows
// both M0701A and M0701B listed - contrast this with any single Part 6
// *PGM, which DSPPGM DETAIL(*MODULE) shows as exactly one, self-named
// module.
//
// WHY MODULE() BINDING HERE, NOT A *SRVPGM (the "copy-bind vs.
// reference-bind" contrast this lesson's design also asks for): CRTPGM
// MODULE(M0701A M0701B) copies both modules' compiled object code
// directly into F0701A - once built, F0701A does not depend on M0701B
// existing anywhere at run time; the two are bound "by copy" into one
// *PGM. This is different from calling a *SRVPGM (07-02's topic), where
// the *PGM instead keeps a live, resolved-at-call-time REFERENCE to a
// separate, independently existing *SRVPGM object via *LIBL or a
// binding directory. Both are legitimate ILE binding strategies; this
// lesson only shows the first.
//
// ACTIVATION GROUP: THE CRTPGM COMMAND DECIDES, NOT EITHER MODULE'S
// CTL-OPT. This is the single most important correction this lesson's
// design went through (part07-design-v1.md section 2, the 07-01 entry's
// critique-found note - section 0.3 is about naming, not this point).
// Verified directly against the primary source, not assumed:
//   - ilerpgref75.txt line 24185: "The ACTGRP keyword is valid only if
//     the CRTBNDRPG command is used."
//   - ilerpgref75.txt line 25080: "The DFTACTGRP keyword is valid only
//     if the CRTBNDRPG command is used."
// Since this module is compiled with CRTRPGMOD (whose own parameter
// table has no ACTGRP or DFTACTGRP parameter at all - checked by
// grepping the ENTIRE CRTRPGMOD command section of cl_commands_75.txt,
// lines 8584-9813, i.e. up to the next command heading, CRTBNDDIR, not
// just its first few parameters: zero matches), any ctl-opt
// actgrp(*new)/dftactgrp(*no) written directly in this source is, at
// minimum, not honored as an activation-group setting for the eventual
// F0701A program the way it would be under CRTBNDRPG.
// TODO: verify - this session could not confirm, from either
// ilerpgref75.txt or cl_commands_75.txt, whether CRTRPGMOD silently
// ignores an ACTGRP/DFTACTGRP ctl-opt keyword or rejects it with a
// compile-time diagnostic (both references say the keywords are "valid
// only if the CRTBNDRPG command is used" but do not say what happens
// under CRTRPGMOD specifically). This matters for what a learner would
// actually see if they deleted the /IF DEFINED(*CRTBNDRPG) wrapper
// below and compiled anyway - confirm with an actual CRTRPGMOD run.
// Either way, the resulting F0701A program's real activation group is
// decided solely by the explicit ACTGRP(*NEW) on the CRTPGM command
// shown above, never by this module's own ctl-opt - that is the point
// this lesson teaches regardless of how the answer above resolves.
//
// The reference's own recommended idiom for this exact situation
// (ilerpgref75.txt lines 7976-7999, the *CRTBNDRPG condition example)
// is to wrap such keywords in /IF DEFINED(*CRTBNDRPG). That idiom is
// used below to illustrate the pattern itself, as this lesson's design
// asks for - but it is NOT a claim that this file could usefully be
// compiled standalone with CRTBNDRPG today: M0701A only IMPORTS
// calcTaxTotal/sendMsg (via the /include below), it does not define
// them, so a standalone CRTBNDRPG would still need to resolve those
// bound-call imports to some export, and neither M0701B nor a binding
// directory supplying them exists yet at this point in the lesson
// (cl_commands_75.txt's CRTPGM "Resolving References (Imports)"
// section, lines 8291-8300, and the analogous CRTBNDRPG binding
// behavior described at lines 6115 onward, "Binding directory
// (BNDDIR)"). Until 07-02 introduces a *SRVPGM/*BNDDIR that could
// supply these exports, this /IF DEFINED(*CRTBNDRPG) block is
// genuinely dead code under any build path actually usable today - the
// same situation jucutl.rpgle's header describes for why THAT file has
// no such block at all, except that here the block is at least
// reachable in principle once 07-02's JUCSRV/JUCSRVBD exist.
// Omitting ACTGRP on CRTPGM would default to ACTGRP(*ENTMOD), which
// (cl_commands_75.txt lines 8221-8225) resolves an RPGLE program-entry
// module to the shared QILE activation group (or QILETS, if
// STGMDL(*TERASPACE) were in effect) - NOT a new, isolated one - which
// is why this lesson's CRTPGM command spells ACTGRP(*NEW) out
// explicitly rather than relying on the default.
//
// CROSS-MODULE CALLS: calcTaxTotal and sendMsg are declared via the
// /include below (jucutlp.rpgleinc), the SAME copy member M0701B itself
// includes, per ilerpgref75.txt's own Tip on placing exported-procedure
// prototypes in a shared member (lines 7818-7822, discussed fully in
// jucutlp.rpgleinc's header). Neither prototype uses EXTPGM/EXTPROC:
// this is a prototype for a BOUND call to a procedure living in another
// module of the same *PGM, resolved when CRTPGM binds M0701A and M0701B
// together - not a call to a separate *PGM object (contrast with
// F0605A's own r0409a prototype, EXTPGM('R0409A'), a real external
// program call). Per ilerpgref75.txt lines 48121-48124, when EXTPROC is
// not specified the bound call's entry point is simply the prototype
// name in upper case - here, CALCTAXTOTAL and SENDMSG, matching the
// EXPORT'ed procedure names in jucutl.rpgle exactly.
//
// STATUS: hardware-UNTESTED (Part 7 draft; Part 6, which calcTaxTotal
// and sendMsg's logic is ported from, is itself not yet hardware-
// verified - SSH to PUB400 is rate-limited as of 2026-09-26). Treat
// every runtime claim below as "should work per the ILE RPG Language
// Reference", not a verified fact.
// TODO: verify - 1580 x 1.10 = 1738.00 is independently trustworthy
// (R0402A, 04-02, hardware-verified 2026-09-25), but the sendMsg calls
// below add one more level of call depth on top of F0605A's own
// already-untested QCMDEXC-from-a-called-program combination (M0701A
// -> bound call into M0701B -> QCMDEXC) - confirm with an actual V1/V2
// run before treating any message text as observed fact.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference, 73451 lines):
//   *CRTBNDRPG/*CRTRPGMOD condition idiom, and the           lines 7976-7999
//     recommended /IF DEFINED(*CRTBNDRPG) H DFTACTGRP(*NO)
//     pattern this file's ctl-opt block follows
//   ACTGRP ctl-opt keyword, "valid only if the CRTBNDRPG        line 24185
//     command is used"
//   DFTACTGRP ctl-opt keyword, "valid only if the CRTBNDRPG     line 25080
//     command is used"
//   NOMAIN Module / Linear Main Module overview (why       lines 8600-8618,
//     cycle-main was chosen here over MAIN(...))              25404-25484
//   /COPY or /INCLUDE (self-include Tip, shared with        lines 7773-7822
//     jucutlp.rpgleinc)
//   DCL-PR free-form prototype for a bound procedure       lines 29340-29368
//     call (no EXTPGM/EXTPROC)
//   Bound-call default entry point = prototype name in     lines 48121-48124
//     upper case, when EXTPROC is not specified
//   %CHAR (numeric to character), reused from F0605A/       lines 44254-44306
//     F0606A
//
// Also grounded against work/design/refs/cl_commands_75.txt (CL command
// reference, added to this repo's refs/ during Part 7's design phase -
// see part07-design-v1.md section 0.4):
//   CRTRPGMOD: MODULE/SRCFILE/SRCMBR parameters               lines 8598-8630
//   CRTPGM: PGM/MODULE/ACTGRP parameters                      lines 7815-7930
//   ACTGRP(*ENTMOD) resolving an RPGLE program-entry          lines 8221-8225
//     module to the shared QILE activation group
//=======================================================================

// Compiler directives (/IF, /INCLUDE, /ENDIF) are kept upper-case below
// to match every worked example of these directives in ilerpgref75.txt
// verbatim (e.g. lines 7976-7999, 7773-7822) - unlike RPG keyword
// statements (ctl-opt, dcl-pr, ...), which this repo writes lower-case
// per this file's own style, directive case was not something this
// session found an explicit "not case sensitive" statement for, so the
// primary source's own casing is followed here rather than guessed.
/IF DEFINED(*CRTBNDRPG)
ctl-opt dftactgrp(*no) actgrp(*new);
/ENDIF

/INCLUDE jucutlp

dcl-s taxTotal1 packed(9:2);
dcl-s taxTotal2 packed(9:2);

//-----------------------------------------------------------------------
// Mainline (cycle-main). Calls calcTaxTotal and sendMsg - both now
// living only in M0701B - to prove the two modules are actually bound
// together, not merely compiled side by side. Same worked values as
// F0605A's own mainline (src/qrpglesrc/f0605s.rpgle lines 173-182):
// 1580 at the default rate (1.10) and 1580 at an explicit rate (1.08).
//-----------------------------------------------------------------------

taxTotal1 = calcTaxTotal(1580);
sendMsg('M0701A: 1580 at default rate = ' + %trim(%char(taxTotal1)));
// TODO: verify on real hardware that taxTotal1 is actually 1738.00, and
// that this message is actually observable (see STATUS above).

taxTotal2 = calcTaxTotal(1580 : 1.08);
sendMsg('M0701A: 1580 at rate 1.08 = ' + %trim(%char(taxTotal2)));

sendMsg('M0701A: calcTaxTotal/sendMsg ran via M0701B.');

*inlr = *on;
return;
