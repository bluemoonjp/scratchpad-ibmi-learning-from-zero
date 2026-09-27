**FREE
//=======================================================================
// T612OFB - THROWAWAY OFLIND probe, candidate B for the 06-12 overflow-
// indicator re-investigation (jiggly-greeting-crystal.md A-2/B-2). Not
// a shipped lesson source - deleted after the connection decides.
//
// Candidate B: same externally described PRTF as candidate A, but
// OFLIND references a NUMBERED indicator (*IN01) instead of the *INOA
// named-overflow form - testing whether the numbered-indicator pool
// (ilerpgref75.txt lines 27970-27988: "*INOA-*INOG, *INOV, and *IN01
// through *IN99" are BOTH listed as historically valid OFLIND
// parameters) behaves differently from the *INOA family for an
// externally described printer file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f p0612a printer usage(*output) oflind(*in01);

dcl-s i int(5);
dcl-s overflowSeen ind inz(*off);

for i = 1 to 100;
  rptnm = 'OFLIND PROBE B LINE';
  rptjuno = %char(i);
  rptjudt = 0;
  write rptdtl;
  if *in01;
    overflowSeen = *on;
  endif;
endfor;

if overflowSeen;
  rptcnt = 1;
else;
  rptcnt = 0;
endif;
write rpttot;

*inlr = *on;
return;
