      * T423N3 - CHAIN: look up one customer by key (TOKCD).
      * Fixed-form RPG IV port of R0407A (04-07). Prints the same line.
      * NEGATIVE PROBE 3: K in col 31 (RPG III) instead of col 34.
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E        K    DISK
     FQSYSPRT   O    F  132        PRINTER
     C     'C00001'      CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    TOKNM
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOKCD                6
     O                                            8 '  '
     O                       TOKNM               38
