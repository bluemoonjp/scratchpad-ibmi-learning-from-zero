      * V0421W - NEGATIVE EXAMPLE: C specs typed with RPG III columns.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     C                     Z-ADD1580      PRICE   72
     C                     Z-ADD1.10      RATE    32
     C           PRICE     MULT RATE      TOTAL   92
     C                     EXCEPT
     C                     SETON                                      LR
     OQSYSPRT   E
     O                       TOTAL         1     20
