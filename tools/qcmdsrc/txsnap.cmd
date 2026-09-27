/* TXSNAP command - wraps the TXSNAP *PGM. See txsetup.cmd for why.      */
             CMD        PROMPT('TXSNAP - save spooled file')
             PARM       KWD(LABEL) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Snapshot label (member name)')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(SPLF) TYPE(*CHAR) LEN(10) DFT('QSYSPRT') +
                          PROMPT('Spooled file name')
             PARM       KWD(JOB) TYPE(*CHAR) LEN(10) DFT('*') +
                          PROMPT('Job name (* = this job)')
             PARM       KWD(SPLNBR) TYPE(*CHAR) LEN(10) DFT(*LAST) +
                          PROMPT('Spooled file number')
