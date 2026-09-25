/* TXLOAD command - wraps the TXLOAD *PGM. See txsetup.cmd for why.      */
             CMD        PROMPT('TXLOAD - fetch a lesson model answer')
             PARM       KWD(SOL) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Lesson id, e.g. 03-14')
             PARM       KWD(FILE) TYPE(*CHAR) LEN(30) MIN(1) +
                          PROMPT('Solution file name (no extension)')
             PARM       KWD(OBJ) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Object/member name to compile as')
             PARM       KWD(TYPE) TYPE(*CHAR) LEN(3) MIN(1) +
                          RSTD(*YES) VALUES(RPG CLP) +
                          PROMPT('Source type')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
