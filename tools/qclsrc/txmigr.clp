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
/* CONFIRMED (part05-legacy-probe, 2026-09-26, real DSPDBR/DSPOBJD        */
/* OUTFILE dump against JUCHUM/JUCHUL1 on PUB400 - see docs/probes.md):   */
/* DSPOBJD's ODOBNM/ODOBAT were already right. DSPDBR's were not - there  */
/* is no WHFILE/WHLIB field at all. The base file DSPDBR was run against  */
/* (JUCHUM itself) comes back as WHRFI/WHRLI, repeated on every row; the  */
/* actual DEPENDENT logical file (what this tool needs) is WHREFI/WHRELI. */
/* Confirmed dependent-row values for JUCHUL1 over JUCHUM: WHRTYP='P'     */
/* (base file type: physical), WHREFI='JUCHUL1', WHRELI=&LIB, WHTYPE='D'  */
/* (dependent type: data, i.e. an ordinary keyed logical file - as        */
/* opposed to an SQL view or index, neither of which this teaching        */
/* library has yet).                                                      */
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
             /* &D_WHREFI/&D_WHRELI (DSPDBR outfile) and &P_ODOBNM/         */
             /* &P_ODOBAT (DSPOBJD outfile) are NOT declared here on        */
             /* purpose: each DCLF below auto-declares its own outfile's    */
             /* fields, PREFIXED with its own OPNID() value and an          */
             /* underscore - declaring these names here too would be a      */
             /* duplicate-name compile error.                               */
             /*                                                            */
             /* REDESIGNED (2026-09-27, real-hardware finding from          */
             /* verify/part05-txmigr-to2b): the previous design DCLF'd      */
             /* QTEMP/TXMDBR and QTEMP/TXMPGM directly - files that only    */
             /* exist at RUN time, created by this same program's own       */
             /* DSPDBR/DSPOBJD OUTFILE steps further down. A deliberately   */
             /* unprimed CRTCLPGM attempt (verify/part05-txmigr-to2b's own  */
             /* CPTXMIGRRW step) confirmed this genuinely fails to compile  */
             /* in a job where those QTEMP files do not already exist       */
             /* ("Program TXMIGR not created" / CPF0801, no compile listing */
             /* at all). This means a real learner following 05-09/05-12   */
             /* as written could never compile TXMIGR at all, since        */
             /* nothing creates QTEMP/TXMDBR or QTEMP/TXMPGM ahead of time  */
             /* for them either.                                            */
             /*                                                            */
             /* FIX, part 1: DCLF against the IBM-supplied MODEL outfiles   */
             /* for DSPDBR/DSPOBJD instead - QSYS/QADSPDBR (format          */
             /* QWHDRDBR) and QSYS/QADSPOBJ (format QLIDOBJD) - which       */
             /* always exist, so the compile no longer depends on this      */
             /* program's own QTEMP files existing yet (WebSearch,          */
             /* 2026-09-27: IBM Knowledge Center/setgetweb.com DSPDBR and   */
             /* DSPOBJD command descriptions both name their model outfile  */
             /* and format this way; not independently fetched as a full    */
             /* primary-source page in this repo, since the pages found     */
             /* were not directly fetchable - flagged as a secondary-source */
             /* citation, not a first-party one). CONFIRMED (2026-09-27,    */
             /* real CRTCLPGM against verify/part05-txmigr-compile-check):  */
             /* QADSPDBR's real format is exactly QWHDRDBR, auto-declaring  */
             /* WHRTYP/WHRFI/WHRLI/WHRMB/WHRRD/WHNO/WHDTM/WHREFI/WHRELI/     */
             /* WHREMB/WHTYPE/WHJDIL/WHJREF/WHSYSN/WHCTLN/WHCSTN - matching */
             /* the WHREFI/WHRELI/WHRTYP/WHTYPE names already confirmed     */
             /* against real hardware above (part05-legacy-probe's DSPDBR   */
             /* dump). ODOBNM/ODOBAT (QADSPOBJ/QLIDOBJD) match what         */
             /* verify/part05-txmigr-to2b's own successful RECOMPILE loop    */
             /* already exercised - both DSPDBR/DSPOBJD default to exactly  */
             /* these formats when no OUTFILEFMT is given.                  */
             /*                                                            */
             /* FIX, part 2 (found by the SAME real CRTCLPGM attempt just   */
             /* cited - the first attempt at this redesign used OPNID       */
             /* (*NONE), the default, on BOTH DCLF statements and failed:    */
             /* CPD0303 "DCLF with OPNID parameter *NONE declared           */
             /* previously" - *NONE can be used for AT MOST ONE DCLF'd file  */
             /* in the whole program, exactly the same "only one file may   */
             /* go unnamed" rule that already made a bare RCVF (no OPNID())  */
             /* invalid here before this redesign, now confirmed to apply    */
             /* to DCLF's own OPNID() too): reverted to explicit, distinct   */
             /* OPNID(D)/OPNID(P) on both DCLF statements (short single      */
             /* letters, sidestepping the still-open CL-variable-name-       */
             /* length question - see the RCVF/CRTLF/RECOMPILE code below), */
             /* which is why the field names carry the &D_/&P_ prefix.      */
             /*                                                            */
             /* At RUN time, OVRDBF redirects each model file (referenced   */
             /* by FILE NAME, not by its OPNID value) to this program's own */
             /* real QTEMP/TXMDBR or QTEMP/TXMPGM (created moments earlier   */
             /* by this same program's own DSPDBR/DSPOBJD OUTFILE step)     */
             /* before the first RCVF against it - see Step 2/Step 3 below. */
             DCLF       FILE(QSYS/QADSPDBR) OPNID(D)
             DCLF       FILE(QSYS/QADSPOBJ) OPNID(P)

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
                             D_WHREFI/D_WHRELI field names in this +
                             program against a real OUTFILE dump.')
                GOTO       CMDLBL(RECOMPILE)
             ENDDO
             /* Redirect the model file this program actually DCLF'd       */
             /* (QADSPDBR, referenced here by its FILE NAME - OPNID(D) is   */
             /* a separate, unrelated identifier used only by RCVF below)   */
             /* to the real outfile DSPDBR just built, so RCVF below reads  */
             /* OUR data, not QADSPDBR itself (which DSPDBR never touches). */
             /* SHARE(*NO): this program has not opened either file yet     */
             /* (DCLF alone does not open it).                              */
             OVRDBF     FILE(QADSPDBR) TOFILE(QTEMP/TXMDBR) SHARE(*NO)

