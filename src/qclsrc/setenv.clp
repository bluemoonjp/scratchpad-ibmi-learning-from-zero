/* SETENV - switch between the development (*DEV) and production-stand-in */
/*          (*PRD) environment by changing the current library. Keeps    */
/*          <profile>1 reachable via *LIBL even in *PRD mode, since      */
/*          tools compiled there (SETENV itself, EXPSRC, ...) must stay  */
/*          callable. See 03-11 and 05-12.                                */
             PGM        PARM(&ENV)

             DCL        VAR(&ENV) TYPE(*CHAR) LEN(4)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB1) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)

             IF         COND(&ENV *EQ ' ') THEN(CHGVAR VAR(&ENV) +
                          VALUE('*DEV'))

             RTVJOBA    CURUSER(&USRPRF)
             CHGVAR     VAR(&LIB1) VALUE(%TRIM(&USRPRF) *TCAT '1')
             CHGVAR     VAR(&LIB2) VALUE(%TRIM(&USRPRF) *TCAT '2')

             IF         COND(&ENV *EQ '*PRD') THEN(DO)
                CHGCURLIB  CURLIB(&LIB2)
                ADDLIBLE   LIB(&LIB1) POSITION(*LAST)
                MONMSG     MSGID(CPF2103)
                SNDPGMMSG  MSG('SETENV: now *PRD (curlib=' *TCAT +
                             %TRIM(&LIB2) *TCAT ')')
             ENDDO
             ELSE       CMD(DO)
                CHGCURLIB  CURLIB(&LIB1)
                RMVLIBLE   LIB(&LIB2)
                MONMSG     MSGID(CPF2105)
                SNDPGMMSG  MSG('SETENV: now *DEV (curlib=' *TCAT +
                             %TRIM(&LIB1) *TCAT ')')
             ENDDO

             DSPLIBL
             ENDPGM
