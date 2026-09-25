/* TXSETUP command - wraps the TXSETUP *PGM so parameters are always     */
/* padded to their declared length by the command processor (avoids the */
/* 32-byte literal-padding trap of a raw CALL PGM(...) PARM(...)).      */
             CMD        PROMPT('TXSETUP - build sample DB')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
             PARM       KWD(FORCE) TYPE(*CHAR) LEN(4) DFT(*NO) +
                          RSTD(*YES) VALUES(*NO *YES) +
                          PROMPT('Force rebuild')
