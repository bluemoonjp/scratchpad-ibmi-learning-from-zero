/* C0511S - plant a decimal data error in JUCHUD for 05-11's incident      */
/*          exercise. Legacy system (Part 5), NOT part of src/legacy/      */
/*          (this is a teaching tool the learner runs against their own    */
/*          copy, not a distributed "old system" object).                  */
/*                                                                          */
/* Design: CPYF's FMTOPT(*NOCHK) copies records between differently-typed  */
/* formats without the normal field-type check that would otherwise reject */
/* the copy. This program builds JUBADD (src/legacy/qddssrc/jubadd.pf -    */
/* identical to JUCHUD except its JUSU is 5A, not 5S 0), inserts one row   */
/* into it, then CPYF FMTOPT(*NOCHK)s that row into JUCHUD - landing the   */
/* raw character bytes in JUCHUD.JUSU, which may or may not be valid       */
/* zoned decimal depending on what was planted (see FIXED note below).     */
/*                                                                          */
/* CONFIRMED, real hardware (part05-mch1202-corrupt, 2026-09-27): JUSU=      */
/* 'ABCDE' is planted deliberately, KEEPING it despite an early finding      */
/* that it is not, in the strictest sense, corrupted data at all: EBCDIC     */
/* 'A'-'E' are X'C1'-X'C5' - the digit (low) nibbles are 1-5 (all valid) and */
/* the LAST byte's zone (high) nibble is C, a valid POSITIVE sign nibble.    */
/* Under an isolated, verification-only JUCHUM/ticket-1-fixed setup          */
/* (part05-mch1202-corrupt's own manifest), OPM RPG/400 read this as         */
/* JUSU=12345 with NO decimal-data error at all - a vividly absurd order     */
/* quantity, visible via a plain SELECT, silently used in arithmetic.        */
/* Blanks (X'40' per byte) were tried as an alternative on the assumption    */
/* that an invalid sign nibble would trigger a real decimal-data error -     */
/* ALSO refuted on real hardware (JUSU read as 0, still no error). Given     */
/* NEITHER value raises a decimal-data error through this corruption path,   */
/* 'ABCDE' was kept as the main demo value specifically because its silent   */
/* misreading (12345) is the more vivid, teachable illustration - see        */
/* docs/part05/05-11-decimal-data-error.md's real-hardware notes for the     */
/* full investigation and the lesson's own reframing around this.           */
/*                                                                          */
/* Uses product code P00001 (a real ZAIKOM row, per za0510.rpg's header    */
/* comment / db/data/load_v1.sql) so the planted row actually reaches      */
/* ZA0500's CHAIN/SUB path when JU0900C runs, instead of being skipped as  */
/* a not-found product.                                                    */
/*                                                                          */
/* FIXED (found while writing 05-11's lesson): the first version of this   */
/* program planted JUNO=C05119 into JUCHUD only. ZA0500 only reaches       */
/* `SUB JUSU AVAIL` on a MATCHED (01+MR) primary/secondary pair - with no  */
/* matching JUCHUM header row, the M1/MR match fails and the planted row   */
/* is simply skipped (GOTO SKPALL), never reaching the corrupted JUSU at   */
/* all. Also inserts a JUCHUM header row for the same JUNO now (real       */
/* customer C00001, rep T00001, per db/data/load_v1.sql), so the row is    */
/* an actual matched pair.                                                 */
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
             /* CURUSER, not USER: RTVJOBA USER() returns the job name's    */
             /* user part, which is QUSER for a PASE system()-launched job  */
             /* (not the real signed-on/SSH-authenticated profile). This    */
             /* was root-caused and fixed the same way in                   */
             /* tools/qclsrc/txsetup.clp/txreset.clp (docs/probes.md's      */
             /* "QUSER problem reproduces via *CMD too; root cause is       */
             /* RTVJOBA USER's own spec" finding). The original             */
             /* USRPRF(&USRPRF) here was also simply an invalid keyword     */
             /* (CPD0043; docs/probes.md line 115) - both bugs fixed        */
             /* together.                                                   */
             RTVJOBA    CURUSER(&USRPRF)
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF))
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR *TCAT '/ibmi-kyozai')
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
             /* insert one row with JUSU='ABCDE' - valid character data    */
             /* for JUBADD's own 5A field. See the header note above: this */
             /* is kept despite reading back as a valid (not corrupted)    */
             /* zoned decimal value on this hardware - its silent, absurd  */
             /* misreading (12345) is the point.                           */
             RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUBADD WHERE JUNO = ''C05119''') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000)
             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUBADD VALUES (''C05119'', 1, ''P00001'', +
                          ''ABCDE'', 100.00)') COMMIT(*NONE)

             /* Step 3: also plant a matching JUCHUM header row, so the    */
             /* JUCHUD row planted below is part of a genuine matched      */
             /* (01+MR) pair - real customer C00001/rep T00001, matching   */
             /* db/data/load_v1.sql's own J00001 row's pairing. Without    */
             /* this, ZA0500's M1/MR match on this JUNO fails and the      */
             /* corrupted row is skipped entirely (GOTO SKPALL) - see the  */
             /* header note above.                                        */
             RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM WHERE JUNO = ''C05119''') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000)
             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM VALUES (''C05119'', ''C00001'', +
                          20260926, ''T00001'')') COMMIT(*NONE)

             /* Step 4: clear any leftover row in JUCHUD itself (same key, */
             /* in case this program is run twice without a TXRESET in    */
             /* between), then CPYF FMTOPT(*NOCHK) the bad row across the  */
             /* type mismatch into JUCHUD.                                */
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
