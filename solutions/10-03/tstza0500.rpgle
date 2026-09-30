**FREE
// =====================================================================
// TSTZA0500 - TESTKIT test case for the modernized ZA0500 (lesson
// 10-03, Capstone D). It calls the real ZA0500 program against the
// real JUCHUD/JUCHUM order data and checks the stock it leaves behind.
//
// STATUS: UNVERIFIED (2026-09-30). verify/part10-03-modernize runs it.
//
// ISOLATION (same trick as tstzaisrv.rpgle, and it is NOT done here):
// ZAIKOM must be redirected to a QTEMP copy BEFORE this program is
// called, in the same job. RUNTEST (runtest.clp) does exactly that:
//   CRTDUPOBJ ZAIKOM to QTEMP with DATA(*YES)
//   OVRDBF FILE(ZAIKOM) TOFILE(QTEMP/ZAIKOM) WAITRCD(3) OVRSCOPE(*JOB)
// ZAISRV is ACTGRP(*CALLER), so it opens whatever ZAIKOM resolves to
// inside this program activation group. Without the override this
// program would change the SHARED ZAIKOM: do not run it by hand
// without RUNTEST.
//
// STARTING STATE: every case first puts the six products back to the
// load_v1 stock (45 3 250 60 12 22) using ZAISRV get/reserve/release,
// so the cases do not depend on each other or on the seed value.
//
// CASES (minqty is 5 in all of them; order lines in JUNO/JULINE order):
//   A  *TEST run: nothing changes.
//   B  *LIVE run: OK lines reduce stock, SHORT lines do not.
//        P00001 45 - 2 - 1 - 3 = 39     P00003 250 - 5 - 10 = 235
//        P00004 60 - 10 - 2 = 48        P00006 22 - 2 = 20
//        P00002 stays 3 (both lines SHORT)
//        P00005 12 - 3 = 9, then 9 - 5 = 4 < 5 is SHORT, stays 9
//   C  margin boundary on P00002 (lines qty 1 then qty 2):
//        stock 6: 6 - 1 = 5 = minqty is OK -> 5; then 5 - 2 = 3 SHORT
//        stock 5: 5 - 1 = 4 < minqty is SHORT -> stays 5
//   D  NOTFOUND: the QTEMP row for P00006 is deleted, the run must
//        complete and leave the other products right. The row is put
//        back afterwards.
//   E  guard, NOT the lock-leak proof: this program reads the SHORT
//        products for update through its own open of ZAIKOM and expects
//        no record-in-use error. ZA0500 runs in its own activation
//        group (ACTGRP *NEW), which is deleted when it returns, so a
//        lock could not survive to this point anyway. What carries the
//        no-leak claim: (1) by construction the SHORT path only calls
//        get() (an unlocked read) and reserve() releases its own lock
//        on its SHORT branch; (2) the batch runs JU0900C twice in one
//        job (second call must work).
//
// BUILD:
//   CRTBNDRPG PGM(<lib>/TSTZA0500) SRCFILE(<lib>/QRPGLESRC)
//     SRCMBR(TSTZA0500) DFTACTGRP(*NO) ACTGRP(*NEW)
//     BNDDIR((*LIBL/ZAISRVBD) (*LIBL/TESTKITBD))
// =====================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

// Own open of ZAIKOM, used only by the lock check (case E).
dcl-f zaikom usage(*update) keyed usropn;

dcl-pr get packed(7:0) extproc('GET');
  prodCode char(6) const;
end-pr;

