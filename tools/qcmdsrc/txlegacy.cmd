/* TXLEGACY command - wraps the TXLEGACY *PGM. See txsetup.cmd for why.  */
             CMD        PROMPT('TXLEGACY - load legacy system')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
             PARM       KWD(FORCE) TYPE(*CHAR) LEN(4) DFT(*NO) +
                          RSTD(*YES) VALUES(*NO *YES) +
                          PROMPT('Force rebuild (backs up first)')
