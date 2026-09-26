/* JUYAKC - nightly job stream skeleton (front / main / back / error).    */
/* The "main" section is a placeholder: Part 4 (04-08) plugs ZAHIK3 in    */
/* here once RPG III exists. See 03-13.                                   */
             PGM

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&NEXTNO) TYPE(*DEC) LEN(6 0)
             DCL        VAR(&TOSTMF) TYPE(*CHAR) LEN(200)

             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))

             RTVJOBA    CURLIB(&LIB) CURUSER(&USRPRF)

/* --- Front: allocate the next order number exclusively --- */
/* FIXED (part03-rtvjoba-fix, 2026-09-26, real-hardware CRTCLPGM):     */
/* ALCOBJ/DLCOBJ's OBJ parameter needs THREE list items per object -   */
/* name, type, AND lock state - not just name+type (CPD0072 "List     */
/* item value for parameter OBJ required"). *EXCL matches this        */
/* header's own "exclusively" intent and is valid for *DTAARA.        */
             ALCOBJ     OBJ((&LIB/JUNODA *DTAARA *EXCL)) WAIT(10)
             MONMSG     MSGID(CPF1002 CPF1085) EXEC(DO)
                SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) +
                             MSGDTA('JUNODA locked') MSGTYPE(*ESCAPE)
             ENDDO

             RTVDTAARA  DTAARA(&LIB/JUNODA) RTNVAR(&NEXTNO)
             CHGVAR     VAR(&NEXTNO) VALUE(&NEXTNO + 1)
             CHGDTAARA  DTAARA(&LIB/JUNODA) VALUE(&NEXTNO)
             DLCOBJ     OBJ((&LIB/JUNODA *DTAARA *EXCL))

/* --- Main: business processing plugs in here (Part 4 onward) --- */

/* --- Back: export today's order count as CSV for the report queue --- */
             CHGVAR     VAR(&TOSTMF) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                          *TCAT '/work/juchum_export.csv')
             CPYTOIMPF  FROMFILE(&LIB/JUCHUM) TOSTMF(&TOSTMF) +
                          MBROPT(*REPLACE) STMFCCSID(1208)

             SNDPGMMSG  MSG('JUYAKC: done. Next order number is now ' +
                          *BCAT %CHAR(&NEXTNO) *BCAT '.')
             GOTO       CMDLBL(END)

/* --- Error: notify via the curriculum message file --- */
FAILED:      SNDPGMMSG  MSGID(JUM0001) MSGF(&LIB/JUMSGF) +
                          MSGDTA('JUYAKC failed') MSGTYPE(*ESCAPE)

END:         ENDPGM
