/* JU0900C - TICKET1 SOLUTION (05-13 checkpoint model answer, not the     */
/*           as-shipped src/legacy/qclsrc/ju0900c.clp): &MINQTY widened   */
/*           to LEN(5 0), matching ZA0500's *ENTRY PLIST declaration for  */
/*           the same parameter. This is the only change from the        */
/*           as-shipped source (compare with a diff before relying on     */
/*           this) - everything else, including the OPNQRYF ordering      */
/*           that ticket 2 is about, is untouched here on purpose (this   */
/*           file answers ticket 1 only).                                 */
/*                                                                        */
/* Which side to fix is a judgment call, not a single correct answer      */
/* (see docs/part05/05-13-checkpoint-tickets.md's own grading rubric):    */
/* the value actually used (5, see CHGVAR below) fits comfortably in      */
/* either 3 or 5 digits. This solution widens JU0900C to match ZA0500,    */
/* since ZA0500's *ENTRY PLIST is the shared contract a *PSSR-notified    */
/* caller (ticket 3) also depends on being stable - narrowing ZA0500      */
/* instead would be an equally valid answer, matching JU0900C's 3,0.      */
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

             /* FIXED (05-13 ticket 1): was LEN(3 0), which disagreed with */
             /* ZA0500's *ENTRY PLIST (5,0) for the same positional        */
             /* parameter. OPM CALL does not check parameter length/       */
             /* decimal agreement when the parameter COUNT matches (see    */
             /* docs/probes.md) - ZA0500 was reading one byte past what    */
             /* JU0900C actually allocated for &MINQTY, corrupting its     */
             /* low-order digit and sign nibble.                          */
             DCL        VAR(&MINQTY) TYPE(*DEC) LEN(5 0)

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
             /* TICKET (05-13 ticket 2, NOT fixed in this file): unsorted  */
             /* JUCHUD is read in JUNO/JULINE (arrival/key) order, so a    */
             /* later-entered order for a short product can be allocated  */
             /* before an earlier one. See docs/part05/05-13-checkpoint-   */
             /* tickets.md and ZA0500 for the corresponding M1/MR ordering */
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

TXCLOF:      CLOF       FILE(JUCHUD)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUD)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('JU0900C: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
