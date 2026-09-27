/* MN0000C - legacy system menu program. SNDRCVF reads the selected       */
/* option from MN0000D, writes it to *LDA (CHGDTAARA), then CALLs         */
/* the matching program. Legacy system (Part 5), lesson 05-06.            */
/*                                                                        */
/* SOURCE STATUS: NOT compiled on real hardware yet (this session ran     */
/* out of its SSH connection budget). Column layout and DCL/comment       */
/* style follow the machine-verified patterns in                          */
/* tools/qclsrc/txsetup.clp and src/legacy/qclsrc/ju0900c.clp; SNDRCVF    */
/* itself has no compiled precedent in this repo yet (closest analog      */
/* in docs/probes.md is 04-11 EXFMT/WORKSTN).                             */
/*                                                                        */
/* Every CALL below is library-qualified (CALL PGM(&LIB/xxx)) on purpose: */
/* an unqualified CALL run from a fresh job can search *LIBL and miss the */
/* target program object, which fails immediately with CPD0170 (program   */
/* not found) - not the RPG1216 hang documented for 04-06 in              */
/* docs/probes.md. That hang's real root cause was different: an          */
/* unqualified, IMPLICIT file reference (TOKUIM) inside the called RPG    */
/* program itself, resolved via *LIBL, failing to open - CPF4101, then    */
/* CPF9999, then the RPG-specific inquiry message RPG1216. RPG1216 is not */
/* a CPF-prefixed *ESCAPE, so the program-level MONMSG MSGID(CPF0000)     */
/* below does not catch it; an unanswered inquiry just hangs a            */
/* non-interactive job instead. Qualifying CALL only protects the         */
/* program-object lookup - it does nothing for TK0100's CHAIN against     */
/* TOKUIM/TANTOM, JU0300's primary read of JUCHUL1, or TK0100D's implicit */
/* open, which all still resolve unqualified via the job's real           */
/* *LIBL/*CURLIB at runtime. So this program also does ADDLIBLE LIB(&LIB) */
/* POSITION(*FIRST) below (same pattern as JU0900C's own internal         */
/* ADDLIBLE, and tools/qclsrc/txsetup.clp) before entering the MENU: loop */
/* - not just for the common case where LIB defaults to *CURLIB, but so a */
/* caller-supplied LIB() that differs from the job's actual current       */
/* library still resolves correctly too.                                  */
/*                                                                        */
/* CALL PGM(&LIB/JU0900C) passes &RUNMODE/&LIB matching its *ENTRY PLIST  */
/* PGM PARM(&RUNMODEP &LIB) (both CHAR 10). docs/probes.md records that   */
/* OPM CALL does not check parameter length/decimal agreement when the    */
/* parameter COUNT matches, and that calling a program without its        */
/* declared parameters risked CPD0172 - so this CALL always passes both,  */
/* correctly typed, rather than omitting them. TK0100/JU0300 have no      */
/* documented *ENTRY PLIST, so their CALLs below pass no PARM.            */
/*                                                                        */
/* DCLF FILE(MN0000D) declares this program record format MNUFMT          */
/* and its fields (src/legacy/qddssrc/mn0000d.dspf):                      */
/*   SELNO   1,0 numeric, usage B - the menu digit (&SELNO, *DEC).        */
/*   MSGTXT  40A, usage O - the message line (&MSGTXT, *CHAR 40).         */
/* CF03(03) on the same record also gives us &IN03 (*LGL) for free - DCLF */
/* declares one logical variable per response indicator used by a         */
/* CAxx/CFxx keyword in the file, no separate INDARA needed. F3 (&IN03)   */
/* is the only in-loop exit (see the MENU: loop below); MN0000D has no    */
/* numeric EXIT option and neither design.objects[6] nor [7] in           */
/* part05-legacy-design.json documents one.                               */
/*                                                                        */
/* Shared *LDA layout across this program and every program it CALLs      */
/* (directly - TK0100/JU0300/JU0900C - or, via JU0900C, indirectly -      */
/* ZA0500; checked by grepping src/ and tools/ for UDS/*LDA/              */
/* RTVDTAARA/CHGDTAARA, 2026-09-26): position 1 = the raw selection digit */
/* (&SELCHAR), written by this program only. Positions 2-10 are unused by */
/* anything in this design. Positions 11-16 = FTOK, an optional           */
/* customer-code filter that JU0300 auto-loads via its own I UDS (I-spec, */
/* option U) at program start; src/legacy/qrpgsrc/ju0300.rpg (design      */
/* deviation 4) places FTOK at 11-16, not 1-6, specifically so this       */
/* program's CHGDTAARA(*LDA (1 1)) below never touches it. Position 17 =  */
/* TK0100's external indicator U1 (RPG III's standard *LDA-loaded U1-U8   */
/* indicators, src/legacy/qrpgsrc/tk0100.rpg), also never written here.   */
/* ZA0500 has no UDS (its own header says so explicitly). This program    */
/* never writes 11-16 or 17, so FTOK stays blank and U1 stays off in a    */
/* fresh interactive job, and JU0300's C-specs (a COMP test against an    */
/* all-blank FTOK sets indicator 91) print every DTL line - there is no   */
/* collision among any of these programs' *LDA usage.                     */
/*                                                                        */
/* MN0000D deliberately avoids DDS conditioning indicators (04-11:        */
/* CPD7410/CPD7606/CPD5238, unresolved); instead this program             */
/* overwrites MSGTXT directly with CHGVAR before the next SNDRCVF -       */
/* the CL equivalent of the RPG MOVEL rewrite used for the same           */
/* reason in R0411A/TK0100D.                                              */
/*                                                                        */
/* *LDA is character, but SELNO is *DEC, so &SELNO is converted to        */
/* &SELCHAR (*CHAR 1) with CHGVAR before CHGDTAARA - CHGDTAARA            */
/* VALUE() on a *CHAR data area needs a character value, and CL's         */
/* own *DEC-to-*CHAR CHGVAR conversion is simple, well-established        */
/* behavior (right-justified digits, no separate call needed).            */
/*                                                                        */
/* SNDRCVF is interactive and cannot be exercised over SSH (non-          */
/* interactive batch) - same structural limit as TK0100D/EXFMT. Only      */
/* compile-time structure is checked here; a real 5250 session is         */
/* required to confirm the screen itself actually works (V3).             */
/*                                                                        */
/* Also note: a value written here with CHGDTAARA(*LDA) does NOT          */
/* survive across separate SSH "system()" calls (each is a fresh          */
/* job - see the TXSETUP section of docs/probes.md), so any               */
/* *LDA-based verification of the called programs must go through a       */
/* dedicated diagnostic CL wrapper in the same job, not through this      */
/* interactive menu.                                                      */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB   library to CALL the menu options from. Default                 */
/*         *CURLIB, resolved to a real library name below                 */
/*         (RTVJOBA). If RTVJOBA returns the special value *NONE          */
/*         (no current library set), this program fails cleanly           */
/*         instead of CALLing with an invalid qualifier - see the         */
/*         *NONE check below.                                             */
             PGM        PARM(&LIB)

