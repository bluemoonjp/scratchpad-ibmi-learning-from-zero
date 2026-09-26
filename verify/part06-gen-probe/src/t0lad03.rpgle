**FREE
//=======================================================================
// T0LAD03 - P24 feature-ladder rung 3 of 12: T0LAD02 + FOR-EACH/%LIST/IN.
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   FOR-EACH (For Each)                              lines 1139,
//     2623-2646, 47167-47174 (worked example: "FOR-EACH type in
//     %LIST(OVERDUE : PENDING : CANCELLED); printReport (type); ENDFOR;")
//   %LIST (item {: item {: item ...}})               lines 1004,
//     2738-2752, 47132-47174
//   IN operator                                      lines 926, 2703-2721,
//     3200-3202, 47159-47165 (worked example: "IF 'Y' IN
//     %LIST(hadError : notFound : alwaysReport); ... ENDIF;")
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

//-----------------------------------------------------------------------
// Rung 2's new feature: DIM(*AUTO:10). The array starts with 0 elements
// and grows as elements are assigned (ilerpgref75.txt line 3282-3286).
//-----------------------------------------------------------------------
dcl-s ladArr char(10) dim(*auto:10);

dcl-s ladItem varchar(20);
dcl-s ladCount int(10) inz(0);
dcl-s ladHitText char(1) inz('N');

sendToJobLog('T0LAD01: **FREE rung compiled and ran.');

ladArr(1) = 'AAA';
ladArr(2) = 'BBB';

sendToJobLog('T0LAD02: DIM(*AUTO:10) OK - %elem after 2 assigns = '
  + %char(%elem(ladArr)));

for-each ladItem in %list('AAA' : 'BBB' : 'CCC');
  ladCount += 1;
endfor;

if 'BBB' IN %list('AAA' : 'BBB' : 'CCC');
  ladHitText = 'Y';
endif;

sendToJobLog('T0LAD03: FOR-EACH/%LIST/IN OK - count = ' + %char(ladCount)
  + ', hit = ' + ladHitText);

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
