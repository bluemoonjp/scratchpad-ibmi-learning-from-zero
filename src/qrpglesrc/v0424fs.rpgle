      * V0424F - called side: reorder check. QTY is 5,0 (packed).
      * PARM 1 QTY 5,0 in, PARM 2 FLG 1 out (R = reorder, O = ok).
      * Port of R0408BC plus a *PSSR that ends with RETURN. The *PSSR
      * touches only FLG (character), so it cannot fail and loop.
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
     C                   SETON                                        LR
     C                   RETURN
     C                   ENDSR
