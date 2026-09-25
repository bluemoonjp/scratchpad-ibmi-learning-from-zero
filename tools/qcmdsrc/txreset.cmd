/* TXRESET command - wraps the TXRESET *PGM. See txsetup.cmd for why.    */
             CMD        PROMPT('TXRESET - restore sample data')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
