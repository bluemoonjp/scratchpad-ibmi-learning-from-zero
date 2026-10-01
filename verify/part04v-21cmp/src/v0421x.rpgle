      * V0421X - NEGATIVE EXAMPLE: the F spec for QSYSPRT is missing.
     H DFTACTGRP(*YES)
     C                   Z-ADD     1580          PRICE             7 2
     C                   Z-ADD     1.10          RATE              3 2
     C     PRICE         MULT      RATE          TOTAL             9 2
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOTAL         1     20
