/* P0512B - probe for Issue #27 (05-12 step 13). Runs inside the       */
/* harness wrapper job (CALLed by the wrapper, so it shares its job).  */
/* Records the library list into VFYCUR at every stage. Only job      */
/* attributes (current library, library list) are changed; no object  */
/* is created or changed in the private area.                         */
             PGM        PARM(&LIBP)
             DCL        VAR(&LIBP) TYPE(*CHAR) LEN(32)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&L1) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TAG) TYPE(*CHAR) LEN(40)
             DCL        VAR(&FND) TYPE(*CHAR) LEN(10)
             DCL        VAR(&SQL) TYPE(*CHAR) LEN(400)
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))

             CHGVAR     VAR(&LIB) VALUE(%SST(&LIBP 1 10))
             RTVJOBA    CURUSER(&USR)
             CHGVAR     VAR(&L1) VALUE(%TRIM(&USR) *TCAT '1')

/* B1: current library is still the private one, RMVLIBLE it        */
             CHGVAR     VAR(&TAG) VALUE('B0-INIT')
             CALLSUBR   SUBR(REC)
             CHGCURLIB  CURLIB(&L1)
             CHGVAR     VAR(&TAG) VALUE('B1-CURLIB-IS-L1')
             CALLSUBR   SUBR(REC)
             RMVLIBLE   LIB(&L1)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('P0512B B1: RMVLIBLE ended with escape')
             ENDDO
             CHGVAR     VAR(&TAG) VALUE('B1-AFTER-RMVLIBLE')
             CALLSUBR   SUBR(REC)

/* B2: SETENV *PRD first, then RMVLIBLE                               */
             CALL       PGM(&LIB/SETENV) PARM('*PRD')
             MONMSG     MSGID(CPF0000 MCH0000) EXEC(DO)
                SNDPGMMSG  MSG('P0512B B2: SETENV *PRD ended with escape')
             ENDDO
             CHGVAR     VAR(&TAG) VALUE('B2-AFTER-SETENV-PRD')
             CALLSUBR   SUBR(REC)
             RMVLIBLE   LIB(&L1)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('P0512B B2: RMVLIBLE ended with escape')
             ENDDO
             CHGVAR     VAR(&TAG) VALUE('B2-AFTER-RMVLIBLE')
             CALLSUBR   SUBR(REC)
             RTVOBJD    OBJ(*LIBL/TK0100D) OBJTYPE(*FILE) RTNLIB(&FND)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                CHGVAR     VAR(&FND) VALUE('NOTFOUND')
             ENDDO
             CHGVAR     VAR(&TAG) VALUE('B2-TK0100D-FOUND-' *TCAT &FND)
             CALLSUBR   SUBR(REC)

             CHGCURLIB  CURLIB(&LIB)
             SNDPGMMSG  MSG('P0512B DONE')
             RETURN
FAILED:      SNDPGMMSG  MSG('P0512B FAILED (program-level MONMSG)')
             RETURN

             SUBR       SUBR(REC)
                CHGVAR     VAR(&SQL) VALUE('INSERT INTO ' *CAT +
                             %TRIM(&LIB) *CAT '/VFYCUR SELECT ''' +
                             *CAT %TRIM(&TAG) *CAT ''', ' *CAT +
                             'ORDINAL_POSITION, SCHEMA_NAME, TYPE ' +
                             *CAT 'FROM QSYS2.LIBRARY_LIST_INFO')
                RUNSQL     SQL(&SQL) COMMIT(*NONE)
                MONMSG     MSGID(CPF0000 SQL0000)
             ENDSUBR
             ENDPGM
