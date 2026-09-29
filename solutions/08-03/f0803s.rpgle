**FREE
// F0803S - model solution for the 08-03 rpglint exercise
// (src/qrpglesrc/f0803s.rpgle). Fixes all 5 real, confirmed rpglint
// violations the seed file has (SpecificCasing, NoGlobalSubroutines,
// NoUnreferenced, StringLiteralDupe, PrettyComments - see
// docs/probes.md's Part 8 08-03 section for the confirmed rule list
// and messages; deliberately not itemized again here since this file
// is the answer key). The seed file also already uses %FOUND (not a
// plain `ind` field) for its CHAIN, after an earlier draft's `ind`
// form was found not to compile at all in free-form RPG (RNF5191,
// verify/part08-03-f0803-compile) - nothing left to fix there.
//
// This is intended as a style-only refactor: the printed output (line
// layout, values) is designed to be unchanged from the seed file, to
// match 08-03's own scope constraint (no behavior-changing edits
// before 08-04 sets up a safety net and 08-05 demonstrates
// test-then-refactor). That equivalence has NOT been independently
// verified by comparing actual printed output byte-for-byte against
// the seed file - both programs compiled and ran without error, but
// their WRKSPLF output was not captured/diffed. Treat as V3
// (unconfirmed) until someone actually compares the two spool files.
//
// STATUS: rpglint-clean locally confirmed (@halcyontech/rpglint 0.27.0,
// templates/part08-project/.vscode/rpglint.json, 2026-09-29, 0 errors).
// Compiled on real hardware as this whole, assembled file and CALLed
// without error (verify/part08-02-testpf, 2026-09-29, Highest
// Severity 00) - see that manifest/docs/probes.md for the exact
// connection record.

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f tokuim keyed usage(*input);
dcl-f juchum usage(*input) usropn;
dcl-f qsysprt printer(132) usage(*output);

dcl-pi *n;
  custCode char(6) const;
end-pi;

dcl-ds line len(132) end-ds;

dcl-c cNotFound 'NOTFOUND';

dcl-s custName char(30);
dcl-s orderCnt zoned(5:0) inz(0);

chain (custCode) tokuim;
if %found(tokuim);
  custName = toknm;
else;
  custName = cNotFound;
endif;

orderCnt = orderCount(custCode);

clear line;
%subst(line:1:6)   = custCode;
%subst(line:10:30) = custName;
if custName <> cNotFound;
  %subst(line:43:5) = %editc(orderCnt:'Z');
else;
  %subst(line:43:8) = cNotFound;
endif;
write qsysprt line;

*inlr = *on;
return;

// orderCount: counts JUCHUM rows for custCode. Converted from the seed
// file's global BEGSR/ENDSR subroutine (NoGlobalSubroutines) into a
// dcl-proc that takes custCode as an explicit parameter and returns
// the count, rather than reading/writing the caller's global
// variables directly - avoids any question about whether a
// subprocedure can see the mainline's globals, by simply not relying
// on them. Called as orderCount(custCode) below (call-with-brackets
// syntax, required for any procedure call regardless of rpglint
// config - NOT because of RequiresParameter specifically: that rule's
// actual trigger condition is unconfirmed, and it did not fire on the
// seed file's own exsr-based call at all - see docs/probes.md).
dcl-proc orderCount;
  dcl-pi *n zoned(5:0);
    custCode char(6) const;
  end-pi;

  dcl-s orderCnt zoned(5:0) inz(0);

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
  return orderCnt;
end-proc;
