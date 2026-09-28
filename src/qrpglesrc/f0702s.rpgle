**FREE
//=======================================================================
// F0702A - offline comparison client for JUCSRV's getCustName (Part 7,
// lesson 07-02).
//
// Per work/design/part07-design-v1.md section 0.2/07-02 entry (a
// deliberate, explicit decision made after review): this program is an
// OFFLINE comparison client ONLY. It is never wired into the live
// JUCINQ command (no CHGCMD anywhere in this lesson) - JUCINQ's CPP
// swap to F0612A was already demonstrated once, in 06-12
// (src/qrpglesrc/f0612s.rpgle's own header comment), and re-doing it
// here would not teach anything new about *SRVPGM/*BNDDIR, this
// lesson's actual subject.
//
// PROGRAM-ENTRY INTERFACE: must match JUCINQC/F0612A's interface
// EXACTLY, so its output can be compared against F0612A's for the same
// input. Confirmed against the real sources:
//   solutions/03-09/jucinqc.clp, line 4:  PGM PARM(&TOKCD)
//   solutions/03-09/jucinqc.clp, line 7:  DCL VAR(&TOKCD) TYPE(*CHAR)
//                                          LEN(6)
//   src/qcmdsrc/jucinq.cmd, lines 1-3:    PARM KWD(TOKCD) TYPE(*CHAR)
//                                          LEN(6) MIN(1)
//   src/qrpglesrc/f0612s.rpgle, line 156: cust char(6);  (its own
//                                         program-entry dcl-pi)
// All agree: exactly one required CHAR(6) parameter. The dcl-pi below
// declares exactly that, named "cust" (matching f0612s.rpgle's own
// local name for this same value, for the same reason it gives: no
// collision risk either way here, since this program has no dcl-f of
// its own to collide with - it calls JUCSRV instead of touching TOKUIM
// directly).
//
// Binding: this is the FIRST program in this repo compiled with
// ctl-opt bnddir() and called through *LIBL symbol resolution rather
// than a hardcoded CALL/prototype target (Issue #8's own checklist
// item for 07-02). Confirmed:
//   CTL-OPT BNDDIR('name')                    ilerpgref75.txt lines
//     - unqualified name resolves via         24335-24349 ("If the
//       *LIBL at bind time, matching           library name is not
//       style-guide.md's "do not hardcode      specified, *LIBL is
//       library names in source" rule          used to find the
//                                               binding directory")
//   DFTACTGRP(*NO)/ACTGRP(*NEW) required       ilerpgref75.txt lines
//     for a bound (non-EXTPGM) procedure         25073-25074, matching
//     call such as getCustName, same reason      f0605s.rpgle's own
//     f0605s.rpgle's calcTaxTotal call needed     rationale for
//     it                                          calcTaxTotal
//   EXTPROC(*DCLCASE) on the prototype below   ilerpgref75.txt lines
//     matches jucsrv.rpgle's own EXTPROC(       31699 ("The external
//     *DCLCASE) choice on getCustName's own     name for the
//     DCL-PI, so both sides agree on the        getCustomerCity
//     external/export name "getCustName"        prototype is
//     (mixed case) - see jucsrv.rpgle's          'getCustomerCity'")
//     header comment for the full rationale
//
// Build (07-02, before src/qsrvsrc/ exists - EXPORT(*ALL) on JUCSRV):
//     CRTBNDRPG PGM(<USER>1/F0702A) SRCFILE(<USER>1/QRPGLESRC)
//               SRCMBR(F0702S)
// (F0702A binds against whatever signature JUCSRV/JUCSRVBD expose at
// this point - the getCustName-only signature from 07-02. It must be
// rebound once in 07-03 step 2, after pingJucsrv changes that
// signature - see jucsrv.rpgle's own header comment for exactly when
// and why. F0702A is NOT recompiled again after that, in 07-03 step 3 -
// see f0703s.rpgle instead for the client that exercises the NEW
// countCustOrders export.)
//
// Message technique: reused VERBATIM from f0609s.rpgle's QMHSNDPM/
// PSDS-free job-log wrapper (sendToJobLog + the qmhsndpm prototype and
// its two template data structures), per this lesson's own task
// instructions ("reuse it verbatim, don't reinvent"). Duplicated here
// rather than shared via /copy or a bindable JUCUTL-style utility,
// matching Part 6's own established convention of NOT sharing this
// exact block across files (f0605s.rpgle/f0606s.rpgle's own header
// comments both note this) - and, more concretely here, because this
// lesson does not depend on 07-01's JUCUTL module actually existing as
// a compiled artifact (it is not part of this task and has no
// committed source in this repo yet).
//
// STATUS: CONFIRMED on real hardware. getCustName's own call is V2
// (part07-0203-srvpgm, 2026-09-27: "getCustName(C00001) = ACME
// TRADING CO"). The full rebind/break/fix cycle this file undergoes
// in 07-03 (EXPORT(*ALL) rebuild breaks it with MCH4431, then binder
// source restores it without recompiling this file) is V2-confirmed
// (part07-03-signature, 2026-09-28) - see src/qrpglesrc/jucsrv.rpgle's
// and src/qsrvsrc/jucsrv.bnd's own headers for the full sequence.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('JUCSRVBD');

//-----------------------------------------------------------------------
// dcl-pr / EXTPROC(*DCLCASE): prototype for JUCSRV's getCustName. See
// the header comment above for why *DCLCASE (not a bare EXTPROC, and
// not the compiler's uppercase default) is used.
//-----------------------------------------------------------------------
dcl-pr getCustName char(30) extproc(*dclcase);
  custCode char(6) const;
end-pr;

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: prototype for QMHSNDPM, copied verbatim from
// f0609s.rpgle (itself copied from ilerpgref75.txt's own worked example,
// lines 13744-13773, procedure "sendException").
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
// Program-entry dcl-pi: matches JUCINQC/F0612A exactly (see header
// comment above). "cust", not "custCode" - purely a naming choice, no
// collision either way (see header comment).
//-----------------------------------------------------------------------
dcl-pi *n;
  cust char(6);
end-pi;

dcl-s custName char(30);

custName = getCustName(cust);
sendToJobLog('F0702A: getCustName(' + cust + ') = '
               + %trimr(custName));

*inlr = *on;
return;

//=======================================================================
// sendToJobLog: verbatim from f0609s.rpgle (see that file's own header
// comment for the full rationale, including the *INFO-vs-*ESCAPE TODO
// it already flags - unchanged here).
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
