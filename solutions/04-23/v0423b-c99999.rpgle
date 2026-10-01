      * V0423B - CHAIN: look up one customer by key (TOKCD).
      * Fixed-form RPG IV port of R0407A (04-07). Prints the same line.
      * Exercise 1 answer: key changed to C99999 (not found).
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     C     'C99999'      CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    TOKNM
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOKCD                6
     O                                            8 '  '
     O                       TOKNM               38
