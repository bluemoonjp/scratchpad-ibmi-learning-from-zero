**FREE
//=======================================================================
// T612OFC - THROWAWAY OFLIND probe, candidate C for the 06-12 overflow-
// indicator re-investigation (jiggly-greeting-crystal.md A-2/B-2). Not
// a shipped lesson source - deleted after the connection decides.
//
// Candidate C: PROGRAM-DESCRIBED printer file (no external DDS/PRTF
// object at all - contrast candidates A/B, which reuse the externally
// described P0612A). Same WRITE-a-data-structure technique f0607s.rpgle
// /f0608s.rpgle already use for QSYSPRT. Tests whether RNF2037 ("the
// Overflow Indicator is already defined") is specific to EXTERNALLY
// described printer files (where the DDS's own file description may
// already establish an implicit overflow indicator the RPG program
// cannot also name - ilerpgref75.txt lines 37590-37593: "If an
// overflow indicator has not been specified with the OFLIND keyword...
// the compiler assigns one to the file... except when...the printer
// uses externally described data") - if so, a program-described file
// (no external data description at all) should not hit this conflict.
//
// FIXED after connection 1 (part06-decisions-1): the file name below
// must be QSYSPRT, not an arbitrary program-described name. A program-
// described PRINTER file with a name OTHER than QSYSPRT is not auto-
// created by CRTBNDRPG - at RUN time RPG tried to OPEN an actual *FILE
// object named T612OFC and failed (CPF4101, "File T612OFC in library
// *LIBL not found"), escalating to an unmonitored RNX1216 program
// check. QSYSPRT is the one printer-file name that always exists as a
// shipped system object (same reason f0607s.rpgle/f0608s.rpgle can use
// it with zero setup) - renamed to reuse it, matching that convention.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f qsysprt printer(132) usage(*output) oflind(*inoa);

dcl-ds line len(132) end-ds;

dcl-s i int(5);
dcl-s overflowSeen ind inz(*off);

for i = 1 to 100;
  clear line;
  %subst(line:1:24) = 'OFLIND PROBE C LINE ' + %char(i);
  write qsysprt line;
  if *inoa;
    overflowSeen = *on;
  endif;
endfor;

clear line;
if overflowSeen;
  %subst(line:1:16) = 'OVERFLOW-SEEN=1';
else;
  %subst(line:1:16) = 'OVERFLOW-SEEN=0';
endif;
write qsysprt line;

*inlr = *on;
return;
