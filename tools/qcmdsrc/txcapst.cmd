/* TXCAPST command - wraps the TXCAPST *PGM. See txsetup.cmd for why.    */
/* LIB is required (no *CURLIB default): the capstone plants a bad row,  */
/* so the target library is always named on purpose. PROMPT() texts stay */
/* at or under 30 characters (CRTCMD limit, see txcheck.cmd).            */
             CMD        PROMPT('TXCAPST - prepare incident')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
             PARM       KWD(FORCE) TYPE(*CHAR) LEN(4) DFT(*NO) +
                          RSTD(*YES) VALUES(*NO *YES) +
                          PROMPT('Force re-plant')
