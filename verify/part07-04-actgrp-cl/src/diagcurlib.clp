/* DIAGCURLIB - one-shot diagnostic: report what RTVJOBA CURLIB() returns */
/* in a job set up by this verify harness (ADDLIBLE only, no CHGCURLIB   */
/* issued yet at this point in the batch). Standalone program because a  */
/* "cl"-type manifest step's command text is inlined into the middle of  */
/* one big shared wrapper PGM (verify/lib/clgen.mjs) - DCL statements     */
/* are only legal immediately after that wrapper's own PGM statement, not */
/* mid-sequence, so this diagnostic could not DCL its own variable inline */
/* the way an ordinary "cl" step's cmd text can call existing commands.   */
/* See work/design/part07-design-v1.md section 0.6 / section 9 item 13.  */
             PGM

             DCL        VAR(&DIAGLIB) TYPE(*CHAR) LEN(10)

             RTVJOBA    CURLIB(&DIAGLIB)
             SNDPGMMSG  MSG('DIAGCURLIB: RTVJOBA CURLIB returned [' *CAT +
                          &DIAGLIB *CAT ']')

             ENDPGM
