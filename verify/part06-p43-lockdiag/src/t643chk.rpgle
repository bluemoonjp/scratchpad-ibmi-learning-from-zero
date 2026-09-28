**FREE
//=======================================================================
// T643CHK - THROWAWAY probe (verify/part06-p43-lockdiag only, NOT
// shipped). Reuses F0611BA's own confirmed-shape logic verbatim
// (src/qrpglesrc/f0611bs.rpgle: chain(e) + %error + %status(shohim) =
// 1218 - see that file's ADD-path comment) against the SAME record
// T643HOLD is deliberately holding (P00006), to prove this pattern
// really detects a genuine cross-job lock conflict, not just compiles.
// The observed outcome ('LOCK '/'NOLCK') is written to *LDA bytes 61-65
// via QCMDEXC+CHGDTAARA (same technique CONFIRMED today in F0605B/
// part06-b8-compile - a different byte range from F0605B's own 21-40
// and za0510's 1-20, so none collide if run in the same job) so it
// survives as plain, inspectable evidence alongside the WRKOBJLCK/
// DSPRCDLCK output this same connection prints.
//=======================================================================

dcl-f shohim usage(*update) keyed;

dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd char(200) const;
  cmdLen packed(15:5) const;
end-pr;

dcl-s cmd char(200);
dcl-s cmdLen packed(15:5);
dcl-s chkKey char(6) inz('P00006');
dcl-s statusText char(5);
dcl-s q char(1) inz('''');

chain(e) chkKey shohim;
if %error and %status(shohim) = 1218;
  statusText = 'LOCK ';
else;
  statusText = 'NOLCK';
endif;

cmd = 'CHGDTAARA DTAARA(*LDA (61 5)) VALUE(' + q + statusText + q + ')';
cmdLen = %len(%trimr(cmd));
qcmdexc(cmd : cmdLen);

*inlr = *on;
return;
