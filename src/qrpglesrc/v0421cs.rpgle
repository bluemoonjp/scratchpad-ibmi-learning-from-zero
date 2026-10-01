      * V0421C - arithmetic opcodes in fixed-form RPG IV.
      * Z-ADD ADD SUB MULT DIV MVR, ADD with factor 1 blank, and
      * silent truncation (TRUNCNBR default *YES). Prints one line:
      * SUM=   13 DIF=    7 MUL=   30 QUO=    3 REM=    1 CNT=   42 OVF=99990
      * Unlike V0421B, the fields are declared on D specs (5P 0 is
      * packed, 5 digits, 0 decimals); the C specs carry no length.
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DNUMA             S              5P 0
     DNUMB             S              5P 0
     DSUMV             S              5P 0
     DDIFV             S              5P 0
     DMULV             S              5P 0
     DQUOV             S              5P 0
     DREMV             S              5P 0
     DCNTV             S              5P 0
     DBIGV             S              5P 0
     DOVFV             S              5P 0
     C                   Z-ADD     10            NUMA
     C                   Z-ADD     3             NUMB
     C     NUMA          ADD       NUMB          SUMV
     C     NUMA          SUB       NUMB          DIFV
     C     NUMA          MULT      NUMB          MULV
      * MVR must come immediately after the DIV it belongs to.
     C     NUMA          DIV       NUMB          QUOV
     C                   MVR                     REMV
      * Factor 1 blank: result = result + factor 2.
     C                   Z-ADD     41            CNTV
     C                   ADD       1             CNTV
      * 99999 x 10 = 999990 does not fit in 5 digits: high-order
      * digit is dropped without any message (TRUNCNBR(*YES)).
     C                   Z-ADD     99999         BIGV
     C     BIGV          MULT      10            OVFV
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            4 'SUM='
     O                       SUMV          3      9
     O                                           14 'DIF='
     O                       DIFV          3     19
     O                                           24 'MUL='
     O                       MULV          3     29
     O                                           34 'QUO='
     O                       QUOV          3     39
     O                                           44 'REM='
     O                       REMV          3     49
     O                                           54 'CNT='
     O                       CNTV          3     59
     O                                           64 'OVF='
     O                       OVFV          3     69
