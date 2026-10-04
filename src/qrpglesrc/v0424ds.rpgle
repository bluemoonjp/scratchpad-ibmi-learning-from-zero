      * V0424D - calling side: QTY is 3,0 but V0424C expects 5,0.
      * Calls V0424C. Output layout is the same as R0408BD.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DQTY              S              3P 0
     DFLG              S              1A
     C                   Z-ADD     5             QTY
     C                   MOVEL     '-'           FLG
     C                   CALL      'V0424C'                             85
     C                   PARM                    QTY
     C                   PARM                    FLG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       QTY                  5
     O                                            7 '  '
     O                       FLG                  8
     O               85                          25 'CALL FAILED'
