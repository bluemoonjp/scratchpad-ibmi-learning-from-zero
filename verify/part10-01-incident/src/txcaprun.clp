/* TXCAPRUN - verify/part10-01-incident helper, NOT part of the           */
/* curriculum. Calls TXLEGACY or TXCAPST (both *CMD objects created by an */
/* earlier RUNTIME step of the same wrapper) via QCMDEXC, same reasoning  */
/* and pattern as verify/part05-txlegacy-exec/src/txlegrun.clp: a literal */
/* command statement in a wrapper step would be resolved at COMPILE time, */
/* before the *CMD exists. The wrapper has no DCL section of its own, so  */
/* the command text is built here at runtime.                             */
/*                                                                        */
/* PARM:                                                                  */
/*   WHAT   'LEGACY' runs  x/TXLEGACY LIB(x) FORCE(f)                     */
/*          'CAPST'  runs  x/TXCAPST  LIB(x) FORCE(f)                     */
/*          'RESET'  runs  x/TXRESET LIB(x)   (FORCE is ignored)          */
/*   LIB    target library (10 chars)                                     */
/*   FORCE  '*YES' or '*NO' (4 chars)                                     */
/* All declared lengths are under 32, so the 32-byte CALL literal padding */
/* trap (03-08) does not apply. TXCAPST does its compile, INSERT and CPYF */
/* inside its own call, which runs in THIS job (one job, one QTEMP).      */
/*                                                                        */
/* After the call it reports the state flag (TXLEGST or TXCAPFL) as a     */
/* message, so the value lands in the wrapper's job log (VFYLOG). A       */
/* missing flag is reported as a value, not as a step failure.            */
             PGM        PARM(&WHAT &LIB &FORCE)

             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(6)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(100)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)
             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(1)

             /* The commands are library-qualified on purpose: the      */
             /* job's own library list may hold an older copy of the     */
             /* same command in the private library 1.                   */
             IF         COND(&WHAT *EQ 'LEGACY') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXLEGACY LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ') FORCE(' *TCAT +
                          %TRIM(&FORCE) *TCAT ')'))
             IF         COND(&WHAT *EQ 'CAPST') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXCAPST LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ') FORCE(' *TCAT +
                          %TRIM(&FORCE) *TCAT ')'))
             IF         COND(&WHAT *EQ 'RESET') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXRESET LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ')'))
             IF         COND(&CMD *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TXCAPRUN: WHAT must be LEGACY, CAPST or RESET.')
                RETURN
             ENDDO

             CHGVAR     VAR(&CMDLEN) VALUE(100)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPRUN: the command ended with an error.')
             ENDDO

             IF         COND(&WHAT *EQ 'LEGACY') THEN(GOTO CMDLBL(RPTLEG))
             IF         COND(&WHAT *EQ 'RESET') THEN(RETURN)

             RTVDTAARA  DTAARA(&LIB/TXCAPFL (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPRUN: TXCAPFL does not exist.')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TXCAPRUN: TXCAPFL value: ' *CAT &FLAG)
             RETURN

RPTLEG:      RTVDTAARA  DTAARA(&LIB/TXLEGST (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPRUN: TXLEGST does not exist.')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TXCAPRUN: TXLEGST value: ' *CAT &FLAG)

             ENDPGM
