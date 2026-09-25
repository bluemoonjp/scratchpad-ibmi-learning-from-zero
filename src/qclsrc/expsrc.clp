/* EXPSRC - export one source member to the IFS work directory, so it can */
/*          be committed with git (see 03-10).                            */
             PGM        PARM(&SRCFILE &SRCMBR)

             DCL        VAR(&SRCFILE) TYPE(*CHAR) LEN(10)
             DCL        VAR(&SRCMBR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TOSTMF) TYPE(*CHAR) LEN(200)

             RTVJOBA    CURLIB(&LIB) USER(&USRPRF)

             CHGVAR     VAR(&TOSTMF) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                          *TCAT '/work/' *TCAT %TRIM(&SRCMBR) *TCAT '.txt')

             CPYTOSTMF  FROMMBR('/QSYS.LIB/' *TCAT %TRIM(&LIB) *TCAT +
                          '.LIB/' *TCAT %TRIM(&SRCFILE) *TCAT '.FILE/' +
                          *TCAT %TRIM(&SRCMBR) *TCAT '.MBR') +
                          TOSTMF(&TOSTMF) STMFOPT(*REPLACE) STMFCCSID(1208) +
                          ENDLINFMT(*LF)

             SNDPGMMSG  MSG('EXPSRC: exported to ' *TCAT &TOSTMF)

             ENDPGM
