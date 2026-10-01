      * V24PL - PROBE: PARM defines its own fields by length on the
      * C spec (RPG III style). Success or failure is recorded.
     H DFTACTGRP(*YES)
     C     *ENTRY        PLIST
     C                   PARM                    QTY               5 0
     C                   PARM                    FLG               1
     C                   MOVEL     'O'           FLG
     C                   SETON                                        LR
     C                   RETURN
