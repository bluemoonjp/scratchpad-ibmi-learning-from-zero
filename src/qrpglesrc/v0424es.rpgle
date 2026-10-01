      * V0424E - calling side, NAME is 10 long but V0424A writes 30.
      * Port of R0408BE. Unlike R0408BE, NAME and GUARD sit in a data
      * structure with a 10-byte TAIL, so that all 30 bytes written by
      * V0424A land inside BUF (no storage outside BUF is touched).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DCODE             S              6A
     DRC               S              1P 0
     DBUF              DS
     D NAME                          10A
     D GUARD                         10A
     D TAIL                          10A
     C                   MOVEL     'C00001'      CODE
     C                   MOVE      *BLANKS       BUF
     C                   MOVEL     'GUARD'       GUARD
     C                   Z-ADD     9             RC
     C                   CALL      'V0424A'                             85
     C                   PARM                    CODE
     C                   PARM                    NAME
     C                   PARM                    RC
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            1 '/'
     O                       NAME                11
     O                                           12 '/'
     O                       GUARD               22
     O                                           23 '/'
     O                       RC                  24
     O               85                          40 'CALL FAILED'
