      * V0422C - structured opcodes (IFxx/ANDxx/DOWxx) and a subroutine.
      * Fixed-form RPG IV port of R0405A (04-05).
      * Expected: A             SUM= 00015
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSCORE            S              3P 0
     DSUM              S              5P 0
     DI                S              3P 0
     DGRADE            S             10A
     C                   Z-ADD     82            SCORE
     C                   Z-ADD     0             SUM
     C                   Z-ADD     1             I
     C     SCORE         IFGE      80
     C     SCORE         ANDLE     100
     C                   MOVEL     'A'           GRADE
     C                   ELSE
     C                   MOVEL     'B'           GRADE
     C                   ENDIF
     C     I             DOWLE     5
     C                   ADD       I             SUM
     C                   ADD       1             I
     C                   ENDDO
     C                   EXSR      PRTOUT
     C                   SETON                                        LR
     C     PRTOUT        BEGSR
     C                   EXCEPT
     C                   ENDSR
     OQSYSPRT   E
     O                       GRADE               10
     O                                           18 '  SUM='
     O                       SUM                 24
