**FREE
//=======================================================================
// F0803S - 08-03 distributed exercise seed. A small, standalone
// program (NOT a service program - no exported procedures, so 08-03's
// own scope constraint "do not change exported procedure names/
// signatures/return values" does not even apply here; this file's
// whole point is to be safely, freely refactored end to end) that
// prints one customer's name and order count (the same TOKUIM/JUCHUM
// data JUCSRV's own getCustName/countCustOrders already use, per
// db/data/load_v1.sql - deliberately familiar data, so the exercise
// itself, not the business data, is what is new).
//
// DELIBERATE, SEEDED rpglint violations (templates/part08-project/
// rpglint.json's own rule set) - the whole point of this file. Each
// violated rule is named here for the AUTHOR's own reference; the
// lesson text should not spoil exactly where each one is in the code
// itself, so the learner has to actually run rpglint and read its
// output to find them. CONFIRMED (see STATUS below) via a real local
// run of @halcyontech/rpglint 0.27.0 against this exact file, using
// the corrected templates/part08-project/.vscode/rpglint.json (see that
// file's own history - the first version had 4 keys, including
// NoIndicators, that are not real rule names in 0.27.0 at all, and
// SpecificCasing's "expected" value needs the CL-style "*LOWER"/
// "*UPPER" special-value form, not a bare "lower"/"upper" string -
// both bugs were found by reading dist/index.js directly, since the
// README documents neither the full rule list nor this value format):
//   - SpecificCasing (if/dcl-s/dcl-pr must be lowercase): IF and
//     DCL-S below are uppercase. Real message: "Does not match
//     required case."
//   - NoGlobalSubroutines: ORDERCOUNT below is a BEGSR/ENDSR global
//     subroutine instead of a dcl-proc. Real message: "Subroutines
//     should not be defined in the global scope."
//   - NoUnreferenced: UNUSEDFLD below is declared and never used
//     anywhere. Real message: "No reference to definition." (not the
//     rule name - the README doesn't document exact message text).
//   - StringLiteralDupe: the literal 'NOTFOUND' appears THREE times
//     (not two - corrected after a real run) instead of being a named
//     constant. Real message: "Same string literal used more than
//     once. Consider using a constant instead."
//   - PrettyComments (NOT originally planned - found by the real run,
//     kept because it's a genuine, confirmed 5th violation): this
//     file's own //===...=== banner-style comments (including this
//     block) trigger "Comments must be correctly formatted." This
//     repo's other RPG sources (including jucsrv.rpgle) use the same
//     banner style and are NOT PrettyComments-clean either - see
//     docs/probes.md's 08-03 rpglint section.
//
// REMOVED, real compile bug found on real hardware: this file used to
// CHAIN into a plain `ind` resulting-indicator field (`foundInd`)
// instead of %FOUND, originally meant to trigger a rule called
// "NoIndicators" that turned out not to exist in 0.27.0 (see above) -
// so it was kept anyway as "not an rpglint finding, but still a
// legitimate design point". That framing was wrong. A real CRTBNDRPG
// test (verify/part08-03-f0803-compile, 2026-09-29) showed this
// pattern does NOT compile in free-form RPG at all: RNF5191 (severity
// 30) "The Result-Field is not a data structure when Factor 2 is a
// file name." - ilerpgref75.txt line 38795's own free-form CHAIN
// syntax table already said the third operand is a data-structure,
// not a resulting indicator; a plain `ind` field doesn't qualify. The
// %FOUND-based form below was compiled in the same connection
// (F0803CHKB, Highest Severity 00) and is what this file now uses.
//
// STATUS: CONFIRMED - the %FOUND-based CHAIN construct compiled in
// isolation first (verify/part08-03-f0803-compile, 2026-09-29,
// Highest Severity 00), and this whole, assembled file (the
// orderCount subroutine's JUCHUM loop, the %subst/WRITE QSYSPRT block,
// all of it together) was then compiled as one real CRTBNDRPG program
// and CALLed without error (verify/part08-02-testpf, 2026-09-29,
// Highest Severity 00).
//
// rpglint re-run locally against this exact, current file
// (@halcyontech/rpglint 0.27.0, npm, zero PUB400 connection needed,
// corrected templates/part08-project/.vscode/rpglint.json, 2026-09-29): 13
// errors - SpecificCasing x2, NoGlobalSubroutines x3, StringLiteralDupe
// x3, NoUnreferenced x1, PrettyComments x4. Matches the 5 rules
// described above exactly. Line numbers are deliberately not quoted
// here - they drift every time this header itself is edited (already
// observed twice this session); re-run rpglint against the current
// file rather than trusting a hardcoded number. rpglint itself is a
// real, installable, locally runnable tool - no longer "general
// knowledge, unconfirmed".
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f tokuim keyed usage(*input);
dcl-f juchum usage(*input) usropn;
dcl-f qsysprt printer(132) usage(*output);

dcl-pi *n;
  custCode char(6) const;
end-pi;

dcl-ds line len(132) end-ds;

DCL-S custName char(30);
dcl-s orderCnt zoned(5:0) inz(0);
dcl-s unusedFld char(10);

chain (custCode) tokuim;
IF %found(tokuim);
  custName = toknm;
ELSE;
  custName = 'NOTFOUND';
ENDIF;

exsr orderCount;

clear line;
%subst(line:1:6)   = custCode;
%subst(line:10:30) = custName;
if custName <> 'NOTFOUND';
  %subst(line:43:5) = %editc(orderCnt:'Z');
else;
  %subst(line:43:8) = 'NOTFOUND';
endif;
write qsysprt line;

*inlr = *on;
return;

//=======================================================================
// orderCount - deliberately a global subroutine (BEGSR/ENDSR), not a
// dcl-proc, to seed a NoGlobalSubroutines violation. Counts JUCHUM
// rows for custCode, the same full-scan pattern jucsrv.rpgle's own
// countCustOrders uses (close/open pair for repositioning safety, even
// though this program never calls it more than once per activation -
// harmless here, kept for consistency with the established pattern).
//=======================================================================
begsr orderCount;
  close juchum;
  open  juchum;

  read juchum;
  dow not %eof(juchum);
    if jutok = custCode;
      orderCnt += 1;
    endif;
    read juchum;
  enddo;

  close juchum;
endsr;
