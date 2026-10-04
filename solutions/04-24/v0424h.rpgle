      * V0424H - called side: reorder check. QTY is 5,0 (packed).
      * PARM 1 QTY 5,0 in, PARM 2 FLG 1 out (R = reorder, O = ok).
      * Like V0424F, but the *PSSR ends with ENDSR *CANCL (escape to the
      * caller). The *PSSR touches only FLG, so it cannot loop.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DFLG              S              1A
     C     *ENTRY        PLIST
     C                   PARM                    QTY
     C                   PARM                    FLG
     C     QTY           COMP      10                                   90
     C   90              MOVEL     'R'           FLG
     C  N90              MOVEL     'O'           FLG
     C                   SETON                                        LR
     C                   RETURN
     C     *PSSR         BEGSR
     C                   MOVEL     'E'           FLG
     C                   ENDSR     '*CANCL'
