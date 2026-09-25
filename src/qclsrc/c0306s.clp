             PGM
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10) VALUE('*CURLIB')
             DCL        VAR(&FOUND) TYPE(*LGL) VALUE('1')

             CHKOBJ     OBJ(&LIB/JUNODA) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(CHGVAR VAR(&FOUND) VALUE('0'))

             IF         COND(&FOUND) THEN(SNDPGMMSG MSG('JUNODA already +
                          exists. Nothing to do.'))
             ELSE       CMD(DO)
                SNDPGMMSG  MSG('JUNODA not found. Creating it.')
                CRTDTAARA  DTAARA(&LIB/JUNODA) TYPE(*DEC) LEN(6 0) VALUE(0) +
                             TEXT('Next order number')
             ENDDO

             ENDPGM
