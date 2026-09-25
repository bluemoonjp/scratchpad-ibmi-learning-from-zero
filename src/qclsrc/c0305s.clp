             PGM
             DCL        VAR(&I) TYPE(*DEC) LEN(5 0) VALUE(0)
             DCL        VAR(&SUM) TYPE(*DEC) LEN(7 0) VALUE(0)
             DCL        VAR(&SUMC) TYPE(*CHAR) LEN(10)

             DOFOR      VAR(&I) FROM(1) TO(10)
                CHGVAR     VAR(&SUM) VALUE(&SUM + &I)
             ENDDO

             CHGVAR     VAR(&SUMC) VALUE(&SUM)
             SNDPGMMSG  MSG('Sum 1..10 = ' *TCAT %TRIM(&SUMC))
             ENDPGM
