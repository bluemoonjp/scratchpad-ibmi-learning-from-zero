/* TXLOAD - fetch and compile the model answer for one lesson from        */
/*          solutions/, sparse-checking it out first if this clone does   */
/*          not have it yet (solutions/ is excluded from the default      */
/*          sparse-checkout set - review-triage B2-8). Never touches a    */
/*          learner's own A-R suffixed member; solutions/ file names      */
/*          never end that way, so there is nothing to collide with.      */
/*                                                                        */
/* Only OBJ(RPG|CLP) is implemented: point this at the model answer's     */
/* actual source type. DDS solutions (a display/printer file) would need  */
/* a third branch here - none exist under solutions/ yet.                 */
/*                                                                        */
/* PARM:                                                                  */
/*   SOL      lesson id, e.g. '03-14'. Required.                          */
/*   FILE     solution file name under solutions/SOL/, without the        */
/*            extension (e.g. 'backup' for solutions/03-14/backup.clp).   */
/*            Required.                                                   */
/*   OBJ      object/member name to compile it as, e.g. 'BACKUP'.         */
/*            Required.                                                   */
/*   TYPE     'RPG' or 'CLP'. Required.                                   */
/*   LIB      target library. Default *CURLIB.                            */
/*   CLONEDIR absolute path of the git clone. Default: your home         */
/*            directory + /ibmi-kyozai (computed from your profile).     */
             PGM        PARM(&SOL &FILE &OBJ &TYPE &LIB &CLONEDIR)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&SOL) TYPE(*CHAR) LEN(10)
             DCL        VAR(&FILE) TYPE(*CHAR) LEN(30)
             DCL        VAR(&OBJ) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TYPE) TYPE(*CHAR) LEN(3)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)

             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SOLDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRCFILE) TYPE(*CHAR) LEN(10)
             DCL        VAR(&QSHCMD) TYPE(*CHAR) LEN(300)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&SOL *EQ ' ' *OR &FILE *EQ ' ' *OR &OBJ *EQ +
                          ' ' *OR &TYPE *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TXLOAD: SOL, FILE, OBJ and TYPE are all +
                             required.')
                RETURN
             ENDDO
             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                RTVJOBA    CURUSER(&USRPRF)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO

             CHGVAR     VAR(&SOLDIR) VALUE('solutions/' *TCAT %TRIM(&SOL))

             /* Make sure this clone actually has the solution files      */
             /* (sparse-checkout excludes solutions/ by default). -C      */
             /* avoids needing a separate `cd` step. Safe to run even if  */
             /* the path is already included: git just reports no change. */
             CHGVAR     VAR(&QSHCMD) VALUE('git -C ' *TCAT &CLONEDIR *TCAT +
                          ' sparse-checkout add ' *TCAT &SOLDIR)
             QSH        CMD(&QSHCMD)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXLOAD: git sparse-checkout add failed - is +
                             this library CLONEDIR actually a git clone?')
                RETURN
             ENDDO

             IF         COND(&TYPE *EQ 'RPG') THEN(DO)
                CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT '/' *TCAT +
                             &SOLDIR *TCAT '/' *TCAT %TRIM(&FILE) *TCAT +
                             '.rpg')
                CHGVAR     VAR(&SRCFILE) VALUE('QRPGSRC')
             ENDDO
             IF         COND(&TYPE *EQ 'CLP') THEN(DO)
                CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT '/' *TCAT +
                             &SOLDIR *TCAT '/' *TCAT %TRIM(&FILE) *TCAT +
                             '.clp')
                CHGVAR     VAR(&SRCFILE) VALUE('QCLSRC')
             ENDDO
             IF         COND(&SRCFILE *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TXLOAD: TYPE must be RPG or CLP (DSPF +
                             solutions are not implemented yet).')
                RETURN
             ENDDO

             ADDPFM     FILE(&LIB/&SRCFILE) MBR(&OBJ) SRCTYPE(&TYPE) +
                          TEXT('TXLOAD model answer: ' *CAT %TRIM(&SOL))
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/' *TCAT %TRIM(&SRCFILE) *TCAT +
                          '.FILE/' *TCAT %TRIM(&OBJ) *TCAT '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)

             IF         COND(&TYPE *EQ 'RPG') THEN(CRTRPGPGM +
                          PGM(&LIB/&OBJ) SRCFILE(&LIB/QRPGSRC) +
                          SRCMBR(&OBJ) REPLACE(*YES))
             IF         COND(&TYPE *EQ 'CLP') THEN(CRTCLPGM +
                          PGM(&LIB/&OBJ) SRCFILE(&LIB/QCLSRC) +
                          SRCMBR(&OBJ) REPLACE(*YES))

             SNDPGMMSG  MSG('TXLOAD: loaded ' *CAT %TRIM(&SOL) *CAT '/' +
                          *CAT %TRIM(&FILE) *CAT ' as ' *CAT %TRIM(&LIB) +
                          *CAT '/' *CAT %TRIM(&OBJ) *CAT '.')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXLOAD: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
