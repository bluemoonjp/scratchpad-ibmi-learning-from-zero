**FREE
//=======================================================================
// T0LAD07 - P24 feature-ladder rung 7 of 12: T0LAD06 + WHEN-IS.
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   WHEN-IS (When the SELECT Operand is Equal to the WHEN-IS Operand)
//     lines 1969, 1978, 2489, 66070-66139 (full syntax + worked example:
//     "SELECT employeeType; WHEN-IS 'MANAGER'; ... WHEN-IS 'OWNER'; ...
//     OTHER; ... ENDSL;"). NOTE: WHEN-IS compares against the SELECT
//     statement's OWN operand (SELECT ladType; WHEN-IS 'X';), unlike the
//     older WHEN op-code which takes an arbitrary boolean condition -
//     this rung follows the reference's own SELECT-with-operand pattern
//     exactly, not a generic "WHEN condition" form.
//=======================================================================

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

//-----------------------------------------------------------------------
// Rung 7's new feature: WHEN-IS inside a SELECT-with-operand group.
//-----------------------------------------------------------------------
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

*inlr = *on;
return;
