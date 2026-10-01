      * W0423A - lock tester: try to read ZAIKOM P00006 for update.
      * The CHAIN has an error indicator (97), so a record-lock time-out
      * does not raise an inquiry message. The file status code comes
      * from the file information data structure (*STATUS subfield).
      * 1218 means "record locked by another job" (docs/probes.md).
      * Pair program: V0423E holds the lock.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK    INFDS(ZAINFO)
     FQSYSPRT   O    F  132        PRINTER
     DZAINFO           DS
     D ZASTS             *STATUS
     DMSG              S             10A
     C     'P00006'      CHAIN     ZAIKOM                             9997
     C   97              GOTO      LOCKED
     C   99              GOTO      NOTFND
     C                   MOVEL     'FOUND'       MSG
     C                   GOTO      ENDPGM
     C     LOCKED        TAG
     C                   MOVEL     'LOCKED'      MSG
     C                   GOTO      ENDPGM
     C     NOTFND        TAG
     C                   MOVEL     'NOTFOUND'    MSG
     C     ENDPGM        TAG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            6 'P00006'
     O                                            8 '  '
     O                       ZASTS               13
     O                                           15 '  '
     O                       MSG                 25
