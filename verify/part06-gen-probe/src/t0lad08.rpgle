**FREE
//=======================================================================
// T0LAD08 - P24 feature-ladder rung 8 of 12: T0LAD07 + DCL-ENUM.
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   DCL-ENUM / END-ENUM (typed enumeration)   lines 2471-2473 (Table 12,
//     "New Language Elements Since 7.5"), 1501-1537 (worked example,
//     "DCL-ENUM FILE_ERROR_CODES INT(10) QUALIFIED; ... END-ENUM;" -
//     this is the ONLY dated introduction of DCL-ENUM/END-ENUM this task
//     found in the reference, and it is dated "available with a
//     compile-time PTF in the second half of the year 2025" - i.e. THIS
//     RUNG, not just %DATE(*YYMD) at rung 11, may already be the point
//     where PUB400's actual PTF level first fails, depending on how
//     recently its 7.5 image was patched), 16972-17004 (DCL-ENUM/
//     END-ENUM general syntax, QUALIFIED keyword), 46537-46542 (typed
//     enum + LIKE() interaction, used below)
//
// This rung deliberately uses a TYPED enum (INT(10) QUALIFIED), not an
// untyped one, because the reference only documents LIKE(enumName) for
// a typed enum ("DCL-S num1 LIKE(e1);" where e1 has an explicit type,
// line 46552) - untyped enums are shown only being referenced directly
// by qualified constant name (myEnum.c1, line 16995), never with LIKE().
// Using the typed form here avoids guessing whether LIKE() also works
// on an untyped enum.
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

dcl-s ladParts varchar(10) dim(10);
dcl-s ladUpper varchar(10);

dcl-ds ladMsgFile likeds(qmhsndpmMsgFile) inz(*likeds);
dcl-ds ladErrCode likeds(qmhsndpmErrCode) inz(*likeds);
dcl-s  ladMsgKey  char(4);

dcl-s ladConcat varchar(50);

dcl-s ladType char(10) inz('OWNER');
dcl-s ladBranch varchar(20);

dcl-enum ladColors int(10) qualified;
  red 1;
  green 2;
  blue 3;
end-enum;

dcl-s ladColorVal like(ladColors);

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

ladParts = %split('cat.dog.fish' : '.');
ladUpper = %upper(ladParts(1));

sendToJobLog('T0LAD04: %SPLIT/%UPPER OK - upper(parts(1)) = ' + ladUpper
  + ', parts(2) = ' + %trim(ladParts(2)));

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

ladConcat = %concat(', ' : 'cat' : 'dog' : 'fish');

sendToJobLog('T0LAD06: %CONCAT OK - result = ' + ladConcat);

select ladType;
  when-is 'MANAGER';
    ladBranch = 'manager-branch';
  when-is 'OWNER';
    ladBranch = 'owner-branch';
  other;
    ladBranch = 'other-branch';
endsl;

sendToJobLog('T0LAD07: WHEN-IS OK - branch = ' + ladBranch);

ladColorVal = ladColors.green;

sendToJobLog('T0LAD08: DCL-ENUM OK - green = ' + %char(ladColorVal));

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
