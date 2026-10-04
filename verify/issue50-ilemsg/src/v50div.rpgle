      * V50DIV - callee that ends in an error: divide by zero at run
      * time (the divisor is set at run time, so it compiles).
     H DFTACTGRP(*YES)
     DFLG              S              1A
     DNUM              S              5P 0
     DZRO              S              5P 0
     DRES              S              5P 0
     C     *ENTRY        PLIST
     C                   PARM                    FLG
     C                   Z-ADD     10            NUM
     C                   Z-ADD     0             ZRO
     C     NUM           DIV       ZRO           RES
     C                   SETON                                        LR
     C                   RETURN
