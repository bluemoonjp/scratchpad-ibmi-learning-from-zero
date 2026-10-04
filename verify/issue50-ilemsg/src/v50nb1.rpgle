      * V50NB1 - CALL to a program that does not exist, WITHOUT an error
      * indicator (cols 73-74 blank). verify/issue50-ilemsg only.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C                   Z-ADD     7             QTY
     C                   CALL      'V50MISS'
     C                   PARM                    QTY
     C                   PARM                    FLG
     C                   SETON                                        LR
