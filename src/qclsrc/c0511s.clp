/* C0511S - plant a decimal data error in JUCHUD for 05-11's incident      */
/*          exercise. Legacy system (Part 5), NOT part of src/legacy/      */
/*          (this is a teaching tool the learner runs against their own    */
/*          copy, not a distributed "old system" object).                  */
/*                                                                          */
/* Design (general IBM i knowledge, NOT confirmed against any primary      */
/* source in work/design/refs/ or a real compile this session - verify     */
/* before relying on this): CPYF's FMTOPT(*NOCHK) is documented (outside   */
/* this repo) to copy records between differently-typed formats without    */
/* the normal field-type check that would otherwise reject the copy. This  */
/* program builds JUBADD (src/legacy/qddssrc/jubadd.pf - identical to      */
/* JUCHUD except its JUSU is 5A, not 5S 0), inserts one row into it with   */
/* JUSU='ABCDE' (valid character data for JUBADD's own 5A field), then     */
/* CPYF FMTOPT(*NOCHK)s that row into JUCHUD - landing 'ABCDE''s raw bytes */
/* in JUCHUD.JUSU, which is not valid zoned decimal. The next arithmetic   */
/* operation on that row's JUSU (ZA0500's `SUB JUSU AVAIL`, reached via    */
/* JU0900C) is expected to raise a decimal data error (MCH1202).           */
/*                                                                          */
/* Uses product code P00001 (a real ZAIKOM row, per za0510.rpg's header    */
/* comment / db/data/load_v1.sql) so the planted row actually reaches      */
/* ZA0500's CHAIN/SUB path when JU0900C runs, instead of being skipped as  */
/* a not-found product.                                                    */
/*                                                                          */
/* PARM:                                                                    */
/*   LIB       library to plant the bad row in. Default *CURLIB.           */
/*   CLONEDIR  IFS path of the git clone (for jubadd.pf's source). Default */
/*             ~/scratchpad-ibmi-learning-from-zero.                       */
/*                                                                          */
/* Afterward: run JU0900C, read the job log / QPJOBLOG entry for the       */
/* MCH1202 (05-11's investigation exercise), then run TXRESET to restore   */
/* JUCHUD to its normal data (TXRESET restores DATA only - it does not     */
/* need to know about JUBADD, which TXRESET never touches).                */
             PGM        PARM(&LIB &CLONEDIR)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(300)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(300)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             RTVJOBA    USRPRF(&USRPRF)
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF))
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR *TCAT +
                             '/scratchpad-ibmi-learning-from-zero')
             ENDDO

             /* Step 1: build JUBADD (create if missing, matching          */
             /* txsetup.clp's own CHKOBJ + conditional-CRTPF idiom - CRTPF */
             /* has no REPLACE parameter, confirmed this session).         */
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qddssrc/jubadd.pf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(JUBADD) SRCTYPE(PF) +
                          TEXT('05-11 mis-typed staging (see jubadd.pf)')
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/JUBADD.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CHKOBJ     OBJ(&LIB/JUBADD) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTPF FILE(&LIB/JUBADD) +
                          SRCFILE(&LIB/QDDSSRC) SRCMBR(JUBADD) TEXT('05-11 +
                          mis-typed staging'))

             /* Step 2: clear any leftover row from a previous run, then   */
             /* insert one row with JUSU='ABCDE' - valid for JUBADD's own  */
             /* 5A field, invalid once its raw bytes land in JUCHUD.JUSU.  */
             RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUBADD WHERE JUNO = ''C05119''') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000)
             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUBADD VALUES (''C05119'', 1, ''P00001'', +
                          ''ABCDE'', 100.00)') COMMIT(*NONE)

             /* Step 3: clear any leftover planted row in JUCHUD itself    */
             /* (same key, in case this program is run twice without a    */
             /* TXRESET in between), then CPYF FMTOPT(*NOCHK) the bad row  */
             /* across the type mismatch into JUCHUD.                     */
             RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUD WHERE JUNO = ''C05119''') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000)
             CPYF       FROMFILE(&LIB/JUBADD) TOFILE(&LIB/JUCHUD) +
                          MBROPT(*ADD) FMTOPT(*NOCHK)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('C0511S: CPYF FMTOPT(*NOCHK) failed - see +
                             the job log. The decimal-error scenario was +
                             not planted.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO

             SNDPGMMSG  MSG('C0511S: planted a decimal data error in +
                          JUCHUD (JUNO=C05119, JULINE=1). Run JU0900C +
                          next, then investigate the job log.')
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('C0511S: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
