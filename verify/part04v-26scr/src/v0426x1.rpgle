      * V0426X1 - NEGATIVE: combined WORKSTN file, col 18 blank.
      * (RPG III needed F in col 16 for EXFMT; RPG IV: col 18.)
     H
     FD0426A    C    E             WORKSTN
     FTOKUIM    IF   E           K DISK
     C     *IN03         DOWEQ     *OFF
     C                   EXFMT     INQFMT
      * RPG III allowed N03 and 50 on one line; RPG IV has one
      * indicator slot (cols 9-11), so test 03 with an IF block.
     C     *IN03         IFEQ      *OFF
     C     TOKCD         CHAIN     TOKUIM                             50
     C   50              MOVEL     'NOTFOUND'    TOKNM
     C                   ENDIF
     C                   ENDDO
     C                   SETON                                        LR
