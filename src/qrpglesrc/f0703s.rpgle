**FREE
//=======================================================================
// F0703A - client for JUCSRV's NEW countCustOrders export (Part 7,
// lesson 07-03 step 3/"the real thing"). A NEW program - F0702A is NOT
// recompiled or touched by this lesson at all; this file's whole
// purpose is to demonstrate that F0702A keeps working, unrecompiled,
// while a brand-new client can already see the newly-added export.
//
// THE ACTUAL TEST THIS PROGRAM RUNS: call countCustOrders TWICE, back
// to back, within this ONE program's own execution, and report BOTH
// counts (plus whether they match) via the job log - see jucsrv.rpgle's
// own header comment ("JUCHUM repositioning") for exactly what bug this
// is designed to surface (or rule out) and why it can only happen if
// both calls land in JUCSRV's SAME activation of its module - see
// "Why this test needs both calls in ONE activation" below.
//
// Why this test needs both calls in ONE activation (design doc's own
// flagged point, part07-design-v1.md section 9 item 3): JUCSRV's
// countCustOrders keeps juchum open/positioned per-call inside its own
// CLOSE/OPEN pair (see jucsrv.rpgle), but the BUG this lesson is about
// (a naive port WITHOUT that pair) only shows up if the SAME activation
// of JUCSRV's module answers both calls - i.e. nothing reclaims
// JUCSRV's activation group between call 1 and call 2. That is
// automatically true here because BOTH calls happen inside this one
// program's own mainline, in a single execution, with no RCLACTGRP
// and no return to the caller in between. It would NOT be true if a
// verify/test harness instead issued two SEPARATE CALL F0703A commands
// (job-level invocations) expecting to see the same effect - each such
// CALL, since this program is dftactgrp(*no) actgrp(*new), gets its own
// fresh activation group, and (per cl_commands_75.txt lines 7446-7448)
// CRTSRVPGM's own ACTGRP default is *CALLER - JUCSRV has no ACTGRP()
// specified on either of its own CRTSRVPGM/UPDSRVPGM commands (see
// jucsrv.rpgle's header comment), so it activates INTO whichever
// activation group calls it. Two separate CALL F0703A invocations would
// each get JUCSRV activated fresh, and the bug (if the fix below were
// removed) could never be observed that way - flagging this explicitly
// so a verify manifest for this lesson does not accidentally test
// nothing by issuing two separate CALLs instead of one.
//
// This program's own ctl-opt (dftactgrp(*no) actgrp(*new) bnddir(...))
// is otherwise identical in shape to F0702A's, for the same reasons
// (see f0702s.rpgle's header comment) - the important thing is not the
// *NEW value itself, it is that this program's OWN mainline makes both
// calls before it ends.
//
// Program-entry interface: this program is not a CPP for any existing
// command (unlike F0702A), so there is no external interface it must
// match. A single required CHAR(6) customer-code parameter ("cust") is
// used anyway, for consistency with every other 07-0x client in this
// part and so a verify harness can pass a real code (matching Part 6's
// own C00001 comparison customer) rather than this program hardcoding
// one - a design choice, not something the task mandated.
//
// Message technique: reused verbatim from f0609s.rpgle, exactly as
// f0702s.rpgle also does - see that file's header comment for why this
// is duplicated rather than shared.
//
// STATUS: hardware-UNTESTED (Part 7 draft, draft/part07 branch).
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('JUCSRVBD');

//-----------------------------------------------------------------------
// dcl-pr / EXTPROC(*DCLCASE): prototype for JUCSRV's countCustOrders -
// only reachable once JUCSRV's *CURRENT signature includes it (07-03
// step 3's binder-source update - see jucsrv.rpgle/jucsrv.bnd). This is
// exactly why F0703A must be built AFTER that update, not before.
//-----------------------------------------------------------------------
dcl-pr countCustOrders zoned(5:0) extproc(*dclcase);
  custCode char(6) const;
end-pr;

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: prototype for QMHSNDPM, copied verbatim from
// f0609s.rpgle (see f0702s.rpgle's header comment for the same note).
//-----------------------------------------------------------------------
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
  msgKey         char(4) const;
  errorCode      likeds(qmhsndpmErrCode);
end-pr;

//-----------------------------------------------------------------------
// Program-entry dcl-pi: one required CHAR(6) customer code (see header
// comment above - not mandated by any existing command's interface).
//-----------------------------------------------------------------------
dcl-pi *n;
  cust char(6);
end-pi;

dcl-s count1 zoned(5:0);
dcl-s count2 zoned(5:0);

//-----------------------------------------------------------------------
// THE TEST: two calls in a row, same activation, no CLOSE/reset of any
// kind between them at THIS level - all repositioning responsibility is
// JUCSRV's own (see jucsrv.rpgle). If JUCSRV's fix were removed, count2
// would read 0 here regardless of count1.
//-----------------------------------------------------------------------
count1 = countCustOrders(cust);
sendToJobLog('F0703A: countCustOrders(' + cust + ') call 1 = '
               + %trim(%char(count1)));

count2 = countCustOrders(cust);
sendToJobLog('F0703A: countCustOrders(' + cust + ') call 2 = '
               + %trim(%char(count2)));

if count1 = count2;
  sendToJobLog('F0703A: MATCH - both calls agree; JUCHUM'
                 + ' repositioning is correct.');
else;
  sendToJobLog('F0703A: MISMATCH - call 2 (' + %trim(%char(count2))
                 + ') differs from call 1 (' + %trim(%char(count1))
                 + ') - JUCHUM was left positioned from the'
                 + ' previous call.');
endif;

*inlr = *on;
return;

//=======================================================================
// sendToJobLog: verbatim from f0609s.rpgle (see f0702s.rpgle's header
// comment for the same note).
//=======================================================================
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
