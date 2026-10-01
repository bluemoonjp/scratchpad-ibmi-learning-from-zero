      * V0425E - exercise 3 (04-25): two control levels on JUCHUL1.
      * L1 = JUDATE (changes more often), L2 = JUTOK (changes less often).
      * A small version of the legacy JU0300: date subtotal, customer
      * subtotal and a grand total at LR. No array and no XFOOT.
      * Calculation order: detail, then L1, then L2, then LR.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     IJUCHUR
     I                                          JUDATE        L1
     I                                          JUTOK         L2
     C                   ADD       1             L1CNT             3 0
     C                   ADD       1             GCNT              3 0
     C                   EXCEPT    DTL
     CL1                 EXCEPT    L1BRK
     CL1                 ADD       L1CNT         L2CNT             3 0
     CL1                 Z-ADD     0             L1CNT
     CL2                 EXCEPT    L2BRK
     CL2                 Z-ADD     0             L2CNT
     CLR                 EXCEPT    GTOT
     OQSYSPRT   E            DTL
     O                       JUNO                10
     O                       JUTOK               20
     O                       JUDATE              30
     O          E            L1BRK
     O                       JUTOK               10
     O                       JUDATE              22
     O                                           35 'DATE TOTAL'
     O                       L1CNT               39
     O          E            L2BRK
     O                       JUTOK               10
     O                                           35 'CUST TOTAL'
     O                       L2CNT               39
     O          E            GTOT
     O                                           20 'GRAND TOTAL'
     O                       GCNT                24
