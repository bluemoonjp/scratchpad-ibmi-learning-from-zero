      * V0421B - C-spec columns and arithmetic (tax-inclusive price).
      * Same printed line as R0402A (RPG III, lesson 04-02): 1,738.00
      * Fields are defined on the C spec itself (length cols 64-68,
      * decimals cols 69-70), the same idea as RPG III but other columns.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     C                   Z-ADD     1580          PRICE             7 2
     C                   Z-ADD     1.10          RATE              3 2
     C     PRICE         MULT      RATE          TOTAL             9 2
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOTAL         1     20
