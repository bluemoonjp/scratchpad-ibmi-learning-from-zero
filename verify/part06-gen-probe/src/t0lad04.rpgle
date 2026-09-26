**FREE
//=======================================================================
// T0LAD04 - P24 feature-ladder rung 4 of 12: T0LAD03 + %SPLIT/%UPPER.
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   %SPLIT(string {: separators {: *ALLSEP {: *NATURAL|*STDCHARSIZE}}})
//     lines 1046, 49648-49650 (syntax line), 49661-49675
//   %UPPER(string {: start {: length {: *NATURAL|*STDCHARSIZE}}})
//     lines 1069, 51234-51241
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

//-----------------------------------------------------------------------
// Rung 4's new feature: %SPLIT and %UPPER.
//-----------------------------------------------------------------------
dcl-s ladParts varchar(10) dim(10);
dcl-s ladUpper varchar(10);

ladParts = %split('cat.dog.fish' : '.');
ladUpper = %upper(ladParts(1));

sendToJobLog('T0LAD04: %SPLIT/%UPPER OK - upper(parts(1)) = ' + ladUpper
  + ', parts(2) = ' + %trim(ladParts(2)));

*inlr = *on;
return;