/* No DLTF before CRTLF here, on purpose: CRTPF/CRTLF have no REPLACE      */
/* parameter (confirmed: neither is in the "has REPLACE" group with       */
/* CRTDSPF/CRTPRTF/CRT*PGM), so CRTLF alone, without a preceding delete,   */
/* is the safe choice: it either recreates a genuinely missing/stale LF,  */
/* or fails harmlessly under its own trailing MONMSG (object-already-     */
/* exists) - never deletes anything. (WHREFI is confirmed to always name  */
/* the dependent logical file, never JUCHUM itself - see header comment - */
/* so the wrong-object-type risk this comment used to flag no longer     */
/* applies. Its DCLF-generated variable name is &D_WHREFI, per OPNID(D).)  */
NEXTDBR:     RCVF       OPNID(D)
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(DLTOVRDBR))
             IF         COND(&D_WHRELI *NE &LIB) THEN(GOTO CMDLBL(NEXTDBR))
             CRTLF      FILE(&LIB/&D_WHREFI) SRCFILE(&LIB/QDDSSRC) +
                          SRCMBR(&D_WHREFI)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: could +
                          not recreate ' *CAT %TRIM(&D_WHREFI) *CAT '.'))
             GOTO       CMDLBL(NEXTDBR)

DLTOVRDBR:   DLTOVR     FILE(QADSPDBR)
             MONMSG     MSGID(CPF0000)

/* --- Step 3: recompile every *PGM in the library (see header comment). */
RECOMPILE:   DSPOBJD    OBJ(&LIB/*ALL) OBJTYPE(*PGM) OUTPUT(*OUTFILE) +
                          OUTFILE(QTEMP/TXMPGM)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXMIGR: DSPOBJD failed - check the +
                             P_ODOBNM/P_ODOBAT field names in this +
                             program against a real OUTFILE dump.')
                GOTO       CMDLBL(TXDONE)
             ENDDO
             OVRDBF     FILE(QADSPOBJ) TOFILE(QTEMP/TXMPGM) SHARE(*NO)

NEXTPGM:     RCVF       OPNID(P)
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(DLTOVROBJ))
             IF         COND(&P_ODOBAT *EQ 'RPG') THEN(DO)
                CRTRPGPGM  PGM(&LIB/&P_ODOBNM) SRCFILE(&LIB/QRPGSRC) +
                             SRCMBR(&P_ODOBNM) REPLACE(*YES)
                MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: +
                             could not recompile ' *CAT %TRIM(&P_ODOBNM) +
                             *CAT ' (RPG).'))
             ENDDO
             IF         COND(&P_ODOBAT *EQ 'CLP') THEN(DO)
                CRTCLPGM   PGM(&LIB/&P_ODOBNM) SRCFILE(&LIB/QCLSRC) +
                             SRCMBR(&P_ODOBNM) REPLACE(*YES)
                MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: +
                             could not recompile ' *CAT %TRIM(&P_ODOBNM) +
                             *CAT ' (CLP).'))
             ENDDO
             GOTO       CMDLBL(NEXTPGM)

DLTOVROBJ:   DLTOVR     FILE(QADSPOBJ)
             MONMSG     MSGID(CPF0000)

TXDONE:      CHGVAR     VAR(&DBVERC) VALUE(&TO)
             SNDPGMMSG  MSG('TXMIGR: done. DBVER=' *CAT %TRIM(&DBVERC) +
                          *CAT '. Run TXSTATUS to check; update TXSTATE +
                          by hand if this tool did not.')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXMIGR: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
