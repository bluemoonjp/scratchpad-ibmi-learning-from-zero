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
             /* underscore (CONFIRMED, ibm.com/docs/api/v1/content/         */
             /* ssw_ibm_i_75/cl/dclf.htm, fetched 2026-09-27 for verify/     */
             /* part05-txmigr-to2b: "If the OPNID parameter value is not    */
             /* *NONE, the variable name is the field name prefixed with    */
             /* an ampersand (&), the value specified for the OPNID         */
             /* parameter, and an underscore." - declaring these names      */
             /* here too would be a duplicate-name compile error.           */
             /*                                                            */
             /* OPNID is D/P (single letter), not TXMDBR/TXMPGM (this       */
             /* file's own QTEMP file names). Ordinary CL variable names    */
             /* declared by DCL are commonly said to be capped at 11        */
             /* characters including the ampersand (WebSearch, 2026-09-27,  */
             /* citing '&NBRDLTPGMMSG is invalid because it is too long')   */
             /* - but the dclf.htm page fetched just above gives ITS OWN    */
             /* example as '&FILE1_CUSTNAME' (14 characters after &),       */
             /* which contradicts a flat 10-after-& reading if that same    */
             /* limit applies to OPNID-generated names. This is NOT settled */
             /* either way by anything this repo has fetched or holds as a  */
             /* primary source - it is left as an open question, not        */
             /* asserted as confirmed. D/P are used anyway, as the          */
             /* conservative choice that sidesteps the question entirely:   */
             /* &D_WHRELI/&D_WHREFI/&P_ODOBNM/&P_ODOBAT (8 characters       */
             /* after &) are short enough to be legal under EITHER          */
             /* reading, so this choice costs nothing regardless of which    */
             /* interpretation turns out to be right. The single-letter     */
             /* OPNID choice is unrelated to the FILE(QTEMP/TXMDBR)/        */
             /* FILE(QTEMP/TXMPGM) qualifiers just below, which are         */
             /* untouched: OPNID only affects RCVF/field-variable naming,   */
             /* never the file name itself.                                */

             /* FIXED (2026-09-27, found by static review before a real   */
             /* connection, ahead of the 2F TXMIGR manifest): both DCLF    */
             /* statements below used to sit right before their first use  */
             /* (Step 2/Step 3 further down, after several executable      */
             /* statements) - OPM CL requires every DCL/DCLF to precede all */
             /* executable statements in the program, so the compile would */
             /* have failed outright (this is the same rule already        */
             /* relied on above: &D_WHREFI/&D_WHRELI/&P_ODOBNM/&P_ODOBAT    */
             /* can only be used because DCLF runs before they are read).   */
             /* Moved both here, into the declare section.                  */
             /* UNVERIFIED risk this reorder does not resolve: DCLF must   */
             /* also find the named file at COMPILE time to read its       */
             /* record format, but QTEMP/TXMDBR and QTEMP/TXMPGM are only  */
             /* created at RUN time, by the DSPDBR/DSPOBJD OUTFILE steps    */
             /* further down in this same program - whether CRTCLPGM can   */
             /* compile this at all (in a job where those QTEMP files do   */
             /* not yet exist) is not something a source reading can       */
             /* settle; needs an actual CRTCLPGM attempt to confirm or      */
             /* refute. verify/part05-txmigr-to2 works around this by      */
             /* priming both QTEMP files (via a throwaway DSPDBR/DSPOBJD   */
             /* OUTFILE run against an object that already exists) before  */
             /* CRTCLPGM'ing this program in the SAME job - but also runs  */
             /* one totally unprimed CRTCLPGM attempt first, specifically  */
             /* to observe whether a real learner's fresh job (no such     */
             /* priming) can compile this at all; see that manifest's own  */
             /* description for the result.                                */
             /*                                                            */
             /* FIXED (2026-09-27, verify/part05-txmigr-to2 design, static  */
             /* review): added explicit OPNID() to both DCLF statements     */
             /* below and to both RCVF statements further down. This repo's */
             /* own work/design/refs/cl_commands_75.txt has no DCLF/RCVF    */
             /* page at all (confirmed by grep - genuinely absent, not      */
             /* just unread), so this was NOT settled against a primary    */
             /* source in this repo when first written; it followed        */
             /* long-standing general CL knowledge instead (a bare RCVF     */
             /* with no OPNID() is only valid when exactly one file is      */
             /* DCLF'd in the whole program - with two, as here, RCVF       */
             /* must say which one).                                        */
             /*                                                            */
             /* CONFIRMED (2026-09-27, second static review for verify/     */
             /* part05-txmigr-to2b, WebFetch of ibm.com/docs/api/v1/        */
             /* content/ssw_ibm_i_75/cl/dclf.htm): giving OPNID() a real    */
             /* value (not *NONE) does NOT just label the open instance -   */
             /* it RENAMES every field variable DCLF auto-declares for      */
             /* that file, prefixing each with the OPNID value and an       */
             /* underscore ("If the OPNID parameter value is not *NONE,     */
             /* the variable name is the field name prefixed with an       */
             /* ampersand (&), the value specified for the OPNID            */
             /* parameter, and an underscore."). The EARLIER static review   */
             /* above (still-genuinely-unconfirmed-on-real-hardware, as     */
             /* this same paragraph used to say) had missed this: it        */
             /* originally used OPNID(TXMDBR)/OPNID(TXMPGM), and then       */
             /* used the OLD, unqualified field names (&WHRELI/&WHREFI/     */
             /* &ODOBNM/&ODOBAT) everywhere below - once OPNID(TXMDBR) is    */
             /* in force those old names are simply UNDECLARED (DCLF only   */
             /* declares the PREFIXED forms), so that version would have    */
             /* failed to compile on undeclared-variable errors regardless   */
             /* of any length question. Switched to single-letter           */
             /* OPNID(D)/OPNID(P), and every use of WHRELI/WHREFI/ODOBNM/    */
             /* ODOBAT below now carries that short prefix (&D_WHRELI/       */
             /* &D_WHREFI/&P_ODOBNM/&P_ODOBAT) - this resolves the          */
             /* undeclared-name problem regardless of the separate,          */
             /* still-open variable-name-length question the DCL section     */
             /* comment above discusses. Still not exercised by an actual    */
             /* CRTCLPGM on real hardware.                                   */
             DCLF       FILE(QTEMP/TXMDBR) OPNID(D)
             DCLF       FILE(QTEMP/TXMPGM) OPNID(P)

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

