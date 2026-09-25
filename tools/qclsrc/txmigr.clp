/* TXMIGR - migrate the sample database to a newer DBVER and recompile    */
/*          whatever it affects, without holding a fixed list of which    */
/*          objects that is (05-09 CPF4131 exercise; review-triage B2-9). */
/*                                                                        */
/* Strategy (deliberately simple, to avoid depending on an *OUTFILE       */
/* format this repo has not confirmed yet - see the "unverified" notes    */
/* below): after recreating the changed physical file from its db/vN     */
/* source, TXMIGR (1) finds and recreates every logical file DSPDBR       */
/* reports as built over it, then (2) recompiles EVERY *PGM object in     */
/* the library whose source member still exists (a small teaching        */
/* library has only a handful of programs, so "recompile them all" is    */
/* cheap and always correct, unlike trying to pick out just the ones a    */
/* single DSPPGMREF/DSPDBR pass can prove depend on the changed file -    */
/* JUYAKC's CPYTOIMPF FROMFILE() reference, for example, is a literal CL  */
/* command parameter, not a compile-time bind, and DSPPGMREF may not      */
/* catch it at all; see work/design/part05-legacy-design.json            */
/* openQuestions). Object names themselves are never hardcoded here -     */
/* only the db/vN source path for the physical file, which the version    */
/* number necessarily fixes anyway.                                       */
/*                                                                        */
/* UNVERIFIED: the exact field names in DSPDBR's and DSPOBJD's            */
/* OUTPUT(*OUTFILE) formats below (WHFILE/WHLIB for DSPDBR, ODOBNM/       */
/* ODOBAT for DSPOBJD) are written from general IBM i documentation, not  */
/* a real OUTFILE dump taken on PUB400. Confirm both before relying on    */
/* this tool; if a field name is wrong, DCLF will fail to compile (safe   */
/* failure) rather than silently reading the wrong column.                */
/*                                                                        */
/* PARM:                                                                  */
/*   TO    target DBVER. Only 2 is implemented (db/v2/juchum.pf exists;   */
/*         add a db/v3 branch here once TO(3) sources exist).             */
/*   LIB   library to migrate. Default *CURLIB.                           */
/*   CLONEDIR absolute path of the git clone. Default: your home         */
/*            directory + /ibmi-kyozai (computed from your profile).     */
             PGM        PARM(&TO &LIB &CLONEDIR)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&TO) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)

             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(200)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&DBVERC) TYPE(*CHAR) LEN(10)
             /* &WHFILE/&WHLIB (DSPDBR outfile) and &ODOBNM/&ODOBAT        */
             /* (DSPOBJD outfile) are NOT declared here on purpose: each   */
             /* DCLF below auto-declares its own outfile's fields under    */
             /* those exact names, and declaring them twice would be a     */
             /* duplicate-name compile error.                              */

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

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

             IF         COND(&TO *NE 2) THEN(DO)
                SNDPGMMSG  MSG('TXMIGR: only TO(2) is implemented so far.')
                RETURN
             ENDDO

/* --- Step 1: recreate the changed physical file from its db/vN source. */
             CHGVAR     VAR(&SRC) VALUE(&CLONEDIR *TCAT '/db/v2/juchum.pf')
             ADDPFM     FILE(&LIB/QDDSSRC) MBR(JUCHUM) SRCTYPE(PF) +
                          TEXT('Order master (DBVER=2)')
             MONMSG     MSGID(CPF7306)
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QDDSSRC.FILE/JUCHUM.MBR')
             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             /* CHGPF, not CRTPF: CRTPF would create a brand new (empty)    */
             /* object. CHGPF changes the format in place and keeps the    */
             /* existing data member/rows - this is what actually causes   */
             /* the level-ID mismatch (CPF4131) in every program that has  */
             /* not been recompiled yet, which is the whole point of this  */
             /* exercise (05-09: CHGPF in <USER>2 to reproduce CPF4131).   */
             CHGPF      FILE(&LIB/JUCHUM) SRCFILE(&LIB/QDDSSRC) +
                          SRCMBR(JUCHUM)

/* --- Step 2: recreate every logical file DSPDBR reports over JUCHUM. -- */
             DSPDBR     FILE(&LIB/JUCHUM) OUTPUT(*OUTFILE) +
                          OUTFILE(QTEMP/TXMDBR)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXMIGR: DSPDBR failed - check the +
                             WHFILE/WHLIB field names in this program +
                             against a real OUTFILE dump.')
                GOTO       CMDLBL(RECOMPILE)
             ENDDO
             DCLF       FILE(QTEMP/TXMDBR)

NEXTDBR:     RCVF
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(RECOMPILE))
             IF         COND(&WHLIB *NE &LIB) THEN(GOTO CMDLBL(NEXTDBR))
             CRTLF      FILE(&LIB/&WHFILE) SRCFILE(&LIB/QDDSSRC) +
                          SRCMBR(&WHFILE) REPLACE(*YES)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: could +
                          not recreate ' *CAT %TRIM(&WHFILE) *CAT '.'))
             GOTO       CMDLBL(NEXTDBR)

/* --- Step 3: recompile every *PGM in the library (see header comment). */
RECOMPILE:   DSPOBJD    OBJ(&LIB/*ALL) OBJTYPE(*PGM) OUTPUT(*OUTFILE) +
                          OUTFILE(QTEMP/TXMPGM)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXMIGR: DSPOBJD failed - check the +
                             ODOBNM/ODOBAT field names in this program +
                             against a real OUTFILE dump.')
                GOTO       CMDLBL(TXDONE)
             ENDDO
             DCLF       FILE(QTEMP/TXMPGM)

NEXTPGM:     RCVF
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(TXDONE))
             IF         COND(&ODOBAT *EQ 'RPG') THEN(DO)
                CRTRPGPGM  PGM(&LIB/&ODOBNM) SRCFILE(&LIB/QRPGSRC) +
                             SRCMBR(&ODOBNM) REPLACE(*YES)
                MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: +
                             could not recompile ' *CAT %TRIM(&ODOBNM) +
                             *CAT ' (RPG).'))
             ENDDO
             IF         COND(&ODOBAT *EQ 'CLP') THEN(DO)
                CRTCLPGM   PGM(&LIB/&ODOBNM) SRCFILE(&LIB/QCLSRC) +
                             SRCMBR(&ODOBNM) REPLACE(*YES)
                MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: +
                             could not recompile ' *CAT %TRIM(&ODOBNM) +
                             *CAT ' (CLP).'))
             ENDDO
             GOTO       CMDLBL(NEXTPGM)

TXDONE:      CHGVAR     VAR(&DBVERC) VALUE(&TO)
             SNDPGMMSG  MSG('TXMIGR: done. DBVER=' *CAT %TRIM(&DBVERC) +
                          *CAT '. Run TXSTATUS to check; update TXSTATE +
                          by hand if this tool did not.')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXMIGR: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
