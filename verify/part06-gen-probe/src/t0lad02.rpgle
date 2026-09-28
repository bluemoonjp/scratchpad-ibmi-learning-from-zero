**FREE
//=======================================================================
// T0LAD02 - P24 feature-ladder rung 2 of 12: T0LAD01 + DIM(*AUTO).
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale and
// verify/part06-gen-probe/manifest.json for the full ladder description.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   DIM(*AUTO:numeric_constant) - varying-dimension array   lines 641,
//     3269-3298, 3477-3484. NOTE: the design doc's own shorthand
//     "DIM(*AUTO)" (work/design/final_probes.json, "P24") is NOT the
//     actual syntax - the reference's own syntax notation is
//     "DIM({*AUTO:|*CTDATA|*VAR:}numeric_constant)" (line 641) and every
//     worked example uses a colon plus a maximum-element count, e.g.
//     "DCL-S array_auto CHAR(10) DIM(*AUTO:100);" (line 3277). A bare
//     DIM(*AUTO) with no colon/count is not what the reference shows, so
//     this rung uses DIM(*AUTO:10) instead.
//   %ELEM (current number of elements of a *AUTO array)      line 3282
//     ("The dimension of a varying-dimension array defined with
//     DIM(*AUTO) increases when there is an assignment statement...")
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

sendToJobLog('T0LAD01: **FREE rung compiled and ran.');

ladArr(1) = 'AAA';
ladArr(2) = 'BBB';

sendToJobLog('T0LAD02: DIM(*AUTO:10) OK - %elem after 2 assigns = '
  + %char(%elem(ladArr)));

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
