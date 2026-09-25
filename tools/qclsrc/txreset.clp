/* TXRESET - restore the sample database DATA to its initial state.       */
/*           Does not touch the schema (DDS). Use TXMIGR for schema       */
/*           changes and TXSETUP for the first-time build.                */
             PGM        PARM(&LIB &CLONEDIR)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

             CHKOBJ     OBJ(&LIB/TXSTATE) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                SNDPGMMSG  MSG('TXRESET: not initialized in this library. +
                             Run TXSETUP first.')
                RETURN
             ENDDO

/* --- *CURLIB is only valid as a qualifier on object references; RUNSQLSTM */
/* DFTRDBCOL below needs the real name. --- */
             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                RTVJOBA    USER(&USRPRF)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO

/* No MONMSG on these two: let an unhandled failure end the program with  */
/* its own real error message (SNDPGMMSG MSGTYPE(*ESCAPE) needs a real    */
/* MSGID, not free text).                                                 */
             RUNSQLSTM  SRCSTMF(&CLONEDIR *TCAT '/db/data/reset_v1.sql') +
                          COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(&LIB)

             RUNSQLSTM  SRCSTMF(&CLONEDIR *TCAT '/db/data/load_v1.sql') +
                          COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(&LIB)

             SNDPGMMSG  MSG('TXRESET: data restored to the initial state.')
             ENDPGM
