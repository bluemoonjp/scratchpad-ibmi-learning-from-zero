**FREE
//=======================================================================
// T643HOLD - THROWAWAY probe (verify/part06-p43-lockdiag only, NOT
// shipped). Acquires an update-mode CHAIN(e) lock on one SHOHIM record
// and holds it for a bounded time (DLYJOB via QCMDEXC, the same **FREE
// QCMDEXC technique CONFIRMED on real hardware in F0605B/
// part06-b8-compile, 2026-09-28), so a SEPARATE, genuinely concurrent
// job (this batch SBMJOBs this program - P15's own technique, otherwise
// unused anywhere in this repo) can be shown colliding with it -
// P43 (lock diagnosis) - the whole point of this probe - and the
// exact mechanism 06-11b's F0611BA already assumes (chain(e)+%error+
// %status(shohim)=1218, src/qrpglesrc/f0611bs.rpgle) but has never been
// tested against a REAL second-job conflict (only compiled, V1).
//
// P00006 (MONITOR STAND) is used deliberately: it is not the baseline
// record for any other probe or lesson exercise in this repo (P00001 is
// used pervasively, P00002/P00005 are the low-stock fixtures), so
// holding its lock here cannot interfere with anything else. This
// program only CHAINs(e) - it never WRITEs/UPDATEs/DELETEs, so SHOHIM's
// contents are unchanged regardless of outcome; no TXRESET is needed.
//=======================================================================

dcl-f shohim usage(*update) keyed;

dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd char(200) const;
  cmdLen packed(15:5) const;
end-pr;

dcl-s cmd char(200);
dcl-s cmdLen packed(15:5);
dcl-s holdKey char(6) inz('P00006');

chain(e) holdKey shohim;

cmd = 'DLYJOB DLY(30)';
cmdLen = %len(%trimr(cmd));
qcmdexc(cmd : cmdLen);

*inlr = *on;
return;
