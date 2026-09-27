/* TXMIGR command - wraps the TXMIGR *PGM. See txsetup.cmd for why.      */
/* FIXED (2026-09-27, verify/part05-txmigr-to2 design, static review      */
/* before any real connection): the original PROMPT text ('TXMIGR -      */
/* migrate sample DB and recompile', 41 chars) exceeds CMD's own          */
/* PROMPT() length limit - probes.md already confirmed on real hardware   */
/* (txsetup.cmd's own CRTCMD history) that a PROMPT() over 30 characters  */
/* fails CRTCMD with CPD0074. Shortened below; still unconfirmed on real  */
/* hardware otherwise (this specific .cmd has never been compiled).       */
             CMD        PROMPT('TXMIGR - migrate & recompile')
             PARM       KWD(TO) TYPE(*DEC) LEN(3 0) MIN(1) RANGE(2 3) +
                          PROMPT('Target DBVER (2 or 3)')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
