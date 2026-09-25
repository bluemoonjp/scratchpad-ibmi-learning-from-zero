/* TXCHECK - run the checks recorded for one lesson and print PASS/FAIL.  */
/*                                                                        */
/* Build order: tools/qddssrc/txckm.pf (the manifest) must be created     */
/* and populated in the compiling library before this program is         */
/* compiled (DCLF below needs a real TXCKM to read its field layout).     */
/*                                                                        */
/* v1 scope: object existence + type only (CHKOBJ), matching the highest */
/* -priority item from the design review ("check that the required       */
/* objects exist, with the right type"). Not yet compiled or run on      */
/* PUB400 - kept on draft/tools until verified.                          */
/*                                                                        */
/* TODO (tracked in Issue #5's TXCHECK follow-up comment): data checks   */
/* (row counts / hash of a SELECT result) and static source checks       */
/* (required/forbidden opcodes, no library qualification, ASCII only).   */
/* Both need a way to run one SQL statement and get a scalar/row-count   */
/* back into a CL variable without embedded SQL; the planned approach is */
/* RUNSQL into a QTEMP table followed by RTVMBRD NBRCURRCD(&CNT) to read */
/* its row count back (both plain CL commands, no SQLRPGLE needed) - add */
/* a CHKTYP column to TXCKM to pick between the CHKOBJ path below and    */
/* this one once it exists.                                              */
/*                                                                        */
/* PARM:                                                                  */
/*   LESSON   lesson id, e.g. '04-13'. Required.                          */
/*   LIB      library to check objects in. Default *CURLIB.               */
             PGM        PARM(&LESSONP &LIB)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&LESSONP) TYPE(*CHAR) LEN(6)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)

             DCL        VAR(&PASSCNT) TYPE(*DEC) LEN(5 0) VALUE(0)
             DCL        VAR(&FAILCNT) TYPE(*DEC) LEN(5 0) VALUE(0)
             DCL        VAR(&CNTC) TYPE(*CHAR) LEN(10)

             /* DCLF against the manifest record format. RCVF below fills */
             /* &LESSON/&SEQNBR/&OBJNAME/&OBJTYPE/&OBJATTR/&CKDESC (the   */
             /* DDS field names) on every read - do not reuse those names */
             /* for anything else in this program (hence &LESSONP above,  */
             /* distinct from the DDS field LESSON).                      */
             DCLF       FILE(TXCKM)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

             /* SHARE(*YES) so this program's own implicit open (the      */
             /* first RCVF below) reuses OPNQRYF's filtered open data     */
             /* path instead of opening TXCKM independently (and          */
             /* unfiltered). Same pattern lesson 05-06 reads in JU0900C.  */
             OVRDBF     FILE(TXCKM) TOFILE(&LIB/TXCKM) SHARE(*YES)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCHECK: manifest TXCKM not found in ' +
                             *CAT %TRIM(&LIB) *CAT '. Nothing to check.')
                RETURN
             ENDDO

             OPNQRYF    FILE((TXCKM)) QRYSLT('LESSON *EQ ''' *TCAT +
                          %TRIM(&LESSONP) *TCAT '''') KEYFLD((SEQNBR))
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCHECK: could not query the manifest for +
                             lesson ' *CAT %TRIM(&LESSONP) *CAT '.')
                GOTO       CMDLBL(TXCLOF)
             ENDDO

NEXTCHK:     RCVF
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(SUMMARY))

             CHKOBJ     OBJ(&LIB/&OBJNAME) OBJTYPE(&OBJTYPE)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                CHGVAR     VAR(&FAILCNT) VALUE(&FAILCNT + 1)
                SNDPGMMSG  MSG('TXCHECK FAIL: ' *CAT %TRIM(&CKDESC) *CAT +
                             ' (' *CAT %TRIM(&OBJNAME) *CAT ' ' *CAT +
                             %TRIM(&OBJTYPE) *CAT ' not found in ' *CAT +
                             %TRIM(&LIB) *CAT ')')
                GOTO       CMDLBL(NEXTCHK)
             ENDDO

             CHGVAR     VAR(&PASSCNT) VALUE(&PASSCNT + 1)
             SNDPGMMSG  MSG('TXCHECK PASS: ' *CAT %TRIM(&CKDESC))
             GOTO       CMDLBL(NEXTCHK)

SUMMARY:     CHGVAR     VAR(&CNTC) VALUE(&PASSCNT)
             SNDPGMMSG  MSG('TXCHECK: lesson ' *CAT %TRIM(&LESSONP) *CAT +
                          ' - ' *CAT %TRIM(&CNTC) *CAT ' passed, ')
             CHGVAR     VAR(&CNTC) VALUE(&FAILCNT)
             SNDPGMMSG  MSG(%TRIM(&CNTC) *CAT ' failed.')

TXCLOF:      CLOF       FILE(TXCKM)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(TXCKM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('TXCHECK: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
