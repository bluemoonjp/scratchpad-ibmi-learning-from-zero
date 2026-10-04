      * V0424J - called side: line total = QTY x PRICE.
      * Port of R0408BF. PARM 1 QTY 5,0 in, PARM 2 PRICE 7,0 in,
      * PARM 3 TOTAL 9,0 out.
     H DFTACTGRP(*YES)
     DQTY              S              5P 0
     DPRICE            S              7P 0
     DTOTAL            S              9P 0
     C     *ENTRY        PLIST
     C                   PARM                    QTY
     C                   PARM                    PRICE
     C                   PARM                    TOTAL
     C     QTY           MULT      PRICE         TOTAL
     C                   SETON                                        LR
     C                   RETURN
