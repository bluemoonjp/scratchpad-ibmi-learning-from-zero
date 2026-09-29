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
// run of @halcyontech/rpglint 0.27.0 against this exact file:
//   - SpecificCasing (if/dcl-s/dcl-pr must be lowercase): IF and
//     DCL-S below are uppercase. Real message: "Does not match
//     required case."
//   - NoGlobalSubroutines: ORDERCOUNT below is a BEGSR/ENDSR global
//     subroutine instead of a dcl-proc. Real message: "Subroutines
//     should not be defined in the global scope."
//   - NoUnreferenced: UNUSEDFLD below is declared and never used
//     anywhere. Real message: "No reference to definition." (not the
//     rule name - the README doesn't document exact message text).
//   - StringLiteralDupe: the literal 'NOTFOUND' appears twice instead
//     of being a named constant. Real message: "Same string literal
//     used more than once. Consider using a constant instead."
//   - PrettyComments (NOT originally planned - found by the real run,
//     kept because it's a genuine, confirmed 5th violation): this
//     file's own //===...=== banner-style comments (including this
//     block) trigger "Comments must be correctly formatted." This
//     repo's other RPG sources (including jucsrv.rpgle) use the same
//     banner style and are NOT PrettyComments-clean either - see
//     docs/probes.md's 08-03 rpglint section.
//
// NOT seeded (originally planned, does not actually fire): NoIndicators
// was intended to be seeded via the CHAIN below using a resulting
// indicator variable (foundInd) instead of %FOUND. A real run showed
// NoIndicators never fires on this pattern, nor on a separately-tested
// bare *IN90 array-indicator reference - its actual trigger condition
// is unconfirmed (the README documents no rule-by-rule specifics). The
// CHAIN/foundInd pattern is left as-is since it's still a legitimate
// %FOUND-vs-indicator teaching point even though rpglint itself won't
// flag it.
//
// STATUS: CONFIRMED - actually run locally (@halcyontech/rpglint
// 0.27.0, npm, zero PUB400 connection needed) against this exact file
// with templates/part08-project/rpglint.json, 2026-09-29. 18 total
// error lines reported, matching the 5 rules listed above (see
// docs/probes.md's Part 8 08-03 rpglint section for the full raw
// output and line numbers). rpglint itself is a real, installable, locally
// runnable tool - no longer "general knowledge, unconfirmed".
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
dcl-s foundInd ind;

chain (custCode) tokuim foundInd;
IF foundInd;
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
