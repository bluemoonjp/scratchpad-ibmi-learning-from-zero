**FREE
//=======================================================================
// F0605B - QCMDEXC demo (Part 6, lesson 06-05). A SEPARATE object from
// F0605A (this lesson's main subprocedure/CALLP worked example) - see
// work/design/part06-design-v1.md's 06-05 entry: the lesson's own goal
// line promises the ability to call CL, RPG III, and QCMDEXC, and
// dependency probe P42 (QCMDEXC) is on this lesson's
// own list, but the QCMDEXC demo itself was displaced when the job-log
// observation channel switched from a QCMDEXC/SNDPGMMSG design to the
// direct QMHSNDPM call (sendMsg, see F0605A's own header) - restoring
// it here as its own small object keeps F0605A itself unchanged (it is
// already V2-confirmed, part06-0509-procs-files - no writer should
// edit it) and matches docs/appendix/e-naming.md section 3.1's
// convention (part+lesson+variant letter, F0605A already used).
//
// WHY QCMDEXC CANNOT DEMONSTRATE SNDPGMMSG (confirmed real bug, same
// one F0605A's own header and 07-01's header already document): IBM's
// own QCMDEXC Docs state "commands that can only be used in CL
// procedures or programs cannot be run by the QCMDEXC program", and
// SNDPGMMSG's own Docs restrict it to "Compiled CL program or
// interpreted REXX" - never RPG, at any call depth, confirmed on real
// hardware (CPD0031, docs/probes.md's part07-01-modules section).
// src/legacy/qrpgsrc/za0510.rpg (05-04, RPG III) hit the exact same
// wall and replaced its demo command with CHGDTAARA - this file reuses
// that same safe, ALLOW(*ALL) replacement command, ported to RPG IV
// free-form QCMDEXC syntax instead of RPG III's CALL/PARM opcodes.
//
// WHAT THIS DEMONSTRATES: an ordinary CALL to the system program
// QCMDEXC from **FREE RPG IV - a prototype (dcl-pr ... extpgm), a
// command-text variable, and a packed(15:5) length, exactly like
// 05-04's RPG III CALL/PARM pair but in the free-form calling
// convention 06-05 has just introduced. The command run is
// CHGDTAARA DTAARA(*LDA (21 20)) VALUE('F0605B OK') - a different
// *LDA byte range from 05-04's own za0510.rpg (bytes 1-20), so the two
// lessons' demos cannot overwrite each other's flag if run in the same
// job. DSPDTAARA DTAARA(*LDA) afterward shows the new value as real,
// inspectable evidence that the call actually ran (same reasoning
// za0510.rpg's own header gives for preferring this over SNDPGMMSG,
// which never gave inspectable proof of delivery either).
//
// STATUS: NOT YET COMPILED (draft/part06 branch). The underlying
// technique (QCMDEXC + CHGDTAARA(*LDA), ALLOW(*ALL)) is separately
// CONFIRMED on real hardware in RPG III form (part05-qcmdexc-runtime,
// src/legacy/qrpgsrc/za0510.rpg) - only this specific RPG IV free-form
// port of the same technique has not itself been compiled/run yet. A
// future connection should confirm this file before it is taught as
// V2; until then, treat it as V1-unverified (should compile per the
// ILE RPG Language Reference, not yet proven).
//
// Verified against work/design/refs/ilerpgref75.txt at these
// citations (not previously cited by F0605A, which does not use
// QCMDEXC):
//   DCL-PR / EXTPGM (call to an external        ilerpgref75.txt lines
//     program, CONST parameters)                8730-8756 (same
//                                                citation F0605A's own
//                                                header already gives
//                                                for its own extpgm)
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: prototype for the system program QCMDEXC. Two
// parameters - the command string (as much of it as is actually used;
// QCMDEXC itself does not care about trailing blanks in a CHAR
// parameter longer than the command text) and a packed(15:5) length,
// matching za0510.rpg's own CALL/PARM shape (05-04) and general IBM i
// API documentation for QCMDEXC.
//-----------------------------------------------------------------------
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd char(200) const;
  cmdLen packed(15:5) const;
end-pr;

dcl-s cmd char(200);
dcl-s cmdLen packed(15:5);

cmd = 'CHGDTAARA DTAARA(*LDA (21 20)) VALUE(''F0605B OK'')';
cmdLen = %len(%trimr(cmd));

qcmdexc(cmd : cmdLen);

*inlr = *on;
return;
