      * V50NB2 - CALL to V50DIV (it divides by zero), WITHOUT an error
      * indicator (cols 73-74 blank). verify/issue50-ilemsg only.
     H DFTACTGRP(*YES)
     DFLG              S              1A
     C                   MOVE      'N'           FLG
     C                   CALL      'V50DIV'
     C                   PARM                    FLG
     C                   SETON                                        LR
