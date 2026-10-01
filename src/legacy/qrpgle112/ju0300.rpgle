      * HAND CONVERSION - UNVERIFIED (2026-10-01): not yet compiled with CRTBNDRPG nor
      * compared to the real CVTRPGSRC output; replace by real output (verify batch
      * part05-lgcvt) and keep the RPG III original (src/legacy/qrpgsrc) in sync.
      *
      * Made by converting src/legacy/qrpgsrc/ju0300.rpg column for column, as CVTRPGSRC
      * does. Only three edits were made on purpose: this header, the H spec
      * (DFTACTGRP(*YES)) and the 100-column limit of QRPGLE112. Code lines are
      * not modernized. Changes that follow from the RPG III -> RPG IV layout:
      *  - EXCPT -> EXCEPT, SETOF -> SETOFF, UPDAT -> UPDATE, DEFN -> DEFINE,
      *    array notation CT,IX -> CT(IX), *IN,60 -> *IN(60).
      *  - RPG IV allows one conditioning indicator per line (cols 9-11). A line
      *    with more than one is split: first indicator on its own line, the
      *    other ones on CAN lines, with the operation on the last CAN line.
      *    (Layout of these CAN lines is UNVERIFIED against real CVTRPGSRC.)
      *  - Resulting indicators moved from cols 54-59 to cols 71-76.
      *
      * JU0300 - order list (JUCHUM/JUCHUL1) with L1/L2 subtotals and a grand
      * total. Legacy system, fixed-form RPG IV (QRPGLE112, CRTBNDRPG).
      * Prints the same lines as the RPG III JU0300.
      *
      * Control levels: L1 = JUDATE (minor key), L2 = JUTOK (major key). This
      * follows the key order of JUCHUL1 (JUTOK, then JUDATE): the field that
      * changes less often must be the HIGHER level. LR gives the grand total.
      * Calculation order: blank level (detail), then L1, L2, LR.
      *
      * CT is a runtime array that collects the order count of each customer
      * at every L2 break. XFOOT cross-foots it at LR against GCNT (the same
      * count added one order at a time): XFOOT OK or MISMATCH is printed.
      * The guard compares IX with 49 BEFORE adding 1, so IX never passes 50.
      *
      * The unnamed UDS reads *LDA. FTOK is *LDA positions 11-16: an optional
      * customer code. When it is not blank, only the detail lines of that
      * customer are printed. Totals always cover all records. MN0000C uses
      * *LDA position 1, so FTOK is placed behind it on purpose.
      *
      * Indicators: 91 FTOK blank, 92 FTOK = JUTOK, 93 XFOOT = GCNT,
      * 94 at least one record was read (an empty JUCHUL1 prints nothing),
      * 90 array bound reached. The second DTL line is conditioned N91, so a
      * record with FTOK and JUTOK both blank cannot print twice (this is the
      * line that became a CAN pair).
      *
      * IX gets its length at its first ADD, after its first use in a COMP.
      * RPG III accepted this. Whether CRTBNDRPG does is UNVERIFIED.
      *
      * Run it with a library-qualified CALL (or ADDLIBLE in the same job), as
      * with JU0900C and ZA0500; an unqualified CALL hits the *LIBL hang.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DCT               S              5S 0 DIM(50)
     D                UDS
     DFTOK                    11     16
     IJUCHUR
     I                                          JUDATE        L1
     I                                          JUTOK         L2
     C                   SETON                                            94
     C                   ADD       1             L1CNT             5 0
     C                   ADD       1             GCNT              5 0
     C     FTOK          COMP      '      '                               91
     C     FTOK          COMP      JUTOK                                  92
     C   91              EXCEPT    DTL
     C  N91
     CAN 92              EXCEPT    DTL
     CL1 94              EXCEPT    L1BRK
     CL1                 ADD       L1CNT         L2CNT             5 0
     CL1                 Z-ADD     0             L1CNT
     CL2                 SETOFF                                       90
     CL2   IX            COMP      49                                 90
     CL2N90              ADD       1             IX                2 0
     CL2N90              Z-ADD     L2CNT         CT(IX)
     CL2 94              EXCEPT    L2BRK
     CL2                 Z-ADD     0             L2CNT
     CLR                 XFOOT     CT            XTOT              5 0
     CLR   XTOT          COMP      GCNT                                   93
     CLR 94              EXCEPT    GTOT
     OQSYSPRT   E            DTL
     O                       JUNO                10
     O                       JUTOK               20
     O                       JUDATE        Z     32
     O                       JUTAN               42
     O          E            L1BRK
     O                       JUTOK               10
     O                       JUDATE        Z     22
     O                                           45 'DATE TOTAL'
     O                       L1CNT         Z     55
     O          E            L2BRK
     O                       JUTOK               10
     O                                           45 'CUST TOTAL'
     O                       L2CNT         Z     55
     O          E            GTOT
     O                                           20 'GRAND TOTAL'
     O                       GCNT          Z     30
     O                                           40 'XFOOT='
     O                       XTOT          Z     50
     O               93                          60 'OK'
     O              N93                          70 'MISMATCH'
