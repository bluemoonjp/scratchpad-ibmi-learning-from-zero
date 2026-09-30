/* TX10CHK - verify/part10-00-probe helper, NOT part of the curriculum.   */
/* Like verify/part06-15-checkpoint/src/txchkrun.clp (builds the TXCHECK  */
/* command at runtime and runs it via QCMDEXC) but it first puts LIB on   */
/* the library list, because it is CALLed from an sh step: every qsh      */
/* system() call is its own job with no ADDLIBLE done for it (see         */
/* verify/README.md). Purpose: prove that one TXCHECK per JOB works even  */
/* though the second TXCHECK in the SAME job fails with CPF4174.          */
/*                                                                        */
/* PARM: LESSON (<=6 chars), LIB (<=10 chars, holds TXCKM and TXCHECK).   */
             PGM        PARM(&LESSON &LIB)

             DCL        VAR(&LESSON) TYPE(*CHAR) LEN(6)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(50)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)

             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             CHGVAR     VAR(&CMD) VALUE('TXCHECK LESSON(''' *TCAT +
                          %TRIM(&LESSON) *TCAT ''') LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ')')
             CHGVAR     VAR(&CMDLEN) VALUE(50)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TX10CHK: +
                          TXCHECK ended with an escape message.'))

             ENDPGM
