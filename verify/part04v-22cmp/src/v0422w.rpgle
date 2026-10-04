      * V0422W - NEGATIVE: RPG III spelling EXCPT in RPG IV.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DMSG              S             10A
     C                   MOVEL     'HELLO'       MSG
     C                   EXCPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       MSG                 10
