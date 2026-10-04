/* TXLEGACY - load and compile the legacy system (src/legacy) into one    */
/*            library. Only runs if not already loaded, unless            */
/*            FORCE(*YES); a FORCE(*YES) rerun saves the library to a     */
/*            SAVF in <profile>B first (see docs: <USER>B is the SAVF/    */
/*            backup role, never overwritten silently).                   */
/*                                                                        */
/* Prerequisite: this repo has been git-cloned (sparse) into ~/ibmi-kyozai,*/
/* and TXSETUP has already built the sample database in this library      */
/* (the legacy programs reference TOKUIM/JUCHUM/JUCHUD/ZAIKOM/TANTOM).     */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB      target library. Default *CURLIB.                           */
/*   CLONEDIR absolute path of the git clone. Default: your home         */
/*            directory + /ibmi-kyozai (computed from your profile).     */
/*   FORCE    *YES rebuilds even if already loaded (backs up first).      */
/*   LANG     *RPG   load the RPG III sources (src/legacy/qrpgsrc).      */
/*            *RPGLE load the fixed-form RPG IV sources                   */
/*                   (src/legacy/qrpgle112), same object names.          */
/*            *SAME  (default) use the language recorded in data area     */
/*                   TXLEGLNG of the target library; *RPG if none.       */
/*            The language used is recorded in TXLEGLNG (CHAR 7).        */
             PGM        PARM(&LIB &CLONEDIR &FORCE &LANG)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)
             DCL        VAR(&LANG) TYPE(*CHAR) LEN(7)
             DCL        VAR(&LANGU) TYPE(*CHAR) LEN(7)
             DCL        VAR(&CURLANG) TYPE(*CHAR) LEN(7)

             /* CALLSUBR cannot pass arguments (a subroutine shares the   */
             /* caller's variables), so &P1 (member/object name) / &P1LC  */
             /* (matching lowercase repo file name, hardcoded at each     */
             /* call site) / &P2 (description) are set before each call. */
             DCL        VAR(&P1) TYPE(*CHAR) LEN(10)
             DCL        VAR(&P1LC) TYPE(*CHAR) LEN(10)
             DCL        VAR(&P2) TYPE(*CHAR) LEN(50)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(200)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&LIBB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DATE) TYPE(*CHAR) LEN(6)
             DCL        VAR(&SAVF) TYPE(*CHAR) LEN(10)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

/* --- LANG: a caller that passes only three parameters gets MCH3601 on  */
/* the first reference to &LANG; treat as *SAME. (On hardware, an older   */
/* 3-parameter *CMD or a CALL with 3 parameters is already rejected by    */
/* CALL with CPD0172 before this runs: recreate the *CMD together with    */
/* the *PGM. This MONMSG is only a second line of defence.) ---           */
             CHGVAR     VAR(&LANGU) VALUE(&LANG)
             MONMSG     MSGID(MCH3601) EXEC(CHGVAR VAR(&LANGU) +
                          VALUE('*SAME'))
             IF         COND(&LANGU *EQ ' ') THEN(CHGVAR VAR(&LANGU) +
                          VALUE('*SAME'))

/* --- Fill in defaults for omitted/blank parameters --- */
             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&FORCE *EQ ' ') THEN(CHGVAR VAR(&FORCE) +
                          VALUE('*NO'))

/* --- CURUSER, not USER: see tools/qclsrc/txsetup.clp for why. --- */
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                RTVJOBA    CURUSER(&USRPRF)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO
             IF         COND(&USRPRF *EQ ' ') THEN(RTVJOBA CURUSER(&USRPRF))

             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

/* --- Language recorded for this library, if any (TXLEGLNG). *SAME      */
/* resolves to it, or to *RPG when the data area does not exist yet. --- */
             CHGVAR     VAR(&CURLANG) VALUE(' ')
             RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&CURLANG)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&CURLANG) +
                          VALUE(' '))
             IF         COND(&LANGU *EQ '*SAME') THEN(DO)
                IF         COND(&CURLANG *EQ ' ') THEN(CHGVAR VAR(&LANGU) +
                             VALUE('*RPG'))
                ELSE       CMD(CHGVAR VAR(&LANGU) VALUE(&CURLANG))
             ENDDO

