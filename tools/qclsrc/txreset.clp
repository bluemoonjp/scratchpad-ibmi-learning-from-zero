/* TXRESET - restore the sample database DATA to its initial state.       */
/*           Does not touch the schema (DDS). Use TXMIGR for schema       */
/*           changes and TXSETUP for the first-time build.                */
             PGM        PARM(&LIB &CLONEDIR)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10) VALUE('*CURLIB')
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200) VALUE(' ')
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)

             CHKOBJ     OBJ(&LIB/TXSTATE) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                SNDPGMMSG  MSG('TXRESET: not initialized in this library. +
                             Run TXSETUP first.')
                RETURN
             ENDDO

             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                RTVJOBA    USRPRF(&USRPRF)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO

             RUNSQLSTM  SRCSTMF(&CLONEDIR *TCAT '/db/data/reset_v1.sql') +
                          COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(&LIB)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRESET: clearing data failed. See the job +
                             log for details.') MSGTYPE(*ESCAPE)
             ENDDO

             RUNSQLSTM  SRCSTMF(&CLONEDIR *TCAT '/db/data/load_v1.sql') +
                          COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(&LIB)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRESET: reloading data failed. See the job +
                             log for details.') MSGTYPE(*ESCAPE)
             ENDDO

             SNDPGMMSG  MSG('TXRESET: data restored to the initial state.')
             ENDPGM
