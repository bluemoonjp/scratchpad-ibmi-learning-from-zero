/* JU0900C - filter order details (JUCHUD) and run stock allocation      */
/*           (ZA0500) against them. Legacy system (Part 5).              */
/*                                                                        */
/* Shares the JUCHUD open data path with ZA0500 (OVRDBF SHARE(*YES)) so  */
/* ZA0500's own primary-file read sees the same filtered/sorted view     */
/* this program set up, instead of opening JUCHUD independently. Also    */
/* DCLFs JUCHUM (a plain control read, not shared) purely to show how a  */
/* CL program's DCLF creates a rebuild dependency on the file it reads   */
/* (05-07 / TXMIGR topic) even though the OPNQRYF below never touches    */
/* JUCHUM.                                                                */
/*                                                                        */
/* PARM:                                                                  */
/*   RUNMODE  '*LIVE' actually updates ZAIKOM; anything else is a dry    */
/*            run (ZA0500 still reports SHORT/OK but does not UPDAT).    */
/*            Default '*LIVE'.                                            */
/*   LIB      library to run against. Default *CURLIB.                    */
             PGM        PARM(&RUNMODEP &LIB)

             DCL        VAR(&RUNMODEP) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&RUNMODE) TYPE(*CHAR) LEN(10)

             /* BUG (05-13 ticket 1): declared 3,0 here but ZA0500's       */
             /* *ENTRY PLIST declares the matching parameter as 5,0. OPM   */
             /* CALL does not check parameter length/decimal agreement    */
             /* when the parameter COUNT matches (see docs/probes.md) -   */
             /* ZA0500 ends up reading one byte past what JU0900C actually */
             /* allocated for &MINQTY, corrupting its low-order digit and */
             /* sign nibble. Left in deliberately; the fix is to make     */
             /* this LEN(5 0), matching ZA0500's PLIST.                    */
             DCL        VAR(&MINQTY) TYPE(*DEC) LEN(3 0)

             DCLF       FILE(JUCHUM)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&RUNMODEP *EQ ' ') THEN(CHGVAR +
                          VAR(&RUNMODEP) VALUE('*LIVE'))
             CHGVAR     VAR(&RUNMODE) VALUE(&RUNMODEP)
             CHGVAR     VAR(&MINQTY) VALUE(5)

             /* ZA0500 must see &LIB/ZA0500 and the same JUCHUD/JUCHUM     */
             /* regardless of *LIBL (04-06's RPG1216 hang was caused by    */
             /* exactly this kind of unqualified reference in a fresh job).*/
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             OVRDBF     FILE(JUCHUM) TOFILE(&LIB/JUCHUM) SHARE(*NO)
             RCVF
             MONMSG     MSGID(CPF0864) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: JUCHUM is empty.')
             ENDDO
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: could not read JUCHUM.')
             ENDDO

             OVRDBF     FILE(JUCHUD) TOFILE(&LIB/JUCHUD) SHARE(*YES)
             /* TICKET (05-13 ticket 2): unsorted JUCHUD is read in        */
             /* JUNO/JULINE (arrival/key) order, so a later-entered order  */
             /* for a short product can be allocated before an earlier    */
             /* one. See ZA0500 for the corresponding M1/MR ordering       */
             /* requirement this alone cannot satisfy.                     */
             OPNQRYF    FILE((JUCHUD)) KEYFLD((JUNO) (JULINE))
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: could not open JUCHUD.')
                GOTO       CMDLBL(TXCLOF)
             ENDDO

             CALL       PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('JU0900C: ZA0500 ended abnormally.')
             ENDDO

             /* FIXED (part05-legacy-probe, 2026-09-26, real-hardware      */
             /* CRTCLPGM): CLOF FILE(JUCHUD) here used to fail with        */
             /* CPD0043 ("Keyword FILE not valid") - same finding as       */
             /* tools/qclsrc/txcheck.clp's header comment: CLOF is not a   */
             /* real command. Unlike txcheck.clp, though, CLOSE OPNID      */
             /* cannot substitute here: OPNID(*NONE) closes THIS program's */
             /* own DCLF'd file with no OPNID given, and that is JUCHUM    */
             /* (line 33 above), not JUCHUD - JUCHUD is never DCLF'd in    */
             /* this program at all (only OVRDBF/OPNQRYF'd, for ZA0500 to  */
             /* share). Removed the close attempt outright: JUCHUD's       */
             /* shared ODP is opened by the CALLed ZA0500 (its F-spec      */
             /* IP), which auto-closes its files on LR before returning    */
             /* here, so by the time TXCLOF runs there is nothing left of  */
             /* this program's own to close. DLTOVR below is already      */
             /* MONMSG-protected either way.                                */
TXCLOF:      DLTOVR     FILE(JUCHUD)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('JU0900C: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
