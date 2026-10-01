      * V0425F - exercise 5 (04-25): V0425D with below OR EQUAL.
      * COMP now sets indicator 60 on LO (cols 73-74) AND on EQ (cols
      * 75-76). Expected: a product whose stock equals its reorder point
      * would also get LOWSTOCK (none does in the shipped data).
     H DFTACTGRP(*YES)
     FZAIKOM    IP   E           K DISK
     FSHOHIM    IF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     C     ZASHO         CHAIN     SHOHIM                             50
     C     ZASU          COMP      SHOHAT                               6060
     C                   EXCEPT
     OQSYSPRT   E
     O                       ZASHO                8
     O                                           10 '  '
     O                       SHONM               42
     O                                           45 '  '
     O                       ZASU                55
     O               60                          70 'LOWSTOCK'
