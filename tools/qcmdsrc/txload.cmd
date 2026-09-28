/* TXLOAD command - wraps the TXLOAD *PGM. See txsetup.cmd for why.      */
/* FIXED (found sweeping tools/qcmdsrc for the same class of bug after   */
/* txcheck.cmd's own PROMPT()-too-long bug surfaced, Part 6 work): this   */
/* PROMPT() text was 36 characters, exceeding CRTCMD's 30-character      */
/* limit (CPD0074) - same bug class as c0511s.cmd/txsnap.cmd/txcheck.cmd.*/
/* Not yet learner-facing (docs/appendix/e-naming.md: "not used in any   */
/* lesson text yet"), but latent and dead-on-arrival the first time      */
/* anyone tries to CRTCMD this member.                                   */
             CMD        PROMPT('TXLOAD - fetch model answer')
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
