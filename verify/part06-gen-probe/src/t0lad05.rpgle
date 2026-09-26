**FREE
//=======================================================================
// T0LAD05 - P24 feature-ladder rung 5 of 12: T0LAD04 + SND-MSG/ON-EXCP
// (built through the point where it would CALL, per the task's own
// instruction not to require actually exercising the exception path).
// See t0lad01.rpgle for the shared QMHSNDPM/sendToJobLog rationale.
//
// New in this rung, verified against work/design/refs/ilerpgref75.txt:
//   SND-MSG (Send a Message to the Joblog)   lines 1736, 2356, 2505-2566
//     (base op-code dated "first half of the year 2022", also 7.3/7.4
//     with PTF - i.e. well-established by 7.5, low risk), 3255,
//     64132-64201 (full syntax + operand rules)
//   MONITOR (Begin a Monitor Group)          lines 1155, 58399-58458
//   ON-EXCP (On Exception)                   lines 1168, 2349,
//     2569-2598 (base op-code, also dated "first half of 2022" - SAME
//     era as SND-MSG above), 3252, 60987-61056 (full syntax + the
//     generic-message-ID rules)
//     IMPORTANT: this rung deliberately uses a LITERAL message ID
//     ('CPF9897'), NOT a generic '*' pattern like 'CPF*'. The reference
//     documents TWO different eras for ON-EXCP: literal message IDs are
//     part of the original, older (2022) ON-EXCP feature used here, but
//     a GENERIC '*' message ID for ON-EXCP is a SEPARATE, much newer
//     enhancement (lines 1414-1436: "You can specify a generic message
//     ID for ON-EXCP... available with a compile-time PTF and a runtime
//     PTF in the first half of the year 2026"). Using a literal ID here
//     avoids accidentally testing that unrelated, newer capability.
//   CALLP (Call a Procedure)                 lines 52581 (free-form
//     syntax "CALLP{(EMR)} name(...)")
//     NOTE: the classic fixed-form CALL op-code is explicitly NOT
//     available in free-form ("Free-Form Syntax (not allowed - use the
//     CALLP operation code)", lines 52461, 52518, 61551, 61667), so this
//     rung's "CALL" is a CALLP against a prototyped external program
//     (QMHSNDPM, already declared above and already known-safe from
//     T0LAD01 onward), not the classic dynamic CALL op-code.
//
// Design choice: the CALLP target is QMHSNDPM itself (already declared,
// already exercised safely since T0LAD01), NOT a made-up/nonexistent
// program name. This repo's two reference files do not document which
// message ID a "target program not found" failure would raise for a
// prototyped CALLP, and getting that wrong here would risk an UNCAUGHT
// exception that could abort the CL wrapper early and skip every later
// rung (T0LAD06-12) in the same connection. Wrapping a call that is
// already known to succeed keeps the MONITOR/ON-EXCP/SND-MSG/CALLP
// syntax genuinely compiled AND executed, without gambling the rest of
// the ladder on an unverified message ID.
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

//-----------------------------------------------------------------------
// Rung 5's new features: SND-MSG (direct), and MONITOR/ON-EXCP/CALLP
// wrapping a call expected to succeed (see header comment above).
//-----------------------------------------------------------------------
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

*inlr = *on;
return;
