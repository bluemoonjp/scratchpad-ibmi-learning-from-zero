      * V0424B - calling side: pass a customer code, print the name.
      * Port of R0408BB. Calls V0424A. RC is set to 9 first so that a
      * change is visible. CALL error indicator 85 is in cols 73-74.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DCODE             S              6A
     DNAME             S             30A
     DRC               S              1P 0
     C                   MOVEL     'C00001'      CODE
     C                   MOVE      *BLANKS       NAME
     C                   Z-ADD     9             RC
     C                   CALL      'V0424A'                             85
     C                   PARM                    CODE
     C                   PARM                    NAME
     C                   PARM                    RC
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       CODE                 6
     O                                            8 '  '
     O                       NAME                38
     O                                           40 '  '
     O                       RC                  41
     O               85                          55 'CALL FAILED'
