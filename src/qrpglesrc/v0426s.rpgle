      * V0426A - TOKUIM inquiry screen (WORKSTN, EXFMT, F3=exit).
      * Ports R0411A (RPG III, lesson 04-11) to fixed-form RPG IV.
      * Same screen (D0426A = R0411A DDS), same visible behavior.
      * Compile with CRTBNDRPG (default DFTACTGRP(*YES)).
     H
     FD0426A    CF   E             WORKSTN
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
