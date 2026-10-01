      * V0422X - NEGATIVE: COMP indicators put in the RPG III place 54-59.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSTOCK            S              5P 0
     DTHRESH           S              5P 0
     DMSG              S             10A
     C                   Z-ADD     15            STOCK
     C                   Z-ADD     20            THRESH
     C     STOCK         COMP      THRESH            303132
     C   31              MOVEL     'REORDER'     MSG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       MSG                 40
