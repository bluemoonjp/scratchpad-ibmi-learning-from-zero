/* TXRGRUN - verify/part10-0x-rpgle helper, NOT part of the curriculum.   */
/* Calls TXLEGACY, TXRESET or TXCAPST (all *CMD objects created by an      */
/* earlier RUNTIME step of the same wrapper) via QCMDEXC. A literal        */
/* command statement in a wrapper step would be resolved at COMPILE time,  */
/* before the *CMD exists, and against the OLD *CMD that may lack LANG.    */
/*                                                                        */
/* PARM:                                                                  */
/*   WHAT   'LEGACY' runs x/TXLEGACY LIB(x) FORCE(f) LANG(l)              */
/*          'RESET'  runs x/TXRESET LIB(x)   (FORCE and LANG are ignored) */
/*          'CAPST'  runs x/TXCAPST LIB(x) FORCE(f) (LANG is ignored)     */
/*   LIB    target library (10 chars)                                     */
/*   LANG   '*RPG' or '*RPGLE' (7 chars)                                  */
/*   FORCE  '*YES' or '*NO' (4 chars)                                     */
/* All declared lengths are under 32, so the 32-byte CALL literal padding */
/* trap (03-08) does not apply. The command is library-qualified on       */
/* purpose: the job's library list may hold an older copy in library 1.   */
/*                                                                        */
/* After the call it reports the state data areas (TXLEGLNG, TXLEGST or   */
/* TXCAPFL) as messages, so the values land in the job log (VFYLOG). A    */
/* missing data area is reported as a value, not as a step failure.       */
             PGM        PARM(&WHAT &LIB &LANG &FORCE)

             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(6)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LANG) TYPE(*CHAR) LEN(7)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(120)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)
             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(1)
             DCL        VAR(&LNG) TYPE(*CHAR) LEN(7)

             IF         COND(&WHAT *EQ 'LEGACY') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXLEGACY LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ') FORCE(' *TCAT +
                          %TRIM(&FORCE) *TCAT ') LANG(' *TCAT +
                          %TRIM(&LANG) *TCAT ')'))
             IF         COND(&WHAT *EQ 'RESET') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXRESET LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ')'))
             IF         COND(&WHAT *EQ 'CAPST') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&LIB) *TCAT '/TXCAPST LIB(' *TCAT +
                          %TRIM(&LIB) *TCAT ') FORCE(' *TCAT +
                          %TRIM(&FORCE) *TCAT ')'))
             IF         COND(&CMD *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TXRGRUN: WHAT must be LEGACY, RESET or +
                             CAPST.')
                RETURN
             ENDDO

             CHGVAR     VAR(&CMDLEN) VALUE(120)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRGRUN: the command ended with an error.')
             ENDDO

             IF         COND(&WHAT *EQ 'LEGACY') THEN(GOTO CMDLBL(RPTLEG))
             IF         COND(&WHAT *EQ 'RESET') THEN(RETURN)

             RTVDTAARA  DTAARA(&LIB/TXCAPFL (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRGRUN: TXCAPFL does not exist.')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TXRGRUN: TXCAPFL value: ' *CAT &FLAG)
             RETURN

RPTLEG:      RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&LNG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRGRUN: TXLEGLNG does not exist.')
             ENDDO
             SNDPGMMSG  MSG('TXRGRUN: TXLEGLNG value: ' *CAT &LNG)
             RTVDTAARA  DTAARA(&LIB/TXLEGST (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRGRUN: TXLEGST does not exist.')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TXRGRUN: TXLEGST value: ' *CAT &FLAG)

             ENDPGM
