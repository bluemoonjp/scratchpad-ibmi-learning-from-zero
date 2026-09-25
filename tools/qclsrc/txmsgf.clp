/* TXMSGF - create the curriculum message file JUMSGF, if it does not     */
/*          exist yet, with message JUM0001 (used from 03-07 onward).     */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

             CHKOBJ     OBJ(&LIB/JUMSGF) OBJTYPE(*MSGF)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                CRTMSGF    MSGF(&LIB/JUMSGF) TEXT('Curriculum message file')
                ADDMSGD    MSGID(JUM0001) MSGF(&LIB/JUMSGF) +
                             MSG('Object not found: &1') FMT((*CHAR 20))
             ENDDO

             ENDPGM
