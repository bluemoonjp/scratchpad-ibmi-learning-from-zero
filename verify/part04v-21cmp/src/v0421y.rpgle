      * V0421Y - NEGATIVE EXAMPLE: MULT starts in column 27, not 26.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     C                   Z-ADD     1580          PRICE             7 2
     C                   Z-ADD     1.10          RATE              3 2
     C     PRICE          MULT     RATE          TOTAL             9 2
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOTAL         1     20
