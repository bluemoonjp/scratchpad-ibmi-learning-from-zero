**FREE
//=======================================================================
// F0803S - 08-03 distributed exercise seed. A small, standalone
// program (NOT a service program - no exported procedures, so 08-03's
// own scope constraint about exported-procedure names/signatures does
// not even apply here; this file's whole point is to be safely,
// freely refactored end to end) that prints one customer's name and
// order count (the same TOKUIM/JUCHUM data JUCSRV's own
// getCustName/countCustOrders already use, per db/data/load_v1.sql -
// deliberately familiar data, so the exercise itself, not the
// business data, is what is new).
//
// This file is meant to be linted against this repo's own
// rpglint.json (templates/part08-project/.vscode/rpglint.json). Run
// rpglint against it yourself and read the output - that is the point
// of the 08-03 exercise. See solutions/08-03/f0803s.rpgle for a model
// answer afterward, not before.
//
// STATUS: CONFIRMED - compiles as one whole program on real hardware
// (verify/part08-02-testpf, 2026-09-29, Highest Severity 00) and runs
// without error.
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

// orderCount - counts JUCHUM rows for custCode, the same full-scan
// pattern jucsrv.rpgle's own countCustOrders uses (close/open pair for
// repositioning safety, even though this program never calls it more
// than once per activation - harmless here, kept for consistency with
// the established pattern).
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
