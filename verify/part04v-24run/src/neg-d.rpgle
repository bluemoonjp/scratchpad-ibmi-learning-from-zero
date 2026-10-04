      * V24ND - NEGATIVE: PARM defines QTY with length 3,0 on the C spec
      * while the D spec says 5P 0 (lengths must agree).
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C     *ENTRY        PLIST
     C                   PARM                    QTY               3 0
     C                   PARM                    FLG
     C                   SETON                                        LR
     C                   RETURN