/* Parameter must not have an initial VALUE(); the caller supplies it     */
/* (blank/omitted if not passed). Default is filled in below.             */
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)

/* Left blank on purpose: JU0900C itself defaults a blank RUNMODEP to     */
/* *LIVE. Declared CHAR 10 to exactly match JU0900C's *ENTRY PLIST length */
/* (docs/probes.md ticket 1).                                             */
             DCL        VAR(&RUNMODE) TYPE(*CHAR) LEN(10)

/* One-character staging area for the *DEC -> *CHAR conversion described  */
/* in the header comment.                                                 */
             DCL        VAR(&SELCHAR) TYPE(*CHAR) LEN(1)

/* MN0000D: record format MNUFMT, fields SELNO/MSGTXT - see header        */
/* comment. DCLF declares &SELNO (*DEC 1 0), &MSGTXT (*CHAR 40) and &IN03 */
/* (*LGL, CF03) for us.                                                   */
             DCLF       FILE(MN0000D)

/* Safety net: see tools/qclsrc/txsetup.clp for why this matters (an      */
/* unmonitored *ESCAPE can hang a non-interactive job forever instead of  */
/* failing). This does NOT cover RPG1216 (see the header comment).        */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

/* *CURLIB is only valid as a qualifier on object references (CALL        */
/* PGM(*CURLIB/xxx) works); ADDLIBLE below needs the real name (see       */
/* header comment and tools/qclsrc/txsetup.clp), so resolve it now.       */
             IF         COND(&LIB *EQ '*CURLIB') THEN(DO)
                RTVJOBA    CURLIB(&LIB)
             ENDDO

