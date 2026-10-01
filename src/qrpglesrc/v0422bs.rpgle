      * V0422B - indicators and COMP: is stock below the reorder point?
      * Fixed-form RPG IV port of R0404A (04-04). Prints REORDER.
      * COMP result indicators are in columns 71-76 here (54-59 in RPG III).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSTOCK            S              5P 0
     DTHRESH           S              5P 0
     DMSG              S             10A
     C                   Z-ADD     15            STOCK
     C                   Z-ADD     20            THRESH
     C     STOCK         COMP      THRESH                             303132
     C   30              MOVEL     'OVER'        MSG
     C   31              MOVEL     'REORDER'     MSG
     C   32              MOVEL     'EQUAL'       MSG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       MSG                 40
