      * V0424L - reads W0424B (QTY 5,0 zoned) and sums QTY into TOT.
      * Row B2 holds X4B4B4B4B4B (five periods) in QTY: not valid zoned
      * decimal data. The batch records which message the ILE program
      * raises. Prints one line (ID and running total) per good row.
     H DFTACTGRP(*YES)
     FW0424B    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     DTOT              S              9P 0
     C                   READ      W0424B                                 98
     C     *IN98         DOWEQ     *OFF
     C                   ADD       QTY           TOT
     C                   EXCEPT
     C                   READ      W0424B                                 98
     C                   ENDDO
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       ID                   2
     O                                            4 '  '
     O                       TOT           1     14
