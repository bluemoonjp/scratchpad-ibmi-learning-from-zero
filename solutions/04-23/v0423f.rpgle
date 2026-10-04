      * V0423F - read JUCHUD sequentially and print every order line.
      * Exercise 3 answer. Same shape as V0423A; 12 lines are expected.
     H DFTACTGRP(*YES)
     FJUCHUD    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     C     LOOP          TAG
     C                   READ      JUCHUD                                 99
     C   99              GOTO      ENDLP
     C                   EXCEPT
     C                   GOTO      LOOP
     C     ENDLP         TAG
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       JUNO                 6
     O                                            8 '  '
     O                       JULINE              11
     O                                           13 '  '
     O                       JUSHO               19
     O                                           21 '  '
     O                       JUSU                26
