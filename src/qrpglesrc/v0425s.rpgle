      * V0425A - order list with a subtotal per customer (control level L1).
      * Fixed-form RPG IV port of R0410A (04-10): same print lines.
      * JUCHUL1 is the PRIMARY file (IP): the RPG cycle reads it by itself,
      * no READ and no GOTO. L1 is declared on the I spec for JUTOK.
      * Source order: detail lines (blank level) first, then the L1 lines.
      * I spec: field name from column 49, control level in columns 63-64.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E           K DISK
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
