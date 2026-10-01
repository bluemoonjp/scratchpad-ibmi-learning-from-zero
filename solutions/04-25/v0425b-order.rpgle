      * V0425B - exercise 1 (04-25): the L1 lines BEFORE the detail lines.
      * Same as V0425A except for the order of the C specs. The compiler
      * is expected to reject this order; the message id is recorded by the
      * verify batch part04v-25run, not guessed here. Do not use as a model.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DCNT              S              3S 0
     IJUCHUR
     I                                          JUTOK         L1
     CL1                 EXCEPT    BRK
     CL1                 Z-ADD     0             CNT
     C                   ADD       1             CNT
     C                   EXCEPT    DTL
     OQSYSPRT   E            DTL
     O                       JUTOK               10
     O                       JUNO                20
     O          E            BRK
     O                                           10 '  SUBTOTAL'
     O                       JUTOK               25
     O                       CNT                 30
