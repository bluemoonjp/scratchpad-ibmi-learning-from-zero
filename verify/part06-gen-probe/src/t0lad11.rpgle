**FREE
//=======================================================================
// T0LAD11 - P24 feature-ladder rung 11 of 12: T0LAD10 + %DATE(*YYMD).
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   *YYMD date format, usable with %DATE (among other operations)
//     lines 1539-1555 ("You can specify date formats *DMYY, *MDYY, and
//     *YYMD for some operations... supported for the TEST operation code
//     and for conversion between date values and character or numeric
//     values using... %DATE built-in function... This enhancement is
//     available with a compile-time PTF in the second half of the year
//     2025" - the task's own hint that this may be newer/PTF-dependent
//     is confirmed directly by the reference itself), 2463-2465 (Table
//     11, "New Language Elements Since 7.5: Date formats"), 20845
//     (format table: "*YYMD  4-digit Year/  yyyy/mm/dd  ...  10
//     2001/04/25"), 59537 ("*YYMD  20360521  21/05/36  D(*DMY)")
//
// Given today's date (2026-09-26) is only about a year after this
// feature's "second half of 2025" PTF, this rung is a strong candidate
// for where PUB400's actual installed PTF level first fails - which is
// exactly the point of this probe.
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

//-----------------------------------------------------------------------
// Rung 11's new feature: %DATE with the *YYMD format option.
//-----------------------------------------------------------------------
dcl-s ladNumDate packed(9:0) inz(20260926);
dcl-s ladDateVal date;

ladDateVal = %date(ladNumDate : *yymd);

sendToJobLog('T0LAD11: %DATE(*YYMD) OK - date = '
  + %char(ladDateVal : *iso));

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
