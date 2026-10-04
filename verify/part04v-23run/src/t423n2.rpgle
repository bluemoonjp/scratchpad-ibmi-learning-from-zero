      * T423N2 - NEGATIVE 2: READ EOF indicator at col 58-59 (RPG III).
      * Fixed-form RPG IV port of R0406A (04-06). Prints the same lines.
      * Compile: CRTBNDRPG. File TOKUIM is found through *LIBL.
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
     C     LOOP          TAG
     C                   READ      TOKUIM                99
     C   99              GOTO      ENDLP
     C                   EXCEPT
     C                   GOTO      LOOP
     C     ENDLP         TAG
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       TOKCD                6
     O                                            8 '  '
     O                       TOKNM               38
