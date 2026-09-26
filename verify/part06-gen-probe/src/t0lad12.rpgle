**FREE
//=======================================================================
// T0LAD12 - P24 feature-ladder rung 12 of 12 (RPGLE variant):
// T0LAD11 + ASSERT-T. See t0lad01.rpgle for the shared QMHSNDPM/
// sendToJobLog rationale, and t0lad12q.sqlrpgle (same directory) for the
// SQLRPGLE variant of this exact same rung (task instruction: ASSERT-T
// must ALSO be built as a separate SQLRPGLE compile, since its behavior
// can differ between the two).
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   ASSERT-T (Test an assertion, true case)   lines 2482, 1379-1408 (base
//     introduction: "Assertion operations ASSERT-F and ASSERT-T... This
//     enhancement is available with a compile-time PTF and a runtime PTF
//     in the first half of the year 2026" - this is the SINGLE newest/
//     most-recent-dated feature in the entire ladder, newer even than
//     %DATE(*YYMD)'s "second half of 2025", which is exactly why it is
//     the last rung), 38789 (op-code table), 51753 (free-form syntax:
//     "ASSERT-F{(A)} condition"), 51940 ("ASSERT-T total <= MAX
//     %MSG('ORD0101' : 'ORDERMSGF' : %char(total));"), 51916-51923 ("the
//     program defaults to ASSERT(*EXCP) mode... If the condition is
//     false, an escape message is sent... escape message RNX0461 is
//     issued")
//
// This rung's condition is deliberately TRUE (ladTotal <= ladMax), so
// under the default ASSERT(*EXCP) mode the assertion succeeds silently
// and the program simply continues - no escape, no dependency on the
// exact RNX0461 status-code behavior the reference describes for the
// FAILURE case, which is not this rung's concern (that would be a
// separate, deliberate-failure test, out of scope for a ladder that just
// asks "does this syntax compile and run").
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

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

sendToJobLog('T0LAD01: **FREE rung compiled and ran.');

dcl-s ladArr char(10) dim(*auto:10);

ladArr(1) = 'AAA';
ladArr(2) = 'BBB';

sendToJobLog('T0LAD02: DIM(*AUTO:10) OK - %elem after 2 assigns = '
  + %char(%elem(ladArr)));

dcl-s ladItem varchar(20);
dcl-s ladCount int(10) inz(0);
dcl-s ladHitText char(1) inz('N');

for-each ladItem in %list('AAA' : 'BBB' : 'CCC');
  ladCount += 1;
endfor;

if 'BBB' IN %list('AAA' : 'BBB' : 'CCC');
  ladHitText = 'Y';
endif;

sendToJobLog('T0LAD03: FOR-EACH/%LIST/IN OK - count = ' + %char(ladCount)
  + ', hit = ' + ladHitText);

dcl-s ladParts varchar(10) dim(10);
dcl-s ladUpper varchar(10);

ladParts = %split('cat.dog.fish' : '.');
ladUpper = %upper(ladParts(1));

sendToJobLog('T0LAD04: %SPLIT/%UPPER OK - upper(parts(1)) = ' + ladUpper
  + ', parts(2) = ' + %trim(ladParts(2)));

dcl-ds ladMsgFile likeds(qmhsndpmMsgFile) inz(*likeds);
dcl-ds ladErrCode likeds(qmhsndpmErrCode) inz(*likeds);
dcl-s  ladMsgKey  char(4);

snd-msg *info 'T0LAD05: native SND-MSG opcode compiled and executed.';

monitor;
  callp qmhsndpm('CPF9898' : ladMsgFile
    : 'T0LAD05: MONITOR/CALLP probe call.'
    : %len(%trimr('T0LAD05: MONITOR/CALLP probe call.'))
    : '*INFO' : '*' : 0 : ladMsgKey : ladErrCode);
on-excp 'CPF9897';
  snd-msg 'T0LAD05: unexpected exception caught by ON-EXCP (should not happen).';
endmon;

sendToJobLog('T0LAD05: SND-MSG/ON-EXCP/MONITOR/CALLP compiled and ran.');

dcl-s ladConcat varchar(50);

ladConcat = %concat(', ' : 'cat' : 'dog' : 'fish');

sendToJobLog('T0LAD06: %CONCAT OK - result = ' + ladConcat);

dcl-s ladType char(10) inz('OWNER');
dcl-s ladBranch varchar(20);

select ladType;
  when-is 'MANAGER';
    ladBranch = 'manager-branch';
  when-is 'OWNER';
    ladBranch = 'owner-branch';
  other;
    ladBranch = 'other-branch';
endsl;

sendToJobLog('T0LAD07: WHEN-IS OK - branch = ' + ladBranch);

dcl-enum ladColors int(10) qualified;
  red 1;
  green 2;
  blue 3;
end-enum;

dcl-s ladColorVal like(ladColors);

ladColorVal = ladColors.green;

sendToJobLog('T0LAD08: DCL-ENUM OK - green = ' + %char(ladColorVal));

dcl-c LAD_MAX_RETRY const(3);

sendToJobLog('T0LAD09: CONST OK - LAD_MAX_RETRY = ' + %char(LAD_MAX_RETRY));

sendToJobLog('T0LAD10: %HIVAL OK - hival(ladColors) = '
  + %char(%hival(ladColors)));

dcl-s ladNumDate packed(9:0) inz(20260926);
dcl-s ladDateVal date;

ladDateVal = %date(ladNumDate : *yymd);

sendToJobLog('T0LAD11: %DATE(*YYMD) OK - date = '
  + %char(ladDateVal : *iso));

//-----------------------------------------------------------------------
// Rung 12's new feature: ASSERT-T (condition is deliberately true).
//-----------------------------------------------------------------------
dcl-s ladTotal packed(9:2) inz(100);
dcl-s ladMax packed(9:2) inz(999);

assert-t ladTotal <= ladMax %msg('T0LAD12: total should not exceed max');

sendToJobLog('T0LAD12: ASSERT-T OK - assertion passed, program continued.');

*inlr = *on;
return;

dcl-proc sendToJobLog;
  dcl-pi *n;
    msg char(200) const;
  end-pi;

  dcl-ds msgFile likeds(qmhsndpmMsgFile) inz(*likeds);
  dcl-ds errCode likeds(qmhsndpmErrCode) inz(*likeds);
  dcl-s  msgKey  char(4);

  qmhsndpm('CPF9898' : msgFile : msg : %len(%trimr(msg))
             : '*INFO' : '*' : 0 : msgKey : errCode);
end-proc;
