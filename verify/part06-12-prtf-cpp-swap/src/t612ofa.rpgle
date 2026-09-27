**FREE
//=======================================================================
// T612OFA - THROWAWAY OFLIND probe, candidate A for the 06-12 overflow-
// indicator re-investigation (jiggly-greeting-crystal.md A-2/B-2). Not
// a shipped lesson source - deleted after the connection decides.
//
// Candidate A: externally described PRTF (reuses the real p0612s.prtf/
// P0612A object, already compiled by part06-12-prtf-cpp-swap's own
// CPP0612A step earlier in this same manifest), OFLIND referencing the
// predefined special indicator *INOA DIRECTLY on the dcl-f keyword -
// NO separate dcl-s declaration at all (contrast with the original,
// removed attempt: "dcl-s ovf ind;" + "oflind(ovf)", which hit RNF2037
// "Overflow Indicator is already defined"). If RNF2037 is specifically
// about naming an INDEPENDENT indicator variable (rather than reusing
// one of the *INOA-*INOG/*INOV/*IN01-*IN99 forms ilerpgref75.txt lines
// 27970-27988 list as the historically valid OFLIND parameters), this
// candidate avoids that by construction.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f p0612a printer usage(*output) oflind(*inoa);

dcl-s i int(5);
dcl-s overflowSeen ind inz(*off);

for i = 1 to 100;
  rptnm = 'OFLIND PROBE A LINE';
  rptjuno = %char(i);
  rptjudt = 0;
  write rptdtl;
  if *inoa;
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
