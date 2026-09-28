**FREE
//=======================================================================
// T612OFHR - THROWAWAY probe (verify/part06-b7-bundle only, NOT shipped).
// Reuses P0612A's own externally described record formats (RPTHDR/
// RPTDTL) and the confirmed-working oflind(*in01) - see docs/probes.md's
// part06-b6-batch section for the OVRPRTF trick this manifest applies
// before calling this program (PAGESIZE(12 132) OVRFLW(10) forces
// overflow every ~9-10 lines instead of the real, much longer page).
//
// GOAL: show that RPTHDR (the banner record) can be re-WRITEn when
// *IN01 fires, and reset *IN01 back off before continuing - a concrete
// "header re-prints on overflow" demonstration for 06-12's page-break
// exercise, going beyond the RPTCNT-only evidence part06-b6-batch/
// part06-decisions-2 already gathered (neither of those probes ever
// WRITE RPTHDR at all - see p0612s.prtf's own STATUS header, 2026-09-28).
//=======================================================================

dcl-f p0612a printer usage(*output) oflind(*in01);

dcl-s i packed(3:0) inz(0);
dcl-s hdrCount packed(3:0) inz(1);

rptcust = 'HDR001';
write rpthdr;

dow i < 20;
  i += 1;
  rptnm = 'OFLIND HDR PROBE LINE';
  rptjuno = %char(i);
  rptjudt = 0;
  write rptdtl;
  if *in01;
    hdrCount += 1;
    rptcust = 'HDR00' + %char(hdrCount);
    write rpthdr;
    *in01 = *off;
  endif;
enddo;

*inlr = *on;
return;
