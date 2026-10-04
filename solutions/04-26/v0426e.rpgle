      * V0426E - exercise 4 answer: V0426B + record count (CNT)
      * shown on the footer record of D0426E.
     H
     FD0426E    CF   E             WORKSTN SFILE(SFL1:RRN)
     FTOKUIM    IF   E           K DISK
      * RRN: relative record number of the subfile (numeric, 0 dec).
     DRRN              S              4P 0
      * Load phase: one WRITE SFL1 per TOKUIM record, RRN 1,2,3...
     C                   MOVE      *BLANKS       MORE
     C                   Z-ADD     0             RRN
     C                   READ      TOKUIM                                 98
     C     *IN98         DOWEQ     *OFF
     C     RRN           ANDLT     9999
     C                   ADD       1             RRN
     C                   WRITE     SFL1
     C                   READ      TOKUIM                                 98
     C                   ENDDO
      * SFLDSP is not conditioned in D0426B: write one blank row
      * when TOKUIM is empty, so the subfile is never empty.
     C     RRN           IFEQ      0
     C                   MOVE      *BLANKS       TOKCD
     C                   MOVE      *BLANKS       TOKNM
     C                   Z-ADD     1             RRN
     C                   WRITE     SFL1
     C                   ENDIF
     C     *IN98         IFEQ      *ON
     C                   MOVEL     'BOTTOM'      MORE
     C                   ELSE
     C                   MOVEL     'MORE...'     MORE
     C                   ENDIF
      * CNT = number of rows loaded (a blank row counts as 1).
     C                   Z-ADD     RRN           CNT
      * Display phase: footer first (OVERLAY), then the control
      * record, until F3 turns on indicator 03.
     C     *IN03         DOWEQ     *OFF
     C                   WRITE     SFL1FTR
     C                   EXFMT     SFL1CTL
     C                   ENDDO
     C                   SETON                                        LR
