      * V0421D - JUCINQ3 as fixed-form RPG IV: order list for one customer.
      * Same printed lines as R0408A (RPG III, lesson 04-08).
      * Hand-written equivalent of CVTRPGSRC output (V0601A, lesson 06-01).
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E           K DISK
     FJUCHUM    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     C                   MOVEL     'C00001'      CUST              6
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
