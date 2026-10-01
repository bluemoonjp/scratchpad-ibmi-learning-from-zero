      * V0423E - lock holder: lock one ZAIKOM record for about 30 seconds.
      * Read-for-update CHAIN locks P00006. There is NO UPDATE, so the
      * data does not change. QCMDEXC runs DLYJOB to keep the lock.
      * The lock is released when this program ends (LR).
      * Pair program: W0423A tries to read the same record.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DCMD              S             14A   INZ('DLYJOB DLY(30)')
     DCMDLEN           S             15P 5 INZ(14)
     C     'P00006'      CHAIN     ZAIKOM                             99
     C   99              GOTO      ENDPGM
     C                   EXCEPT
     C                   CALL      'QCMDEXC'
     C                   PARM                    CMD
     C                   PARM                    CMDLEN
     C     ENDPGM        TAG
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                           19 'V0423E: HELD P00006'
