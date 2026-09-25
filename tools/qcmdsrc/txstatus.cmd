/* TXSTATUS command - wraps the TXSTATUS *PGM. See txsetup.cmd for why.  */
             CMD        PROMPT('TXSTATUS - show DB version')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
