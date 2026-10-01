      * V0421T - exercise 3 answer: V0421D for customer C00003.
      * Expected: J00004 and J00008 lines for the customer of C00003.
      * Only the literal in the first C spec differs from V0421D.
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E           K DISK
     FJUCHUM    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     C                   MOVEL     'C00003'      CUST              6
     C     CUST          CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    TOKNM
     C     LOOP          TAG
     C                   READ      JUCHUM                                 98
     C   98              GOTO      ENDLP
     C     JUTOK         IFEQ      CUST
     C                   EXCEPT
     C                   ENDIF
     C                   GOTO      LOOP
     C     ENDLP         TAG
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOKNM               30
     O                                           32 '  '
     O                       JUNO                38
     O                                           40 '  '
     O                       JUDATE              48
