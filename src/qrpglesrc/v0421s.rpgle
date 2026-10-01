      * V0421A - minimal fixed-form RPG IV: print one line via EXCEPT.
      * Same printed line as R0401A (RPG III, lesson 04-01).
      * Part 4V lesson 04-21. Compile: CRTBNDRPG (see the lesson).
     H DFTACTGRP(*YES)
     FQSYSPRT   O    F  132        PRINTER
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                           20 'HELLO, RPG III!'
