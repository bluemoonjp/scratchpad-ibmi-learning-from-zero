**FREE
//=======================================================================
// T0LAD12Q - P24 feature-ladder rung 12 of 12 (SQLRPGLE variant):
// byte-for-byte the SAME source as t0lad12.rpgle, compiled with
// CRTSQLRPGI instead of CRTBNDRPG. Per the task instruction, ASSERT-T
// "should ALSO be built as a separate SQLRPGLE compile, not just RPGLE,
// since ASSERT-T behavior can differ between the two".
//
// Deliberate choice: this member contains NO embedded SQL statement
// (no EXEC SQL). Embedded SQL syntax itself is documented in IBM's
// separate "SQL Programming" manual, not in either of this task's two
// primary sources (work/design/refs/ilerpgref75.txt and
// ilerpgprogguide75.txt - both were grepped for "exec sql" and neither
// has any hit), so this task cannot verify any specific EXEC SQL
// statement's syntax the way every other line in this ladder was
// verified. Adding an unverified EXEC SQL statement here would also
// confound the one thing this rung is meant to isolate: whether
// ASSERT-T itself compiles/runs differently under CRTSQLRPGI's compile
// path. CRTSQLRPGI does not require any embedded SQL to be present - the
// SQL precompiler pass simply finds nothing to precompile and hands the
// unchanged source to the same RPG compiler CRTBNDRPG would use - so
// omitting EXEC SQL keeps this a clean A/B comparison against
// t0lad12.rpgle instead of adding an unverified variable.
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

sendToJobLog('T0LAD12Q: **FREE rung compiled and ran.');

dcl-s ladArr char(10) dim(*auto:10);

ladArr(1) = 'AAA';
ladArr(2) = 'BBB';

sendToJobLog('T0LAD12Q: DIM(*AUTO:10) OK - %elem after 2 assigns = '
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

sendToJobLog('T0LAD12Q: FOR-EACH/%LIST/IN OK - count = ' + %char(ladCount)
  + ', hit = ' + ladHitText);

dcl-s ladParts varchar(10) dim(10);
dcl-s ladUpper varchar(10);

ladParts = %split('cat.dog.fish' : '.');
ladUpper = %upper(ladParts(1));

sendToJobLog('T0LAD12Q: %SPLIT/%UPPER OK - upper(parts(1)) = ' + ladUpper
  + ', parts(2) = ' + %trim(ladParts(2)));

dcl-ds ladMsgFile likeds(qmhsndpmMsgFile) inz(*likeds);
dcl-ds ladErrCode likeds(qmhsndpmErrCode) inz(*likeds);
dcl-s  ladMsgKey  char(4);

snd-msg *info 'T0LAD12Q: native SND-MSG opcode compiled and executed.';

monitor;
  callp qmhsndpm('CPF9898' : ladMsgFile
    : 'T0LAD12Q: MONITOR/CALLP probe call.'
    : %len(%trimr('T0LAD12Q: MONITOR/CALLP probe call.'))
    : '*INFO' : '*' : 0 : ladMsgKey : ladErrCode);
on-excp 'CPF9897';
  snd-msg 'T0LAD12Q: unexpected exception caught by ON-EXCP (should not happen).';
endmon;

sendToJobLog('T0LAD12Q: SND-MSG/ON-EXCP/MONITOR/CALLP compiled and ran.');

dcl-s ladConcat varchar(50);

ladConcat = %concat(', ' : 'cat' : 'dog' : 'fish');

sendToJobLog('T0LAD12Q: %CONCAT OK - result = ' + ladConcat);

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

sendToJobLog('T0LAD12Q: WHEN-IS OK - branch = ' + ladBranch);

dcl-enum ladColors int(10) qualified;
  red 1;
  green 2;
  blue 3;
end-enum;

dcl-s ladColorVal like(ladColors);

ladColorVal = ladColors.green;

sendToJobLog('T0LAD12Q: DCL-ENUM OK - green = ' + %char(ladColorVal));

dcl-c LAD_MAX_RETRY const(3);

sendToJobLog('T0LAD12Q: CONST OK - LAD_MAX_RETRY = ' + %char(LAD_MAX_RETRY));

sendToJobLog('T0LAD12Q: %HIVAL OK - hival(ladColors) = '
  + %char(%hival(ladColors)));

dcl-s ladNumDate packed(9:0) inz(20260926);
dcl-s ladDateVal date;

ladDateVal = %date(ladNumDate : *yymd);

sendToJobLog('T0LAD12Q: %DATE(*YYMD) OK - date = '
  + %char(ladDateVal : *iso));

//-----------------------------------------------------------------------
// Rung 12's new feature: ASSERT-T (condition is deliberately true),
// compiled here via CRTSQLRPGI instead of CRTBNDRPG.
//-----------------------------------------------------------------------
dcl-s ladTotal packed(9:2) inz(100);
dcl-s ladMax packed(9:2) inz(999);

assert-t ladTotal <= ladMax %msg('T0LAD12Q: total should not exceed max');

sendToJobLog('T0LAD12Q: ASSERT-T OK (CRTSQLRPGI) - assertion passed, program continued.');

*inlr = *on;
return;
