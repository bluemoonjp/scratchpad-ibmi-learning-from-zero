      * V0424A - called side: look up a customer name by code.
      * Port of R0408BA (04-08b) to fixed-form RPG IV. Same behaviour.
      * PARM 1 PCODE 6 in, PARM 2 PNAME 30 out, PARM 3 PRC 1,0 out
      * (0 = found, 1 = not found).
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E           K DISK
     DPCODE            S              6A
     DPNAME            S             30A
     DPRC              S              1P 0
     C     *ENTRY        PLIST
     C                   PARM                    PCODE
     C                   PARM                    PNAME
     C                   PARM                    PRC
     C                   MOVE      *BLANKS       PNAME
     C     PCODE         CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    PNAME
     C   99              Z-ADD     1             PRC
     C  N99              MOVEL     TOKNM         PNAME
     C  N99              Z-ADD     0             PRC
     C                   SETON                                        LR
     C                   RETURN
