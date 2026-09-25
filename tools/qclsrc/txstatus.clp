/* TXSTATUS - show the sample database version (DBVER) in a library.      */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DBVER) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&DBVERC) TYPE(*CHAR) LEN(10)

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

             CHKOBJ     OBJ(&LIB/TXSTATE) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                SNDPGMMSG  MSG('TXSTATUS: not initialized in this library. +
                             Run TXSETUP first.')
                RETURN
             ENDDO

             RTVDTAARA  DTAARA(&LIB/TXSTATE) RTNVAR(&DBVER)
             CHGVAR     VAR(&DBVERC) VALUE(&DBVER)
             SNDPGMMSG  MSG('TXSTATUS: DBVER=' *CAT %TRIM(&DBVERC) *CAT +
                          ' in library ' *CAT &LIB)

             ENDPGM
