      * V0422P - reading sample for CASxx/CABxx/TAG (04-22, read only).
      * CAB loop adds 1..5 (SUM 15); CAS group picks subroutine BIG (N=7).
      * Expected: BIG        00015
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     DN                S              3P 0
     DI                S              3P 0
     DSUM              S              5P 0
     DOUT              S             10A
     C                   Z-ADD     7             N
     C                   Z-ADD     0             I
     C                   Z-ADD     0             SUM
     C     LOOP          TAG
     C                   ADD       1             I
     C                   ADD       I             SUM
     C     I             CABLT     5             LOOP
     C     N             CASGT     5             BIG
     C     N             CASEQ     5             FIVE
     C                   CAS                     SMALL
     C                   ENDCS
     C                   EXCEPT
     C                   SETON                                        LR
     C     BIG           BEGSR
     C                   MOVEL     'BIG'         OUT
     C                   ENDSR
     C     FIVE          BEGSR
     C                   MOVEL     'FIVE'        OUT
     C                   ENDSR
     C     SMALL         BEGSR
     C                   MOVEL     'SMALL'       OUT
     C                   ENDSR
     OQSYSPRT   E
     O                       OUT                 10
     O                       SUM                 16
