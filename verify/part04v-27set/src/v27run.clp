/* V27RUN - verify/part04v-27set helper, NOT part of the curriculum.      */
/* Runs the pieces of the 04-27 route that cannot be written directly in  */
/* a wrapper step: (1) commands that do not exist yet, or that are        */
/* replaced at run time, when the wrapper is compiled (TXLEGACY,          */
/* TXCHECK, TXSTATUS - the CL compiler resolves a *CMD at compile time),  */
/* run here through QCMDEXC (same idea as part05-txlegacy-exec's          */
/* TXLEGRUN); (2) RMVLIBLE of the user's first library (profile name +    */
/* '1'), which has no placeholder in the harness; (3) the precondition    */
/* check. The library list is job-scoped, so the RMVLIBLE done here       */
/* stays in effect in the wrapper job after this program returns.         */
/*                                                                        */
/* PARM: WHAT (10) selects the action, LIB (10) is the library.           */
/*   PRECOND  DBVER must be 1 and TXLEGLNG absent or *RPG; otherwise an   */
/*            escape (CPF9898) is sent so the caller can jump to its end. */
/*   RMVLIB1  RMVLIBLE <profile>1                                         */
/*   LEGRPGLE TXLEGACY LIB(x) LANG(*RPGLE)                                */
/*   LEGSAME  TXLEGACY LIB(x)            (LANG omitted = *SAME)           */
/*   LEGRPG   TXLEGACY LIB(x) LANG(*RPG)                                  */
/*   CHECK    TXCHECK LESSON('04-27') LIB(x)                              */
/*   STATUS   TXSTATUS LIB(x)                                             */
/*   SHOWST   report TXLEGST and TXLEGLNG only                            */
/* After every TXLEGACY call, TXLEGST and TXLEGLNG are reported with      */
/* SNDPGMMSG (job log), so a TXLEGACY that stopped early is visible.      */
/* CALL passes literals padded to 32 bytes; both parameters are 10 long   */
/* so the 32-byte padding trap does not matter.                           */
             PGM        PARM(&WHAT &LIB)

             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(200)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5) VALUE(200)
             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB1) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DBVER) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&DBVERC) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LANGV) TYPE(*CHAR) LEN(7)
             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(1)

             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(UNEXP))

             IF         COND(&WHAT *EQ 'PRECOND') THEN(GOTO +
                          CMDLBL(PRECOND))
             IF         COND(&WHAT *EQ 'RMVLIB1') THEN(GOTO +
                          CMDLBL(RMVLIB1))
             IF         COND(&WHAT *EQ 'SHOWST') THEN(GOTO +
                          CMDLBL(REPORT))

/* --- Build the command text (qualified by library). --- */
             CHGVAR     VAR(&CMD) VALUE(%TRIM(&LIB) *TCAT '/')
             IF         COND(&WHAT *EQ 'LEGRPGLE') THEN(CHGVAR +
                          VAR(&CMD) VALUE(%TRIM(&CMD) *TCAT +
                          'TXLEGACY LIB(' *TCAT %TRIM(&LIB) *TCAT +
                          ') LANG(*RPGLE)'))
             IF         COND(&WHAT *EQ 'LEGSAME') THEN(CHGVAR +
                          VAR(&CMD) VALUE(%TRIM(&CMD) *TCAT +
                          'TXLEGACY LIB(' *TCAT %TRIM(&LIB) *TCAT ')'))
             IF         COND(&WHAT *EQ 'LEGRPG') THEN(CHGVAR +
                          VAR(&CMD) VALUE(%TRIM(&CMD) *TCAT +
                          'TXLEGACY LIB(' *TCAT %TRIM(&LIB) *TCAT +
                          ') LANG(*RPG)'))
             IF         COND(&WHAT *EQ 'CHECK') THEN(CHGVAR +
                          VAR(&CMD) VALUE(%TRIM(&CMD) *TCAT +
                          'TXCHECK LESSON(''04-27'') LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ')'))
             IF         COND(&WHAT *EQ 'STATUS') THEN(CHGVAR +
                          VAR(&CMD) VALUE(%TRIM(&CMD) *TCAT +
                          'TXSTATUS LIB(' *TCAT %TRIM(&LIB) *TCAT ')'))

             SNDPGMMSG  MSG('V27RUN: running ' *CAT %TRIM(&CMD))
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('V27RUN: +
                          the command ended with an error.'))

             IF         COND(%SST(&WHAT 1 3) *NE 'LEG') THEN(RETURN)

REPORT:      CHGVAR     VAR(&FLAG) VALUE('?')
             RTVDTAARA  DTAARA(&LIB/TXLEGST (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&FLAG) +
                          VALUE('-'))
             CHGVAR     VAR(&LANGV) VALUE('(none)')
             RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&LANGV)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&LANGV) +
                          VALUE('(none)'))
             SNDPGMMSG  MSG('V27RUN: TXLEGST=[' *CAT &FLAG *CAT +
                          '] TXLEGLNG=[' *CAT &LANGV *CAT ']')
             RETURN

RMVLIB1:     RTVJOBA    CURUSER(&USR)
             CHGVAR     VAR(&LIB1) VALUE(%TRIM(&USR) *TCAT '1')
             RMVLIBLE   LIB(&LIB1)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('V27RUN: +
                          RMVLIBLE ended with an error.'))
             SNDPGMMSG  MSG('V27RUN: RMVLIBLE attempted for ' *CAT +
                          &LIB1)
             RETURN

PRECOND:     RTVDTAARA  DTAARA(&LIB/TXSTATE) RTNVAR(&DBVER)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSGID(CPF9898) +
                          MSGF(QCPFMSG) MSGDTA('V27RUN PRECONDITION +
                          FAILED: no TXSTATE') TOPGMQ(*PRV) +
                          MSGTYPE(*ESCAPE))
             CHGVAR     VAR(&DBVERC) VALUE(&DBVER)
             SNDPGMMSG  MSG('V27RUN: DBVER=' *CAT %TRIM(&DBVERC))
             IF         COND(&DBVER *NE 1) THEN(SNDPGMMSG +
                          MSGID(CPF9898) MSGF(QCPFMSG) +
                          MSGDTA('V27RUN PRECONDITION FAILED: DBVER +
                          is not 1') TOPGMQ(*PRV) MSGTYPE(*ESCAPE))
             CHGVAR     VAR(&LANGV) VALUE(' ')
             RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&LANGV)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&LANGV) +
                          VALUE(' '))
             SNDPGMMSG  MSG('V27RUN: start TXLEGLNG=[' *CAT &LANGV *CAT +
                          ']')
             IF         COND(&LANGV *NE ' ' *AND &LANGV *NE '*RPG') +
                          THEN(SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) +
                          MSGDTA('V27RUN PRECONDITION FAILED: legacy +
                          system is not RPG III') TOPGMQ(*PRV) +
                          MSGTYPE(*ESCAPE))
             RETURN
 UNEXP:       SNDPGMMSG  MSG('V27RUN: unexpected error, see job log.')
              RETURN
             ENDPGM
