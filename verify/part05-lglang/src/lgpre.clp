/* LGPRE - verify/part05-lggold and part05-lglang helper, NOT part of the */
/* curriculum. Precondition gate (Issue #35 plan, section "Verification"):*/
/* the library must hold the DBVER 1 sample DB and the legacy system must */
/* not be the RPG IV (*RPGLE) variant already. If not, it sends an        */
/* *ESCAPE (CPF9898); the manifest step monitors it and jumps to DONE, so */
/* nothing after the gate runs.                                           */
/*                                                                        */
/* PARM: LIB (<=10 chars; 10 is well under the 32-byte CALL/PARM literal  */
/* padding trap).                                                         */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DBVER) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&DBVERC) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LANG) TYPE(*CHAR) LEN(7)

             CHGVAR     VAR(&LANG) VALUE(' ')
             RTVDTAARA  DTAARA(&LIB/TXSTATE) RTNVAR(&DBVER)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('LGPRE: ABORT - cannot read TXSTATE (DBVER).')
                GOTO       CMDLBL(STOP)
             ENDDO
             CHGVAR     VAR(&DBVERC) VALUE(&DBVER)
             RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&LANG)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&LANG) VALUE(' '))
             SNDPGMMSG  MSG('LGPRE: DBVER=' *CAT &DBVERC *CAT +
                          ' TXLEGLNG=[' *CAT &LANG *CAT ']')
             IF         COND(&DBVER *NE 1) THEN(DO)
                SNDPGMMSG  MSG('LGPRE: ABORT - DBVER is not 1.')
                GOTO       CMDLBL(STOP)
             ENDDO
             IF         COND(&LANG *EQ '*RPGLE') THEN(DO)
                SNDPGMMSG  MSG('LGPRE: ABORT - legacy system is already +
                             *RPGLE (TXLEGLNG).')
                GOTO       CMDLBL(STOP)
             ENDDO
             SNDPGMMSG  MSG('LGPRE: gate passed.')
             RETURN

STOP:        SNDPGMMSG  MSGID(CPF9898) MSGF(QCPFMSG) +
                          MSGDTA('LGPRE: precondition failed') +
                          MSGTYPE(*ESCAPE)
             ENDPGM
