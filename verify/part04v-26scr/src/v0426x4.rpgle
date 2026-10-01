      * V0426X4 - NEGATIVE: two conditioning indicators on one C
      * line (RPG III habit: N03 in 9-11, 50 in 12-14).
     H
     FD0426A    CF   E             WORKSTN
     FTOKUIM    IF   E           K DISK
     C     *IN03         DOWEQ     *OFF
     C                   EXFMT     INQFMT
     C  N03TOKCD         CHAIN     TOKUIM                             50
     C  N03 50           MOVEL     'NOTFOUND'    TOKNM
     C                   ENDDO
     C                   SETON                                        LR