dcl-pr reserve ind extproc('RESERVE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

dcl-pr release ind extproc('RELEASE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

dcl-pr za0500 extpgm('ZA0500');
  rmode  char(10);
  minqty packed(5:0);
end-pr;

dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd    char(200) const;
  cmdLen packed(15:5) const;
end-pr;

dcl-pr testInit extproc(*dclcase);
end-pr;

dcl-pr assertEqualsNum extproc(*dclcase);
  testName char(30) const;
  expected packed(15:5) const;
  actual   packed(15:5) const;
end-pr;

dcl-pr assertTrue extproc(*dclcase);
  testName char(30) const;
  actual   ind const;
end-pr;

dcl-s ran    ind;
dcl-s locked ind;
dcl-s opened ind inz(*off);
dcl-s cmd    char(200);

testInit();

// --- A: *TEST run changes nothing -----------------------------------
resetAll(3);
ran = callZa0500('*TEST');

monitor;
  assertEqualsNum('A1-TEST-P00001-UNCHANGED' : 45 : get('P00001'));
on-error;
endmon;

monitor;
  assertEqualsNum('A2-TEST-P00005-UNCHANGED' : 12 : get('P00005'));
on-error;
endmon;

// --- B: *LIVE run, OK lines deduct, SHORT lines do not ---------------
resetAll(3);
ran = callZa0500('*LIVE');

monitor;
  assertEqualsNum('B1-LIVE-P00001-DEDUCTED' : 39 : get('P00001'));
on-error;
endmon;

monitor;
  assertEqualsNum('B2-LIVE-P00002-SHORT-KEPT' : 3 : get('P00002'));
on-error;
endmon;

monitor;
  assertEqualsNum('B3-LIVE-P00003-DEDUCTED' : 235 : get('P00003'));
on-error;
endmon;

monitor;
  assertEqualsNum('B4-LIVE-P00004-DEDUCTED' : 48 : get('P00004'));
on-error;
endmon;

monitor;
  assertEqualsNum('B5-LIVE-P00005-SECOND-SHORT' : 9 : get('P00005'));
on-error;
endmon;

monitor;
  assertEqualsNum('B6-LIVE-P00006-DEDUCTED' : 20 : get('P00006'));
on-error;
endmon;

// --- C: margin boundary (avail = minqty is OK, minqty - 1 is SHORT) --
resetAll(6);
ran = callZa0500('*LIVE');

monitor;
  assertEqualsNum('C1-BOUNDARY-AVAIL-EQ-MIN' : 5 : get('P00002'));
on-error;
endmon;

resetAll(5);
ran = callZa0500('*LIVE');

monitor;
  assertEqualsNum('C2-BOUNDARY-AVAIL-MIN-MINUS1' : 5 : get('P00002'));
on-error;
endmon;

// --- E: no lock left behind (read now, while SHORT lines just ran) ---
locked = *off;
monitor;
  open zaikom;
  opened = *on;
on-error;
endmon;

if opened;
  locked = isLocked('P00002');
  if not locked;
    locked = isLocked('P00005');
  endif;
  close zaikom;
endif;

monitor;
  assertTrue('E0-LOCK-CHECK-FILE-OPENED' : opened);
on-error;
endmon;

monitor;
  assertTrue('E1-NO-LOCK-LEFT-BEHIND' : not locked);
on-error;
endmon;

// --- D: NOTFOUND (last, it edits the QTEMP copy and restores it) -----
resetAll(3);
monitor;
  cmd = 'RUNSQL SQL(''DELETE FROM QTEMP/ZAIKOM WHERE ZASHO = ' +
        '''''P00006'''''') COMMIT(*NONE)';
  qcmdexc(cmd : %len(%trimr(cmd)));
on-error;
endmon;

monitor;
  assertEqualsNum('D1-GET-P00006-NOTFOUND' : -1 : get('P00006'));
on-error;
endmon;

ran = callZa0500('*LIVE');

monitor;
  assertTrue('D2-NOTFOUND-RUN-COMPLETED' : ran);
on-error;
endmon;

monitor;
  assertEqualsNum('D3-NOTFOUND-OTHERS-DEDUCTED' : 39 : get('P00001'));
on-error;
endmon;

// Put the deleted row back so the QTEMP copy is whole again.
monitor;
  cmd = 'RUNSQL SQL(''INSERT INTO QTEMP/ZAIKOM (ZASHO, ZASU, ZAUPD) ' +
        'VALUES (''''P00006'''', 22, 20260910)'') COMMIT(*NONE)';
  qcmdexc(cmd : %len(%trimr(cmd)));
on-error;
endmon;

*inlr = *on;
return;

// =====================================================================
// callZa0500 - call the program under test with minqty 5. Returns *on
// when the call finished normally, *off when it ended with an error.
// =====================================================================
dcl-proc callZa0500;
  dcl-pi *n ind;
    mode char(10) const;
  end-pi;

  dcl-s md char(10);
  dcl-s mq packed(5:0) inz(5);

  md = mode;
  monitor;
    za0500(md : mq);
    return *on;
  on-error;
    return *off;
  endmon;
  return *off;
end-proc;

// =====================================================================
// setStock - move one product to a target quantity with get() and
// reserve()/release(). A missing product is left alone.
// =====================================================================
dcl-proc setStock;
  dcl-pi *n;
    prodCode char(6) const;
    target   packed(7:0) const;
  end-pi;

  dcl-s cur packed(7:0);
  dcl-s ok  ind;

  cur = get(prodCode);
  if cur = -1;
    return;
  endif;

  if cur > target;
    ok = reserve(prodCode : cur - target);
  elseif cur < target;
    ok = release(prodCode : target - cur);
  endif;
end-proc;

// =====================================================================
// resetAll - the six products back to the load_v1 stock. P00002 takes
// a caller value so the boundary cases can start from 6 and 5.
// =====================================================================
dcl-proc resetAll;
  dcl-pi *n;
    p2 packed(7:0) const;
  end-pi;

  setStock('P00001' : 45);
  setStock('P00002' : p2);
  setStock('P00003' : 250);
  setStock('P00004' : 60);
  setStock('P00005' : 12);
  setStock('P00006' : 22);
end-proc;

// =====================================================================
// isLocked - read one product for update through this program own
// open of ZAIKOM. A record-in-use error means somebody still holds
// the lock. On success the lock just taken is released again.
// =====================================================================
dcl-proc isLocked;
  dcl-pi *n ind;
    prodCode char(6) const;
  end-pi;

  dcl-s err ind inz(*off);

  chain(e) prodCode zaikom;
  err = %error;
  if not err and %found(zaikom);
    unlock zaikom;
  endif;
  return err;
end-proc;
