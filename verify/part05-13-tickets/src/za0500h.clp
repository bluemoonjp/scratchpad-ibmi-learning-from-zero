/* ZA0500H - verify/part05-13-tickets helper, NOT part of the             */
/* curriculum. Ticket 1's own grading rubric                              */
/* (docs/part05/05-13-checkpoint-tickets.md) explicitly asks to confirm   */
/* the SAME result both "via a test harness" and "via JU0900C" - two      */
/* independent call paths agreeing. This manifest's other CALL step       */
/* (RUNCOMBO) only ever exercises the JU0900C-mediated path; before this  */
/* helper existed, nothing in this manifest called &LIB/ZA0500 directly   */
/* to check parity.                                                       */
/*                                                                        */
/* This program opens JUCHUD/JUCHUM the same way                          */
/* solutions/05-13/ju0900c-ticket1.clp does (OVRDBF+RCVF on JUCHUM,        */
/* OVRDBF+OPNQRYF KEYFLD((JUNO)(JULINE)) on JUCHUD) and then CALLs         */
/* &LIB/ZA0500 DIRECTLY, passing a properly DCL'd *DEC LEN(5 0) &MINQTY -  */
/* matching ZA0500's own *ENTRY PLIST exactly (ticket 1's fix). Being a    */
/* DCL'd CL variable (not a bare literal typed into CALL...PARM()), this   */
/* also sidesteps the 32-byte-literal padding trap docs/probes.md already  */
/* documents for other PARM() calls in this same curriculum - not because  */
/* MINQTY (3 packed bytes) would overflow it, but so this program reads    */
/* as an ordinary, correctly-typed caller rather than a literal that       */
/* happens to be short enough.                                            */
/*                                                                        */
/* RUNMODE is hard-coded to '*TEST' (matches RUNCOMBO's own PARM) so       */
/* ZAIKOM is never mutated by either call in this same connection.         */
/*                                                                        */
/* Judge success by comparing THIS call's own printed OK/SHORT/NOTFOUND    */
/* lines (12 rows expected - see expected/notes.md) against RUNCOMBO's:    */
/* both read the same unchanged JUCHUD/JUCHUM/ZAIKOM, with the same        */
/* RUNMODE and the same (correctly 5,0-typed) MINQTY=5, so both should     */
/* print byte-for-byte identical output. This assumes ZA0500's QSYSPRT     */
/* output reaches this qsh connection's stdout at all - the SAME open      */
/* question part05-13-tickets' own manifest description already flags     */
/* for RUNCOMBO; if it does not, BOTH calls will show 0 printed lines,     */
/* which is uninformative about parity either way (see expected/notes.md).*/
/*                                                                        */
/* Placed BEFORE RUNCOMBO in this manifest, not as the very last step:     */
/* it CALLs the same &LIB/ZA0500 object RUNCOMBO does, compiled moments    */
/* earlier in this same connection, from a caller with no prior real-      */
/* hardware history on this exact object - same hang-risk-last caution     */
/* this manifest's own description already applies to RUNCOMBO, just one   */
/* step earlier (README.md's hang-risk-last rule only requires the         */
/* riskiest step be LAST, not that every risky step be the only one).      */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB   library to run against. Default *CURLIB.                      */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&RUNMODE) TYPE(*CHAR) LEN(10) VALUE('*TEST')
             DCL        VAR(&MINQTY) TYPE(*DEC) LEN(5 0) VALUE(5)

             DCLF       FILE(JUCHUM)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

             /* ZA0500 must see &LIB/ZA0500 (unqualified CALL below) and   */
             /* the same JUCHUD/JUCHUM regardless of *LIBL, same reasoning */
             /* as ju0900c-ticket1.clp's own ADDLIBLE.                     */
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             OVRDBF     FILE(JUCHUM) TOFILE(&LIB/JUCHUM) SHARE(*NO)
             RCVF
             MONMSG     MSGID(CPF0864) EXEC(DO)
                SNDPGMMSG  MSG('ZA0500H: JUCHUM is empty.')
             ENDDO
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0500H: could not read JUCHUM.')
             ENDDO

             OVRDBF     FILE(JUCHUD) TOFILE(&LIB/JUCHUD) SHARE(*YES)
             OPNQRYF    FILE((JUCHUD)) KEYFLD((JUNO) (JULINE))
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0500H: could not open JUCHUD.')
                GOTO       CMDLBL(TXCLOF)
             ENDDO

             CALL       PGM(&LIB/ZA0500) PARM(&RUNMODE &MINQTY)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0500H: ZA0500 ended abnormally.')
             ENDDO

/* FIXED (2026-09-27, real hardware - see src/legacy/qclsrc/ju0900c.clp's  */
/* matching fix for the full finding): close both this program's own ODPs */
/* before returning. JUCHUM was DCLF'd above with no OPNID (defaults to    */
/* *NONE) -> CLOSE OPNID(*NONE). JUCHUD was OPNQRYF'd with no explicit     */
/* OPNID -> defaults to the unqualified file name -> CLOF OPNID(JUCHUD).   */
/* Without this, a caller running this program twice in the same job (or  */
/* any other program sharing this OPNID afterward) hits "OPNID(JUCHUD)     */
/* for file JUCHUD already exists" - exactly what part05-13-tickets'       */
/* RUNZA0500H itself observed when JU0900C's own (then-unclosed) ODP was   */
/* still open from RUNCOMBO immediately before it.                        */
TXCLOF:      CLOF       OPNID(JUCHUD)
             MONMSG     MSGID(CPF0000)
             CLOSE      OPNID(*NONE)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUD)
             MONMSG     MSGID(CPF0000)
             DLTOVR     FILE(JUCHUM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('ZA0500H: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
