      * V0423D - ZAHIK3: allocate stock for one product (UPDATE + lock).
      * Fixed-form RPG IV port of R0409A (04-09): same logic, same print
      * line, NO parameters (R0409A has no *ENTRY PLIST either). The
      * single CHAIN locks the record and the lock stays until LR.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DPROD             S              6A
     DQTY              S              5S 0
     DMSG              S             10A
     C                   MOVEL     'P00001'      PROD
     C                   Z-ADD     2             QTY
     C     PROD          CHAIN     ZAIKOM                             99
     C   99              GOTO      NOTFND
     C     ZASU          COMP      QTY                                  98
     C   98              GOTO      SHORT
     C                   SUB       QTY           ZASU
     C                   UPDATE    ZAIKOR
     C                   MOVEL     'OK'          MSG
     C                   GOTO      ENDPGM
     C     SHORT         TAG
     C                   MOVEL     'SHORT'       MSG
     C                   GOTO      ENDPGM
     C     NOTFND        TAG
     C                   MOVEL     'NOTFOUND'    MSG
     C     ENDPGM        TAG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                       PROD                 6
     O                                            8 '  '
     O                       ZASU                15
     O                                           17 '  '
     O                       MSG                 27
