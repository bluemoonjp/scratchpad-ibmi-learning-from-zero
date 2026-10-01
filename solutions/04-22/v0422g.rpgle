      * V0422G - answer to 04-22 exercise 6: IFxx/ORxx, SCORE out of range.
      * SCORE is 120, so GRADE becomes X. Expected: X             SUM= 00015
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DSCORE            S              3P 0
     DSUM              S              5P 0
     DI                S              3P 0
     DGRADE            S             10A
     C                   Z-ADD     120           SCORE
     C                   Z-ADD     0             SUM
     C                   Z-ADD     1             I
     C     SCORE         IFLT      0
     C     SCORE         ORGT      100
     C                   MOVEL     'X'           GRADE
     C                   ELSE
     C     SCORE         IFGE      80
     C                   MOVEL     'A'           GRADE
     C                   ELSE
     C                   MOVEL     'B'           GRADE
     C                   ENDIF
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
