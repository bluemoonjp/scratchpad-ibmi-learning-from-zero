      * V24NC - NEGATIVE: CALL error indicator in cols 71-72 (RPG III
      * habit; RPG IV wants it in cols 73-74). Positions 71-72 must be blank.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C                   CALL      'V0424C'                           85
     C                   PARM                    QTY
     C                   PARM                    FLG
     C                   SETON                                        LR
