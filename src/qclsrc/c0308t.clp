/* C0308T - the "target" program for the CALL-literal experiment (03-08). */
             PGM        PARM(&NUM)

             DCL        VAR(&NUM) TYPE(*DEC) LEN(5 0)
             DCL        VAR(&NUMC) TYPE(*CHAR) LEN(15)

             CHGVAR     VAR(&NUMC) VALUE(&NUM)
             SNDPGMMSG  MSG('Received: ' *TCAT %TRIM(&NUMC))

             ENDPGM
