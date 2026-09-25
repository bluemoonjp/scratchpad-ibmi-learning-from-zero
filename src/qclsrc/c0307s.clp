             PGM
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10) VALUE('*CURLIB')
             DCL        VAR(&OBJNAME) TYPE(*CHAR) LEN(20) VALUE('NOSUCHOBJ')

             /* Program-level MONMSG: monitors the whole program from this */
             /* point on. Only GOTO is allowed in its EXEC().              */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(UNEXPCT))

             CHKOBJ     OBJ(&LIB/&OBJNAME) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(NOTFND))

             SNDPGMMSG  MSG('Object found.')
             GOTO       CMDLBL(END)

NOTFND:      SNDPGMMSG  MSGID(JUM0001) MSGF(*LIBL/JUMSGF) MSGDTA(&OBJNAME) +
                          MSGTYPE(*ESCAPE)

UNEXPCT:     SNDPGMMSG  MSG('Unexpected error. See the job log.')

END:         ENDPGM
