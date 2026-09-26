      * V0601B - mixed fixed-form/free-form RPG IV demo (lesson 06-01b).
      * Ports R0402A (04-02, RPG III): 1580 x 1.10 = 1738.00, edit code 1.
      * UNTESTED on real hardware (PUB400 SSH access is rate-limited).
      *
      * Verified vs work/design/refs/ilerpgref75.txt: H/F/D-spec columns
      * near line 24125-29948; C-spec columns near line 36799-37085 (NOT
      * the same as RPG III; RPG III has no D-spec at all -- see report).
      * /FREE and /END-FREE became no-ops in 7.2, still accepted in 7.5
      * (near line 4204, 7536-7541); kept only so the reader can see the
      * fixed/free boundary (06-01b core concept 2), not because 7.5
      * requires them.
      * %EDITC (near line 45287) replaces the O-spec edit-code column
      * (RPG III has zero %-BIFs, appendix F). This realizes 06-01b core
      * concept 1; it is not counted as new syntax for this lesson.
      * WRITE to a program-described file needs a DS matching the file
      * record length exactly (near line 66329-66358).
      *
      * TODO: verify - hand-written by design (06-01 is the CVTRPGSRC-
      * converted lesson, V0601A); this file has not been compiled.
      * TODO: verify - exact %EDITC(...:'1') byte width for a 9,2 packed
      * field; TOTALX is sized with slack (15) until confirmed on hardware.

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
