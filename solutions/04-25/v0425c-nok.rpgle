      * V0425C - exercise 2 (04-25): V0425A WITHOUT the K in column 34.
      * Without K the keyed logical file is read in arrival order, so the
      * customer code changes on almost every record. Compare the number of
      * SUBTOTAL lines with V0425A. Do not use as a model.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     IJUCHUR
     I                                          JUTOK         L1
     C                   ADD       1             CNT               3 0
     C                   EXCEPT    DTL
     CL1                 EXCEPT    BRK
     CL1                 Z-ADD     0             CNT
     OQSYSPRT   E            DTL
     O                       JUTOK               10
     O                       JUNO                20
     O          E            BRK
     O                                           10 '  SUBTOTAL'
     O                       JUTOK               25
     O                       CNT                 30
