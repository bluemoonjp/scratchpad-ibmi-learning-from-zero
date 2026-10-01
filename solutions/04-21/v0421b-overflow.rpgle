      * V0421S - exercise 2 answer: TOTAL shrunk to 4 digits (2 decimals).
      * 1738.00 does not fit; the high-order digits are dropped silently.
      * Expected line (to be confirmed on the machine): 38.00
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     C                   Z-ADD     1580          PRICE             7 2
     C                   Z-ADD     1.10          RATE              3 2
     C     PRICE         MULT      RATE          TOTAL             4 2
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOTAL         1     20