/* --- Has this library already been loaded? (state data area TXLEGST) --- */
             CHKOBJ     OBJ(&LIB/TXLEGST) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(BUILD))
             IF         COND(&FORCE *NE '*YES') THEN(DO)
                SNDPGMMSG  MSG('TXLEGACY: already loaded in this library. +
                             Use FORCE(*YES) to rebuild (backs up first).')
                IF         COND(&CURLANG *NE ' ' *AND &CURLANG *NE +
                             &LANGU) THEN(SNDPGMMSG MSG('TXLEGACY: note - +
                             the loaded language is ' *CAT &CURLANG *CAT +
                             ', not ' *CAT &LANGU *CAT '. Nothing was +
                             changed; use FORCE(*YES) to switch.'))
                GOTO       CMDLBL(TXEND)
             ENDDO

/* --- FORCE(*YES) rerun: back up to a dated SAVF in <profile>B first --- */
             CHGVAR     VAR(&LIBB) VALUE(%TRIM(&USRPRF) *TCAT 'B')
             RTVSYSVAL  SYSVAL(QDATE) RTNVAR(&DATE)
             CHGVAR     VAR(&SAVF) VALUE('LG' *TCAT &DATE)
             CHKOBJ     OBJ(&LIBB/&SAVF) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSAVF FILE(&LIBB/&SAVF) +
                          TEXT('TXLEGACY pre-rebuild backup'))
             SAVOBJ     OBJ(TK0100 TK0100D JU0300 ZA0500 MN0000C MN0000D +
                          FLDREF FLDREFR) LIB(&LIB) DEV(*SAVF) +
                          SAVF(&LIBB/&SAVF) OBJTYPE(*ALL)
             MONMSG     MSGID(CPF0000)
             SNDPGMMSG  MSG('TXLEGACY: backed up existing legacy objects to +
                          ' *CAT %TRIM(&LIBB) *CAT '/' *CAT &SAVF)

BUILD:       SNDPGMMSG  MSG('TXLEGACY: loading legacy system into library ' +
                          *CAT &LIB *CAT ' ...')

/* --- Create source files if they do not exist yet (defensive: normally  */
/* already created by 01-06/TXSETUP, but TXLEGACY may run standalone). --- */
             CHKOBJ     OBJ(&LIB/QDDSSRC) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF FILE(&LIB/QDDSSRC) +
                          RCDLEN(92) TEXT('Curriculum DDS sources'))
             CHKOBJ     OBJ(&LIB/QRPGSRC) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF FILE(&LIB/QRPGSRC) +
                          RCDLEN(92) TEXT('Curriculum RPG III sources'))
             CHKOBJ     OBJ(&LIB/QCLSRC) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF FILE(&LIB/QCLSRC) +
                          RCDLEN(92) TEXT('Curriculum CL sources'))
             IF         COND(&LANGU *EQ '*RPGLE') THEN(DO)
                CHKOBJ     OBJ(&LIB/QRPGLE112) OBJTYPE(*FILE)
                MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF +
                             FILE(&LIB/QRPGLE112) RCDLEN(112) +
                             TEXT('Curriculum RPG IV (fixed form) sources'))
             ENDDO

/* --- DDS reference file first (no other legacy object depends on it to  */
/* compile, but it documents the shared field layout). --- */
             CHGVAR     VAR(&P1) VALUE('FLDREF')
             CHGVAR     VAR(&P1LC) VALUE('fldref')
             CHGVAR     VAR(&P2) VALUE('Shared field reference')
             CALLSUBR   SUBR(LOADPF)

/* --- RPG III /COPY member (no compile of its own; just needs to land in */
/* QRPGSRC before anything that /COPYs it, none of which TXLEGACY builds  */
/* yet - ZA0510 is a follow-up, see docs/probes.md TODO). --- */
             IF         COND(&LANGU *EQ '*RPG') THEN(DO)
                CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                             '/src/legacy/qrpgsrc/fldrefr.rpg')
                ADDPFM     FILE(&LIB/QRPGSRC) MBR(FLDREFR) SRCTYPE(RPG) +
                             TEXT('Shared field definitions (/COPY member)')
                MONMSG     MSGID(CPF7306)
                CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT +
                             %TRIM(&LIB) *TCAT +
                             '.LIB/QRPGSRC.FILE/FLDREFR.MBR')
                CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                             STMFCCSID(1208)
             ENDDO

/* --- Display files (compile before the RPG programs that use them, so   */
/* CRTRPGPGM can resolve the external record formats). --- */
             CHGVAR     VAR(&P1) VALUE('TK0100D')
             CHGVAR     VAR(&P1LC) VALUE('tk0100d')
             CHGVAR     VAR(&P2) VALUE('Customer inquiry display')
             CALLSUBR   SUBR(LOADDSPF)
             CHGVAR     VAR(&P1) VALUE('MN0000D')
             CHGVAR     VAR(&P1LC) VALUE('mn0000d')
             CHGVAR     VAR(&P2) VALUE('Legacy menu display')
             CALLSUBR   SUBR(LOADDSPF)

/* --- RPG III programs. --- */
             CHGVAR     VAR(&P1) VALUE('TK0100')
             CHGVAR     VAR(&P1LC) VALUE('tk0100')
             CHGVAR     VAR(&P2) VALUE('Customer inquiry')
             IF         COND(&LANGU *EQ '*RPGLE') THEN(CALLSUBR +
                          SUBR(LOADRPGLE))
             ELSE       CMD(CALLSUBR SUBR(LOADRPG))
             CHGVAR     VAR(&P1) VALUE('JU0300')
             CHGVAR     VAR(&P1LC) VALUE('ju0300')
             CHGVAR     VAR(&P2) VALUE('Order list by customer')
             IF         COND(&LANGU *EQ '*RPGLE') THEN(CALLSUBR +
                          SUBR(LOADRPGLE))
             ELSE       CMD(CALLSUBR SUBR(LOADRPG))
             CHGVAR     VAR(&P1) VALUE('ZA0500')
             CHGVAR     VAR(&P1LC) VALUE('za0500')
             CHGVAR     VAR(&P2) VALUE('Stock allocation')
             IF         COND(&LANGU *EQ '*RPGLE') THEN(CALLSUBR +
                          SUBR(LOADRPGLE))
             ELSE       CMD(CALLSUBR SUBR(LOADRPG))

