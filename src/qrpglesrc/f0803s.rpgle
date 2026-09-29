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
// output to find them:
//   - SpecificCasing (if/dcl-s/dcl-pr must be lowercase): IF and
//     DCL-S below are uppercase.
//   - NoIndicators: the CHAIN below uses a resulting indicator
//     variable (foundInd) instead of %FOUND.
//   - NoGlobalSubroutines: ORDERCOUNT below is a BEGSR/ENDSR global
//     subroutine instead of a dcl-proc.
//   - NoUnreferenced: UNUSEDFLD below is declared and never used
//     anywhere.
//   - StringLiteralDupe: the literal 'NOTFOUND' appears twice instead
//     of being a named constant.
//
// STATUS: never compiled or linted on real hardware - rpglint itself
// has zero primary-source documentation in this repo (work/design/
// part08-design-v1.md's own section 9), so both the exact violations
// this file seeds AND whether rpglint actually reports them the way
// this header predicts are UNCONFIRMED. Treat every claim above as
// "general knowledge, to be checked against the real rpglint output
// on this file's own first real run" - if rpglint's own real output
// disagrees with this list, the real output wins and this header
// should be corrected to match it, not the other way around.
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
