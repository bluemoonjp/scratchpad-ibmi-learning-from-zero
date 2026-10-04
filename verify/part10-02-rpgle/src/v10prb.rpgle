      * V10PRB - probe for verify/part10-02-rpgle, NOT part of the curriculum.
      * Opens TOKUIM (found through *LIBL) and reads one record. It is
      * compiled before CHGPF and called after it, so the record format
      * level check must fail when the file is opened. The batch records
      * the ILE message sequence of that failure (job log copy).
      * Fixed-form RPG IV, CRTBNDRPG, DFTACTGRP(*YES).
     H DFTACTGRP(*YES)
     FTOKUIM    IF   E             DISK
     C                   READ      TOKUIM                                 99
     C                   SETON                                        LR
