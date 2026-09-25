/* TXMIGR command - wraps the TXMIGR *PGM. See txsetup.cmd for why.      */
             CMD        PROMPT('TXMIGR - migrate sample DB and recompile')
             PARM       KWD(TO) TYPE(*DEC) LEN(3 0) MIN(1) RANGE(2 3) +
                          PROMPT('Target DBVER (2 or 3)')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
