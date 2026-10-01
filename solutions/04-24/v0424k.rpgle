      * V0424K - calling side: call V0424J with 3 and 1500.
      * Port of R0408BG. Expected print: 4,500 (edit code 1).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DQTY              S              5P 0
     DPRICE            S              7P 0
     DTOTAL            S              9P 0
     C                   Z-ADD     3             QTY
     C                   Z-ADD     1500          PRICE
     C                   Z-ADD     0             TOTAL
     C                   CALL      'V0424J'                             85
     C                   PARM                    QTY
     C                   PARM                    PRICE
     C                   PARM                    TOTAL
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOTAL         1     12
     O               85                          30 'CALL FAILED'
