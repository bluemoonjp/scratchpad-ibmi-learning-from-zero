/* TXCHKRUN - verify/part06-15-checkpoint helper, NOT part of the        */
/* curriculum. Calls TXCHECK (a *CMD) via QCMDEXC from inside a CL        */
/* wrapper program, same reasoning and pattern as                        */
/* verify/part05-txlegacy-exec/src/txlegrun.clp (that file's own header   */
/* explains why: a bare 'TXCHECK LESSON(...) LIB(...)' statement in the   */
/* wrapper's own step text fails with CPD0030, since TXCHECK's *CMD is    */
/* only created by an earlier RUNTIME step in the same wrapper, not yet   */
/* existing when the wrapper itself is COMPILED). This helper builds the  */
/* command with CHGVAR/*TCAT/%TRIM at RUNTIME instead - the same fix      */
/* used there - after a first attempt (embedding a fixed-length literal   */
/* directly in a CALL PGM(QCMDEXC) PARM('...' N) step) failed real        */
/* hardware with "String '          ' contains a character that is not    */
/* valid" (LIB came through blank) - not yet root-caused, but this        */
/* proven-working pattern sidesteps it entirely rather than debugging     */
/* the literal-embedding approach further.                                */
/*                                                                        */
/* PARM: LESSON (<=6 chars, e.g. '06-15'), LIB (target library, <=10      */
/* chars). CMDLEN is the &CMD DS's own full declared size, not the        */
/* shorter true command length - trailing blanks in a CL command are      */
/* tolerated (same reasoning txlegrun.clp's own header documents).        */
             PGM        PARM(&LESSON &LIB)

             DCL        VAR(&LESSON) TYPE(*CHAR) LEN(6)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(50)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)

             CHGVAR     VAR(&CMD) VALUE('TXCHECK LESSON(''' *TCAT +
                          %TRIM(&LESSON) *TCAT ''') LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ')')
             CHGVAR     VAR(&CMDLEN) VALUE(50)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000)

             ENDPGM
