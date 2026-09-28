      * V0601B - mixed fixed-form/free-form RPG IV demo (lesson 06-01b).
      * Ports R0402A (04-02, RPG III): 1580 x 1.10 = 1738.00, edit code 1.
      * CONFIRMED on real hardware (part06-0103-freeform, 2026-09-26):
      * CRTBNDRPG Highest Severity 00, CALL prints '1,738.00', matching
      * R0402A's own real-machine value (not byte-for-byte identical as a
      * print record -- R0402A's O-spec is 132 bytes wide, this is 15;
      * only the edited digits match). See docs/probes.md.
      *
      * H/F/D-spec and C-spec column positions here are NOT the same as
      * RPG III's (RPG III has no D-spec at all -- see the 06-01b lesson
      * prose for the full side-by-side column table).
      * /FREE and /END-FREE are accepted (though no longer required by
      * the compiler); kept only so the reader can see the fixed/free
      * boundary (06-01b core concept 2).
      * %EDITC is the free-form successor to the O-spec edit-code column
      * (RPG III has zero %-BIFs, appendix F; the O-spec column itself
      * still works unchanged in fixed-form RPG IV -- %EDITC is only
      * required because this file's total is built in a /FREE block).
      * This realizes 06-01b core concept 1; it is not counted as new
      * syntax for this lesson.
      * WRITE to a program-described file needs a DS matching the file
      * record length exactly.
      *
      * (Earlier drafts of this comment said this file was untested and
      * had not been compiled -- that was already stale by the time
      * 06-01b was written: part06-0103-freeform had settled it,
      * including the %EDITC(...:'1') width against this 9,2 packed
      * field -- 15 bytes was enough, no truncation observed.)

     H

     FQSYSPRT   O    F   15        PRINTER

      * PRICE P(7,2) / RATE P(3,2) / TOTAL P(9,2): same attributes as
      * R0402A (04-02 hardware memo confirms these on the real machine).
     DPRICE            S              7P 2
     DRATE             S              3P 2
     DTOTAL            S              9P 2
      * 15-byte print record for QSYSPRT: the edited total (edit code 1).
     DOUTREC           DS
     DTOTALX                         15A

      /FREE
       // Tax calc, EVAL-style assignments (no opcode column needed).
       price = 1580;
       rate = 1.10;
       total = price * rate;
       // Edit code 1: successor to R0402A's O-spec edit-code column.
       totalx = %editc(total : '1');
      /END-FREE
      * WRITE and SETON stay fixed-form here (on purpose, not because
      * they must): it gives the reader code on both sides of the line.
     C                   WRITE     QSYSPRT       OUTREC
     C                   SETON                                        LR