/* RTVJOBA CURLIB() can return the special value *NONE (unverified on     */
/* real hardware - general IBM i CL behavior, not confirmed in this       */
/* session's primary sources) when the job has no current library set.    */
/* *NONE is not a real library name, so every CALL PGM(&LIB/xxx) below    */
/* would fail to qualify correctly if left as is.                         */
             IF         COND(&LIB *EQ '*NONE') THEN(DO)
                SNDPGMMSG  MSG('MN0000C: no current library (LIB *NONE). +
                             Pass LIB explicitly.') MSGTYPE(*COMP)
                GOTO       CMDLBL(TXEND)
             ENDDO

/* TK0100's CHAIN against TOKUIM/TANTOM, JU0300's primary read of         */
/* JUCHUL1, and TK0100D's implicit open all resolve unqualified via the   */
/* job's real *LIBL/*CURLIB at runtime (see header comment), so add &LIB  */
/* to the top of the library list before entering the menu loop - same    */
/* pattern as JU0900C's own internal ADDLIBLE and                         */
/* tools/qclsrc/txsetup.clp.                                              */
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

MENU:        SNDRCVF    RCDFMT(MNUFMT)

/* F3 (CF03/&IN03) is the only in-loop exit - see the header comment (no  */
/* numeric EXIT option).                                                  */
             IF         COND(&IN03) THEN(GOTO CMDLBL(TXEND))

/* Selection travels via *LDA too (05-06 teaching point) - see the shared */
/* *LDA layout note in the header comment. Position 1, length 1: the raw  */
/* digit.                                                                 */
             CHGVAR     VAR(&SELCHAR) VALUE(&SELNO)
             CHGDTAARA  DTAARA(*LDA (1 1)) VALUE(&SELCHAR)

             IF         COND(&SELNO *EQ 1) THEN(GOTO CMDLBL(OPT1))
             IF         COND(&SELNO *EQ 2) THEN(GOTO CMDLBL(OPT2))
             IF         COND(&SELNO *EQ 3) THEN(GOTO CMDLBL(OPT3))

/* Anything else: rewrite the output field (no DDS conditioning           */
/* indicators, see header comment), also tell the job log, reset the      */
/* selection field so a bare Enter does not silently repeat it, then      */
/* redisplay the same menu.                                               */
             CHGVAR     VAR(&MSGTXT) VALUE('MN0000C: invalid selection.')
             SNDPGMMSG  MSG('MN0000C: invalid selection.')
             CHGVAR     VAR(&SELNO) VALUE(0)
             GOTO       CMDLBL(MENU)

OPT1:        CHGVAR     VAR(&MSGTXT) VALUE(' ')
             CALL       PGM(&LIB/TK0100)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                CHGVAR     VAR(&MSGTXT) VALUE('MN0000C: TK0100 ended +
                             abnormally.')
                SNDPGMMSG  MSG('MN0000C: TK0100 ended abnormally.')
             ENDDO
             CHGVAR     VAR(&SELNO) VALUE(0)
             GOTO       CMDLBL(MENU)

OPT2:        CHGVAR     VAR(&MSGTXT) VALUE(' ')
             CALL       PGM(&LIB/JU0300)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                CHGVAR     VAR(&MSGTXT) VALUE('MN0000C: JU0300 ended +
                             abnormally.')
                SNDPGMMSG  MSG('MN0000C: JU0300 ended abnormally.')
             ENDDO
             CHGVAR     VAR(&SELNO) VALUE(0)
             GOTO       CMDLBL(MENU)

OPT3:        CHGVAR     VAR(&MSGTXT) VALUE(' ')
             CALL       PGM(&LIB/JU0900C) PARM(&RUNMODE &LIB)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                CHGVAR     VAR(&MSGTXT) VALUE('MN0000C: JU0900C ended +
                             abnormally.')
                SNDPGMMSG  MSG('MN0000C: JU0900C ended abnormally.')
             ENDDO
             CHGVAR     VAR(&SELNO) VALUE(0)
             GOTO       CMDLBL(MENU)

TXEND:       RETURN

FAILSAFE:    SNDPGMMSG  MSG('MN0000C: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
