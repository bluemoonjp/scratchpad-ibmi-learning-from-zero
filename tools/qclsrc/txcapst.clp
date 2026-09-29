/* TXCAPST - prepare the Part 10 (capstone) incident for lesson 10-01.    */
/*           Teaching tool the learner runs against their own copy; NOT   */
/*           part of src/legacy/.                                          */
/*                                                                        */
/* HONOR SYSTEM: read this file AFTER you have written your incident      */
/* report (the 10-01 exercise), not before. tools/ is fully visible in    */
/* your clone; looking here first spoils the investigation. Nothing       */
/* enforces this except you.                                              */
/*                                                                        */
/* What it does: plants ONE sentinel order (JUNO J00000, one line, real   */
/* product P00001) whose quantity field is not valid zoned decimal, plus  */
/* the matching order header so the pair is really read. It uses the same */
/* mechanism as src/qclsrc/c0511s.clp (05-11): a QTEMP staging copy of    */
/* src/legacy/qddssrc/jubadd.pf (quantity 5A) is filled with '.....' and  */
/* copied to JUCHUD with CPYF FMTOPT(*NOCHK). J00000 sorts before every   */
/* other order, so it is the first record the batch reads.                */
/*                                                                        */
/* It never runs JU0900C and never writes the TXSTATE data area (TXSTATE  */
/* is only read, to choose the column list of the header INSERT).         */
/*                                                                        */
/* All work (compile, INSERT, CPYF) happens inside this ONE job: QTEMP    */
/* belongs to the job, so the staging file cannot be built in one call    */
/* and copied in another.                                                 */
/*                                                                        */
/* Guards: TXLEGST (TXLEGACY marker) must exist; TXCAPFL (data area, 'Y') */
/* marks an already planted incident. A rerun without FORCE(*YES) refuses.*/
/* FORCE(*YES) deletes the sentinel rows and plants them again.           */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB      target library. Required by the command.                    */
/*   CLONEDIR absolute path of the git clone (for jubadd.pf). Default:    */
/*            your home directory + /ibmi-kyozai (from your profile).     */
/*   FORCE    *YES plants again even if TXCAPFL exists.                   */
/*                                                                        */
/* UNVERIFIED (2026-09-30): the DBVER 2 branch of the header INSERT. At   */
/* DBVER 2 JUCHUM has the extra column JUDLV (db/v2/juchum.pf), without   */
/* a default; the branch below gives it an explicit value. Not yet run    */
/* on PUB400; see verify/part10-00-probe step 5.                           */
             PGM        PARM(&LIB &CLONEDIR &FORCE)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)

             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(300)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(300)
             DCL        VAR(&DBVER) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&MSG) TYPE(*CHAR) LEN(200)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

/* --- Fill in defaults for omitted/blank parameters --- */
             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&FORCE *EQ ' ') THEN(CHGVAR VAR(&FORCE) +
                          VALUE('*NO'))

/* --- CURUSER, not USER: see tools/qclsrc/txsetup.clp for why. --- */
             RTVJOBA    CURUSER(&USRPRF)
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO

             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

/* --- Prerequisite: the legacy system must be loaded (TXLEGST). --- */
             CHKOBJ     OBJ(&LIB/TXLEGST) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                CHGVAR     VAR(&MSG) VALUE('TXCAPST: the legacy system is +
                             not loaded in ' *CAT %TRIM(&LIB) *CAT '. Run +
                             TXLEGACY first.')
                SNDPGMMSG  MSG(&MSG)
                RETURN
             ENDDO

/* --- Already planted? (flag data area TXCAPFL) --- */
             CHKOBJ     OBJ(&LIB/TXCAPFL) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(PLANT))
             IF         COND(&FORCE *NE '*YES') THEN(DO)
                SNDPGMMSG  MSG('TXCAPST: already prepared in this library. +
                             Use FORCE(*YES) to plant it again.')
                GOTO       CMDLBL(TXEND)
             ENDDO

/* --- Step a: remove old sentinel rows. C05119 (from 05-11) sorts before */
/* J00000 in EBCDIC, so a leftover one would be read first. --- */
PLANT:       RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUD WHERE JUNO IN (''J00000'', ''C05119'')') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)
             RUNSQL     SQL('DELETE FROM ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM WHERE JUNO IN (''J00000'', ''C05119'')') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

/* --- Step b: build the staging file in QTEMP. The source member lives   */
/* in LIB/QDDSSRC (as in c0511s); every file reference below is QTEMP/    */
/* JUBADD, never LIB/JUBADD (a 05-11 run may have left one there). --- */
             CHKOBJ     OBJ(&LIB/QDDSSRC) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF FILE(&LIB/QDDSSRC) +
                          RCDLEN(92) TEXT('Curriculum DDS sources'))
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qddssrc/jubadd.pf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(JUBADD) SRCTYPE(PF) +
                          TEXT('Staging file source (see jubadd.pf)')
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/JUBADD.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CHKOBJ     OBJ(QTEMP/JUBADD) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTPF FILE(QTEMP/JUBADD) +
                          SRCFILE(&LIB/QDDSSRC) SRCMBR(JUBADD) +
                          TEXT('Staging file'))
             RUNSQL     SQL('DELETE FROM QTEMP/JUBADD') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

