      * T423NE - lock tester: try to read ZAIKOM P00006 for update.
      * Probe variant WITHOUT an error indicator: records what the ILE
      * runtime does for an unhandled record-lock time-out.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DMSG              S             10A
     C     'P00006'      CHAIN     ZAIKOM                             99
     C   99              GOTO      NOTFND
     C                   MOVEL     'FOUND'       MSG
     C                   GOTO      ENDPGM
     C     NOTFND        TAG
     C                   MOVEL     'NOTFOUND'    MSG
     C     ENDPGM        TAG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            6 'P00006'
     O                                            8 '  '
     O                                           13 '-----'
     O                                           15 '  '
     O                       MSG                 25
