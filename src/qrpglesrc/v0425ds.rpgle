      * V0425D - product-wise stock list, flag low-stock items.
      * Fixed-form RPG IV port of R0413A (04-13): same print lines.
      * ZAIKOM is the PRIMARY file (IP): every product is read by the
      * cycle. SHOHIM is fetched with CHAIN. COMP puts LO (cols 73-74)
      * on indicator 60 when stock is below the reorder point.
     H DFTACTGRP(*YES)
     FZAIKOM    IP   E           K DISK
     FSHOHIM    IF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     C     ZASHO         CHAIN     SHOHIM                             50
     C     ZASU          COMP      SHOHAT                               60
     C                   EXCEPT
     OQSYSPRT   E
     O                       ZASHO                8
     O                                           10 '  '
     O                       SHONM               42
     O                                           45 '  '
     O                       ZASU                55
     O               60                          70 'LOWSTOCK'