/* --- Step a2: put the header in arrival order. ZA0500 reads JUCHUM in   */
/* ARRIVAL sequence (program-described, no key), and RPG match fields     */
/* must be ascending. A header for J00000 appended after J00001..J00008   */
/* is out of sequence (RPG1031, real run 2026-09-29). So: save the rows   */
/* in QTEMP, empty JUCHUM (CLRPFM), insert J00000 first (step c), then    */
/* put the saved rows back in JUNO order (step c2). --- */
             DLTF       FILE(QTEMP/TXCAPHD)
             MONMSG     MSGID(CPF2105)
             RUNSQL     SQL('CREATE TABLE QTEMP/TXCAPHD AS (SELECT * FROM ' +
                          *CAT %TRIM(&LIB) *CAT '/JUCHUM) WITH DATA') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not save the order headers. +
                             Nothing was changed.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO
             CLRPFM     FILE(&LIB/JUCHUM)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not empty JUCHUM. Run +
                             TXRESET if orders are missing.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO

/* --- Step c: the order header first. The column list is explicit.       */
/* DBVER 1 (JUCHUM 26 bytes): four columns. DBVER 2 adds JUDLV, which has */
/* no default, so it gets a value (UNVERIFIED, see the header). TXSTATE   */
/* is only read here, never written. --- */
             RTVDTAARA  DTAARA(&LIB/TXSTATE) RTNVAR(&DBVER)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&DBVER) VALUE(1))
             IF         COND(&DBVER *GE 2) THEN(GOTO CMDLBL(HDRV2))

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM (JUNO, JUTOK, JUDATE, JUTAN) VALUES +
                          (''J00000'', ''C00001'', 20260930, ''T00001'')') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not insert the order header. +
                             See the job log.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO
             GOTO       CMDLBL(RELOAD)

HDRV2:       RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM (JUNO, JUTOK, JUDATE, JUTAN, JUDLV) +
                          VALUES (''J00000'', ''C00001'', 20260930, +
                          ''T00001'', DATE(''2026-09-30''))') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not insert the order header +
                             (DBVER 2). See the job log.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO

/* --- Step c2: put the saved order headers back after J00000, in JUNO    */
/* order (ORDER BY keeps the arrival order ascending). --- */
RELOAD:      RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/JUCHUM SELECT * FROM QTEMP/TXCAPHD ORDER BY +
                          JUNO') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not restore the order +
                             headers. Run TXRESET.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO

/* --- Step d: one detail row into the staging file. Numeric 1 and 100.00 */
/* (not character literals), doubled quotes inside RUNSQL, exactly like   */
/* src/qclsrc/c0511s.clp. Then CPYF FMTOPT(*NOCHK) lands the raw bytes in */
/* JUCHUD. --- */
DETAIL:      RUNSQL     SQL('INSERT INTO QTEMP/JUBADD VALUES (''J00000'', +
                          1, ''P00001'', ''.....'', 100.00)') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: could not fill the staging file. +
                             See the job log.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO
             CPYF       FROMFILE(QTEMP/JUBADD) TOFILE(&LIB/JUCHUD) +
                          MBROPT(*ADD) FMTOPT(*NOCHK)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPST: CPYF FMTOPT(*NOCHK) failed. See +
                             the job log. The incident was not planted.')
                GOTO       CMDLBL(FAILSAFE)
             ENDDO

/* --- Flag: set TXCAPFL last, so a failed plant leaves no flag. --- */
             CHKOBJ     OBJ(&LIB/TXCAPFL) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(CRTDTAARA DTAARA(&LIB/TXCAPFL) +
                          TYPE(*CHAR) LEN(1) VALUE('Y') TEXT('Capstone +
                          incident planted flag'))
             MONMSG     MSGID(CPF0000) EXEC(CHGDTAARA DTAARA(&LIB/TXCAPFL) +
                          VALUE('Y'))

/* --- Step f: report. No key or byte names on purpose. --- */
             CHGVAR     VAR(&MSG) VALUE('TXCAPST: incident condition +
                          prepared in library ' *CAT %TRIM(&LIB) *CAT '.')
             SNDPGMMSG  MSG(&MSG)
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXCAPST: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
