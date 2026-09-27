/* TXCHECK command - wraps the TXCHECK *PGM. See txsetup.cmd for why.    */
             CMD        PROMPT('TXCHECK - run checks for one lesson')
             PARM       KWD(LESSON) TYPE(*CHAR) LEN(6) MIN(1) +
                          PROMPT('Lesson id, e.g. 04-13')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
