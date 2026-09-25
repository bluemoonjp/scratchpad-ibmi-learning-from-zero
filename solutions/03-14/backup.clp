/* BACKUP - save every object in the current library to a dated save     */
/* file in <profile>B. Model answer for the 03-14 checkpoint.            */
             PGM

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIBB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DATE) TYPE(*CHAR) LEN(6)
             DCL        VAR(&SAVF) TYPE(*CHAR) LEN(10)

             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))

             RTVJOBA    CURLIB(&LIB) USER(&USRPRF)
             CHGVAR     VAR(&LIBB) VALUE(%TRIM(&USRPRF) *TCAT 'B')
             RTVSYSVAL  SYSVAL(QDATE) RTNVAR(&DATE)
             CHGVAR     VAR(&SAVF) VALUE('BK' *TCAT &DATE)

             CHKOBJ     OBJ(&LIBB/&SAVF) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSAVF FILE(&LIBB/&SAVF) +
                          TEXT('Weekly backup'))

             SAVOBJ     OBJ(*ALL) LIB(&LIB) DEV(*SAVF) SAVF(&LIBB/&SAVF) +
                          OBJTYPE(*ALL)

             SNDPGMMSG  MSG('BACKUP: saved ' *TCAT &LIB *TCAT ' to ' *TCAT +
                          &LIBB *TCAT '/' *TCAT &SAVF)
             GOTO       CMDLBL(END)

FAILED:      SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) MSGDTA('BACKUP +
                          failed') MSGTYPE(*ESCAPE)

END:         ENDPGM
