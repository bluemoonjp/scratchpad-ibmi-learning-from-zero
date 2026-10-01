      * JU0300 - order list (JUCHUM/JUCHUL1) with L1/L2 subtotals and a grand
      * total, legacy system, fixed-form RPG IV (QRPGLE112, CRTBNDRPG), with the
      * credit-limit flag added.
      *
      * Model answer for lesson 10-02 (route that skips RPG III). Counterpart of
      * solutions/10-02/ju0300-credit.rpg (RPG III): same output, same rule.
      *
      * Base lines: the hand conversion src/legacy/qrpgle112/ju0300.rpgle, kept
      * verbatim. The lines between the "10-02 added" marks are the credit-limit
      * change: 14 C lines (KLIST, 2 KFLD and 11 lines of the check), 3 F lines
      * and 1 O line. All other lines are the base.
      *
      * Rule: the order is flagged when LINE 1 of the order, valued at the
      * CURRENT list price (SHOHIM SHOTNK), is greater than the credit limit
      * TOKYSN of the customer. Only line 1 is looked at (a CHAIN, not a loop).
      * A limit of zero (what CHGPF gives existing rows) flags every order.
      * Indicators: 95 over limit, 96 no TOKUIM row, 97 no JUCHUD line 1,
      * 98 no SHOHIM row. When 96/97/98 is on, the order is not flagged.
      * The check is one IFEQ/ANDEQ/ENDIF block: N96N97N98 cannot be written on
      * one line, and the MULT and the COMP would each need a CAN group.
      *
      * UNVERIFIED (2026-10-01): not compiled yet. The base part is a hand
      * conversion (see its header). If the real CVTRPGSRC output of JU0300
      * differs, trust the compiled copy under src/legacy/qrpgle112/ for the
      * base part and add only the marked lines.
      * Needs the v3 TOKUIM (solutions/10-02/tokuim-v3.pf) BEFORE it compiles.
     H DFTACTGRP(*YES)
     FJUCHUL1   IP   E           K DISK
      * ---- 10-02 added: three input files ----
     FTOKUIM    IF   E           K DISK
     FSHOHIM    IF   E           K DISK
     FJUCHUD    IF   E           K DISK
      * ---- 10-02 added end ----
     FQSYSPRT   O    F  132        PRINTER
     DCT               S              5S 0 DIM(50)
     D                UDS
     DFTOK                    11     16
     IJUCHUR
     I                                          JUDATE        L1
     I                                          JUTOK         L2
      * ---- 10-02 added: key list ----
     C     JKEY          KLIST
     C                   KFLD                    JUNO
     C                   KFLD                    JULINE
      * ---- 10-02 added end ----
     C                   SETON                                            94
      * ---- 10-02 added: credit check ----
     C                   SETOFF                                           95
     C     JUTOK         CHAIN     TOKUIM                             96
     C                   Z-ADD     1             JULINE
     C     JKEY          CHAIN     JUCHUD                             97
     C  N97JUSHO         CHAIN     SHOHIM                             98
     C     *IN96         IFEQ      *OFF
     C     *IN97         ANDEQ     *OFF
     C     *IN98         ANDEQ     *OFF
     C     JUSU          MULT      SHOTNK        AMT              12 2
     C     AMT           COMP      TOKYSN                             95
     C                   ENDIF
      * ---- 10-02 added end ----
     C                   ADD       1             L1CNT             5 0
     C                   ADD       1             GCNT              5 0
     C     FTOK          COMP      '      '                               91
     C     FTOK          COMP      JUTOK                                  92
     C   91              EXCEPT    DTL
     C  N91
     CAN 92              EXCEPT    DTL
     CL1 94              EXCEPT    L1BRK
     CL1                 ADD       L1CNT         L2CNT             5 0
     CL1                 Z-ADD     0             L1CNT
     CL2                 SETOFF                                       90
     CL2   IX            COMP      49                                 90
     CL2N90              ADD       1             IX                2 0
     CL2N90              Z-ADD     L2CNT         CT(IX)
     CL2 94              EXCEPT    L2BRK
     CL2                 Z-ADD     0             L2CNT
     CLR                 XFOOT     CT            XTOT              5 0
     CLR   XTOT          COMP      GCNT                                   93
     CLR 94              EXCEPT    GTOT
     OQSYSPRT   E            DTL
     O                       JUNO                10
     O                       JUTOK               20
     O                       JUDATE        Z     32
     O                       JUTAN               42
      * ---- 10-02 added: flag text ----
     O               95                          55 'OVER LIMIT'
      * ---- 10-02 added end ----
     O          E            L1BRK
     O                       JUTOK               10
     O                       JUDATE        Z     22
     O                                           45 'DATE TOTAL'
     O                       L1CNT         Z     55
     O          E            L2BRK
     O                       JUTOK               10
     O                                           45 'CUST TOTAL'
     O                       L2CNT         Z     55
     O          E            GTOT
     O                                           20 'GRAND TOTAL'
     O                       GCNT          Z     30
     O                                           40 'XFOOT='
     O                       XTOT          Z     50
     O               93                          60 'OK'
     O              N93                          70 'MISMATCH'
