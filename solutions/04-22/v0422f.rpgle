      * V0422F - answer to 04-22 exercise 4: N31, SETOFF and *IN30.
      * STOCK is 25, so indicator 30 (HI) is ON and 31 (LO) is OFF.
      * Expected: OVER (10 wide) then F=OK and S=OFF.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSTOCK            S              5P 0
     DTHRESH           S              5P 0
     DMSG              S             10A
     DFLAG             S              2A
     DST30             S              3A
     C                   Z-ADD     25            STOCK
     C                   Z-ADD     20            THRESH
     C     STOCK         COMP      THRESH                             303132
     C   30              MOVEL     'OVER'        MSG
     C   31              MOVEL     'REORDER'     MSG
     C   32              MOVEL     'EQUAL'       MSG
     C  N31              MOVEL     'OK'          FLAG
     C                   SETOFF                                       30
     C     *IN30         IFEQ      *OFF
     C                   MOVEL     'OFF'         ST30
     C                   ENDIF
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       MSG                 40
     O                                           44 '  F='
     O                       FLAG                46
     O                                           50 '  S='
     O                       ST30                53