/* --- CL programs (JU0900C calls ZA0500 by a library-qualified name, so   */
/* compile order relative to ZA0500 does not matter, but load it after    */
/* the RPG programs anyway for a predictable log). --- */
             CHGVAR     VAR(&P1) VALUE('JU0900C')
             CHGVAR     VAR(&P1LC) VALUE('ju0900c')
             CHGVAR     VAR(&P2) VALUE('Run stock allocation for orders')
             CALLSUBR   SUBR(LOADCLP)
             CHGVAR     VAR(&P1) VALUE('MN0000C')
             CHGVAR     VAR(&P1LC) VALUE('mn0000c')
             CHGVAR     VAR(&P2) VALUE('Legacy menu')
             CALLSUBR   SUBR(LOADCLP)

/* --- Record the language in TXLEGLNG (CHAR 7). --- */
             CHKOBJ     OBJ(&LIB/TXLEGLNG) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(CRTDTAARA +
                          DTAARA(&LIB/TXLEGLNG) TYPE(*CHAR) LEN(7) +
                          VALUE(' ') TEXT('Legacy system source language'))
             CHGDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) VALUE(&LANGU)

/* --- Create the TXLEGST marker data area --- */
             CHKOBJ     OBJ(&LIB/TXLEGST) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(CRTDTAARA DTAARA(&LIB/TXLEGST) +
                          TYPE(*CHAR) LEN(1) VALUE('Y') TEXT('Legacy system +
                          loaded flag'))
             MONMSG     MSGID(CPF0000) EXEC(CHGDTAARA DTAARA(&LIB/TXLEGST) +
                          VALUE('Y'))

             SNDPGMMSG  MSG('TXLEGACY: done. TXCHECK (05-13) can later +
                          confirm these objects still exist.')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXLEGACY: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)
             GOTO       CMDLBL(TXEND)

/* ==================== Subroutines ==================== */
/* Use &P1 (member/object name), &P1LC (matching lowercase repo file      */
/* name, set by the caller), &P2 (description). No return value.          */
SUBR       SUBR(LOADPF)
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qddssrc/' *TCAT %TRIM(&P1LC) *TCAT +
                          '.pf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(&P1) SRCTYPE(PF) TEXT(&P2)
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CHKOBJ     OBJ(&LIB/&P1) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTPF FILE(&LIB/&P1) +
                          SRCFILE(&LIB/QDDSSRC) SRCMBR(&P1) TEXT(&P2))
ENDSUBR

SUBR       SUBR(LOADDSPF)
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qddssrc/' *TCAT %TRIM(&P1LC) *TCAT +
                          '.dspf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(&P1) SRCTYPE(DSPF) TEXT(&P2)
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CRTDSPF    FILE(&LIB/&P1) SRCFILE(&LIB/QDDSSRC) SRCMBR(&P1) +
                          TEXT(&P2) REPLACE(*YES)
ENDSUBR

SUBR       SUBR(LOADRPG)
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qrpgsrc/' *TCAT %TRIM(&P1LC) *TCAT +
                          '.rpg')
             ADDPFM     FILE(&LIB/QRPGSRC) MBR(&P1) SRCTYPE(RPG) TEXT(&P2)
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QRPGSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CRTRPGPGM  PGM(&LIB/&P1) SRCFILE(&LIB/QRPGSRC) SRCMBR(&P1) +
                          TEXT(&P2) REPLACE(*YES)
ENDSUBR

SUBR       SUBR(LOADRPGLE)
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qrpgle112/' *TCAT %TRIM(&P1LC) *TCAT +
                          '.rpgle')
             ADDPFM     FILE(&LIB/QRPGLE112) MBR(&P1) SRCTYPE(RPGLE) +
                          TEXT(&P2)
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QRPGLE112.FILE/' *TCAT %TRIM(&P1) +
                          *TCAT '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CRTBNDRPG  PGM(&LIB/&P1) SRCFILE(&LIB/QRPGLE112) SRCMBR(&P1) +
                          TEXT(&P2) REPLACE(*YES)
ENDSUBR

SUBR       SUBR(LOADCLP)
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT +
                          '/src/legacy/qclsrc/' *TCAT %TRIM(&P1LC) *TCAT +
                          '.clp')
             ADDPFM     FILE(&LIB/QCLSRC) MBR(&P1) SRCTYPE(CLP) TEXT(&P2)
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QCLSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CRTCLPGM   PGM(&LIB/&P1) SRCFILE(&LIB/QCLSRC) SRCMBR(&P1) +
                          TEXT(&P2) REPLACE(*YES)
ENDSUBR

TXEND:       ENDPGM
