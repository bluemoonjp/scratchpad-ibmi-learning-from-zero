      * V0422A - MOVE/MOVEL leave old data behind; CLEAR first to avoid it.
      * Fixed-form RPG IV port of R0403A (04-03). Same print line.
      * Expected: A=JOHNSON     B=ALHNSON     C=123456  D=1234AB  E=BOB
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DNAME1            S             10A
     DNAME2            S             10A
     DNAME3            S             10A
     DCODE1            S              6A
     DCODE2            S              6A
     C                   MOVEL     'JOHNSON'     NAME1
     C                   MOVEL     'JOHNSON'     NAME2
     C                   MOVEL     'AL'          NAME2
     C                   MOVE      '123456'      CODE1
     C                   MOVE      '123456'      CODE2
     C                   MOVE      'AB'          CODE2
     C                   MOVEL     'XX'          NAME3
     C                   CLEAR                   NAME3
     C                   MOVEL     'BOB'         NAME3
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            2 'A='
     O                       NAME1               12
     O                                           16 '  B='
     O                       NAME2               26
     O                                           30 '  C='
     O                       CODE1               36
     O                                           40 '  D='
     O                       CODE2               46
     O                                           50 '  E='
     O                       NAME3               60
