      * V0426C - exercise 2 answer: V0426A with MOVEL(P) so that
      * NOTFOUND never leaves the tail of the previous name.
      * Needs display file D0426A (same screen as V0426A).
     H
     FD0426A    CF   E             WORKSTN
     FTOKUIM    IF   E           K DISK
     C     *IN03         DOWEQ     *OFF
     C                   EXFMT     INQFMT
     C     *IN03         IFEQ      *OFF
     C     TOKCD         CHAIN     TOKUIM                             50
     C   50              MOVEL(P)  'NOTFOUND'    TOKNM
     C                   ENDIF
     C                   ENDDO
     C                   SETON                                        LR
