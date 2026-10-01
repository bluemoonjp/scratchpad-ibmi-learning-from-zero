      * V0422Y - NEGATIVE: CLEAR target in factor 2 (RPG III place).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DNAME3            S             10A
     C                   MOVEL     'XX'          NAME3
     C                   CLEAR     NAME3
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       NAME3               10
