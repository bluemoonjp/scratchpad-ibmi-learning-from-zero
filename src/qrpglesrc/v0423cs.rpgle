      * V0423C - CHAIN with KLIST/KFLD: composite key (JUNO + JULINE).
      * No RPG III counterpart in part 4 (it is new for this route).
      * JUCHUD key is JUNO (6A) then JULINE (3S 0), in this order.
     H DFTACTGRP(*YES)
     FJUCHUD    IF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DKJUNO            S              6A
     DKLINE            S              3S 0
     C     JKEY          KLIST
     C                   KFLD                    KJUNO
     C                   KFLD                    KLINE
     C                   MOVEL     'J00001'      KJUNO
     C                   Z-ADD     2             KLINE
     C     JKEY          CHAIN     JUCHUD                             99
     C   99              MOVEL     'NOTFND'      JUSHO
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       JUNO                 6
     O                                            8 '  '
     O                       JULINE              11
     O                                           13 '  '
     O                       JUSHO               19
     O                                           21 '  '
     O                       JUSU                26