/* No DLTF before CRTLF here, on purpose: CRTPF/CRTLF have no REPLACE      */
/* parameter (confirmed: neither is in the "has REPLACE" group with       */
/* CRTDSPF/CRTPRTF/CRT*PGM), so CRTLF alone, without a preceding delete,   */
/* is the safe choice: it either recreates a genuinely missing/stale LF,  */
/* or fails harmlessly under its own trailing MONMSG (object-already-     */
/* exists) - never deletes anything. (WHREFI is confirmed to always name  */
/* the dependent logical file, never JUCHUM itself - see header comment - */
/* so the wrong-object-type risk this comment used to flag no longer     */
/* applies. Its DCLF-generated variable name is &D_WHREFI, per the OPNID-  */
/* prefixing rule confirmed just above - OPNID(D), not OPNID(TXMDBR),      */
/* to stay under the CL variable-name-length limit.)                       */
NEXTDBR:     RCVF       OPNID(D)
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(RECOMPILE))
             IF         COND(&D_WHRELI *NE &LIB) THEN(GOTO CMDLBL(NEXTDBR))
             CRTLF      FILE(&LIB/&D_WHREFI) SRCFILE(&LIB/QDDSSRC) +
                          SRCMBR(&D_WHREFI)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TXMIGR: could +
                          not recreate ' *CAT %TRIM(&D_WHREFI) *CAT '.'))
             GOTO       CMDLBL(NEXTDBR)

/* --- Step 3: recompile every *PGM in the library (see header comment). */
RECOMPILE:   DSPOBJD    OBJ(&LIB/*ALL) OBJTYPE(*PGM) OUTPUT(*OUTFILE) +
                          OUTFILE(QTEMP/TXMPGM)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXMIGR: DSPOBJD failed - check the +
                             P_ODOBNM/P_ODOBAT field names in this +
                             program against a real OUTFILE dump.')
                GOTO       CMDLBL(TXDONE)
             ENDDO

NEXTPGM:     RCVF       OPNID(P)
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(TXDONE))
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

TXDONE:      CHGVAR     VAR(&DBVERC) VALUE(&TO)
             SNDPGMMSG  MSG('TXMIGR: done. DBVER=' *CAT %TRIM(&DBVERC) +
                          *CAT '. Run TXSTATUS to check; update TXSTATE +
                          by hand if this tool did not.')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXMIGR: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
