/* TXSETUP - build the sample database (customers, products, orders,      */
/*           order lines, stock, sales reps) in one library (DBVER=1).    */
/*                                                                        */
/* Prerequisite: this repo has been git-cloned (sparse) into ~/ibmi-kyozai */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB      target library. Default *CURLIB.                           */
/*   CLONEDIR absolute path of the git clone. Default: your home         */
/*            directory + /ibmi-kyozai (computed from your profile).     */
/*   FORCE    *YES rebuilds even if already initialized.                 */
             PGM        PARM(&LIB &CLONEDIR &FORCE)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it (blank/omitted if not passed). Defaults are   */
             /* filled in below.                                         */
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)

             /* CALLSUBR cannot pass arguments (a subroutine shares the   */
             /* caller's variables), so &P1 (object name) and &P2        */
             /* (description) are set before each call.                  */
             DCL        VAR(&P1) TYPE(*CHAR) LEN(10)
             DCL        VAR(&P1LC) TYPE(*CHAR) LEN(10)
             DCL        VAR(&P2) TYPE(*CHAR) LEN(50)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(200)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(200)

/* --- Fill in defaults for omitted/blank parameters --- */
             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&FORCE *EQ ' ') THEN(CHGVAR VAR(&FORCE) +
                          VALUE('*NO'))

/* --- Build the default CLONEDIR (your home directory + /ibmi-kyozai) --- */
             IF         COND(&CLONEDIR *EQ ' ') THEN(DO)
                RTVJOBA    USER(&USRPRF)
                CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                             *TCAT '/ibmi-kyozai')
                CHGVAR     VAR(&CLONEDIR) VALUE(&HOMEDIR)
             ENDDO

/* --- *CURLIB is only valid as a qualifier on object references; some    */
/* commands below (ADDLIBLE, RUNSQLSTM DFTRDBCOL) need the real name.     */
             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

/* --- Has this library already been set up? (state data area TXSTATE) --- */
             CHKOBJ     OBJ(&LIB/TXSTATE) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(BUILD))
             IF         COND(&FORCE *NE '*YES') THEN(DO)
                SNDPGMMSG  MSG('TXSETUP: already initialized in this library. +
                             Use FORCE(*YES) to rebuild.')
                GOTO       CMDLBL(TXEND)
             ENDDO

BUILD:       SNDPGMMSG  MSG('TXSETUP: building sample database in library ' +
                          *CAT &LIB *CAT ' ...')

/* --- Create source file QDDSSRC if it does not exist yet --- */
             CHKOBJ     OBJ(&LIB/QDDSSRC) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTSRCPF FILE(&LIB/QDDSSRC) +
                          RCDLEN(92) TEXT('Curriculum DDS sources'))

/* --- Physical files first (logical files depend on them) --- */
             CHGVAR     VAR(&P1) VALUE('TOKUIM')
             CHGVAR     VAR(&P2) VALUE('Customer master')
             CALLSUBR   SUBR(LOADPF)
             CHGVAR     VAR(&P1) VALUE('SHOHIM')
             CHGVAR     VAR(&P2) VALUE('Product master')
             CALLSUBR   SUBR(LOADPF)
             CHGVAR     VAR(&P1) VALUE('JUCHUM')
             CHGVAR     VAR(&P2) VALUE('Order master')
             CALLSUBR   SUBR(LOADPF)
             CHGVAR     VAR(&P1) VALUE('JUCHUD')
             CHGVAR     VAR(&P2) VALUE('Order detail')
             CALLSUBR   SUBR(LOADPF)
             CHGVAR     VAR(&P1) VALUE('ZAIKOM')
             CHGVAR     VAR(&P2) VALUE('Stock master')
             CALLSUBR   SUBR(LOADPF)
             CHGVAR     VAR(&P1) VALUE('TANTOM')
             CHGVAR     VAR(&P2) VALUE('Sales rep master')
             CALLSUBR   SUBR(LOADPF)

/* --- Logical files. PFILE() in the LF's DDS has no library name (the   */
/* DDS is shared, deployed source), so it resolves through *LIBL. Add    */
/* the target library to the top of the library list first.             */
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             CHGVAR     VAR(&P1) VALUE('JUCHUL1')
             CHGVAR     VAR(&P2) VALUE('Order by customer/date')
             CALLSUBR   SUBR(LOADLF)
             CHGVAR     VAR(&P1) VALUE('TOKUIL1')
             CHGVAR     VAR(&P2) VALUE('Customer by name')
             CALLSUBR   SUBR(LOADLF)

/* --- Initial data --- */
             RUNSQLSTM  SRCSTMF(&CLONEDIR *TCAT '/db/data/load_v1.sql') +
                          COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(&LIB)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXSETUP: loading initial data failed. See +
                             the job log for details.') MSGTYPE(*ESCAPE)
             ENDDO

/* --- Create the DBVER state data area (DBVER=1) --- */
             CHKOBJ     OBJ(&LIB/TXSTATE) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(CRTDTAARA DTAARA(&LIB/TXSTATE) +
                          TYPE(*DEC) LEN(3 0) VALUE(1) TEXT('Curriculum DB +
                          version'))
             MONMSG     MSGID(CPF0000) EXEC(CHGDTAARA DTAARA(&LIB/TXSTATE) +
                          VALUE(1))

             SNDPGMMSG  MSG('TXSETUP: done. DBVER=1. Run TXSTATUS to check.')
             GOTO       CMDLBL(TXEND)

/* ==================== Subroutines ==================== */
/* Use &P1 (object name = member name) and &P2 (description). No return. */
SUBR       SUBR(LOADPF)
             CHGVAR     VAR(&P1LC) VALUE(%TRIM(&P1))
             CHGVAR     VAR(&P1LC) VALUE(%LOWER(&P1LC))
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT '/db/v1/' *TCAT +
                          %TRIM(&P1LC) *TCAT '.pf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(&P1) SRCTYPE(PF) TEXT(&P2)
             MONMSG     MSGID(CPF7302)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             /* Do not overwrite a file the learner may already have built  */
             /* by hand (02-02). Only create it if it is not there yet.     */
             CHKOBJ     OBJ(&LIB/&P1) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTPF FILE(&LIB/&P1) +
                          SRCFILE(&LIB/QDDSSRC) SRCMBR(&P1) TEXT(&P2))
ENDSUBR

SUBR       SUBR(LOADLF)
             CHGVAR     VAR(&P1LC) VALUE(%TRIM(&P1))
             CHGVAR     VAR(&P1LC) VALUE(%LOWER(&P1LC))
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT '/db/v1/' *TCAT +
                          %TRIM(&P1LC) *TCAT '.lf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(&P1) SRCTYPE(LF) TEXT(&P2)
             MONMSG     MSGID(CPF7302)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/' *TCAT %TRIM(&P1) *TCAT +
                          '.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             CHKOBJ     OBJ(&LIB/&P1) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(CRTLF FILE(&LIB/&P1) +
                          SRCFILE(&LIB/QDDSSRC) SRCMBR(&P1) TEXT(&P2))
ENDSUBR

TXEND:       ENDPGM
