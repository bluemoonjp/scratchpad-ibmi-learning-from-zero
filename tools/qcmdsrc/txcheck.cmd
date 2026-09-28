/* TXCHECK command - wraps the TXCHECK *PGM. See txsetup.cmd for why.    */
/* FIXED (Part 6 source cleanup): PROMPT() text was 35 characters,       */
/* exceeding CRTCMD's 30-character limit (CPD0074) - the same bug        */
/* c0511s.cmd/txsnap.cmd already hit and fixed. This command's own       */
/* *CMD wrapper had never been compiled before (05-13's own real-hardware*/
/* note), so this bug had never surfaced until now.                      */
             CMD        PROMPT('TXCHECK - check one lesson')
             PARM       KWD(LESSON) TYPE(*CHAR) LEN(6) MIN(1) +
                          PROMPT('Lesson id, e.g. 04-13')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
