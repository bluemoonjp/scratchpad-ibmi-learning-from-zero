**FREE
//=======================================================================
// T612OFRF - THROWAWAY OVRPRTF overflow probe (part06-b6-batch, advisor
// review item 4/1). Not a shipped lesson source - deleted after the
// connection decides.
//
// PURPOSE: f0612s.rpgle's oflind(*in01) confirmation (part06-decisions-
// 2) showed *IN01 compiling and printing correctly, but never actually
// turning ON across 100 printed lines - leaving open whether the
// default form length is simply longer than 100 lines, or whether this
// harness's job (no real spooled file - CPYSPLF always fails here)
// makes overflow detection impossible in principle. This probe forces
// a SMALL page size (12 lines, overflow at line 10) via OVRPRTF before
// writing 30 lines, to settle the question either way.
//
// Reuses P0612A's own externally described record formats (RPTDTL, via
// a fresh member/object T612OFRF against the SAME DDS file P0612A -
// already compiled and confirmed, part06-12-prtf-cpp-swap) with
// oflind(*in01) (the confirmed-working form for this externally
// described printer file).
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f p0612a printer usage(*output) oflind(*in01);

dcl-s i int(5);
dcl-s overflowSeen ind inz(*off);
dcl-s overflowLine int(5) inz(0);

for i = 1 to 30;
  rptnm = 'OVRPRTF PROBE LINE';
  rptjuno = %char(i);
  rptjudt = 0;
  write rptdtl;
  if *in01;
    if not overflowSeen;
      overflowLine = i;
    endif;
    overflowSeen = *on;
  endif;
endfor;

if overflowSeen;
  rptcnt = overflowLine;
else;
  rptcnt = 0;
endif;
write rpttot;

*inlr = *on;
return;
