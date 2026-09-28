/* Q0805BH - verify/part08-05-f0805a helper, NOT part of the curriculum.  */
/* Same reasoning as verify/part05-13-tickets/src/za0500h.clp's own       */
/* header: a bare CL numeric literal in CALL...PARM() is NOT typed *DEC   */
/* to match the receiver. It is passed as *DEC(15 5) (X'...0500000F' for  */
/* the literal 5), and Q0805B's own dcl-pi declares minqty packed(5:0),   */
/* which reads only the first 3 of those 8 bytes - bytes with no valid   */
/* sign nibble. This is the CONFIRMED cause of MCH1202 "Decimal data      */
/* error" at statement 440 (`if avail < minqty;`, inside processLine) on  */
/* part08-05-f0805a's 3rd connection (2026-09-28) - see docs/probes.md.   */
/* This helper DCLs &MINQTY as a real *DEC LEN(5 0) CL variable before    */
/* calling Q0805B, exactly matching JU0900C's own already-proven-working  */
/* pattern for the SAME parameter (solutions/05-13/ju0900c-ticket1.clp,   */
/* &MINQTY TYPE(*DEC) LEN(5 0), CHGVAR VAR(&MINQTY) VALUE(5)) - the       */
/* value 5 is confirmed from that same file's own CHGVAR line, not        */
/* guessed here.                                                          */
/*                                                                        */
/* RUNMODE is hard-coded to '*TEST' (matches this manifest's own          */
/* RUNCHAIN step, which also calls JU0900C with '*TEST') so ZAIKOM is     */
/* never mutated by either call in this same connection, keeping a        */
/* same-connection diff against ZA0500's own printed output valid.        */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB   library Q0805B lives in. Default *CURLIB.                     */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&RMODE) TYPE(*CHAR) LEN(10) VALUE('*TEST')
             DCL        VAR(&MINQTY) TYPE(*DEC) LEN(5 0) VALUE(5)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))

             /* Q0805B must see &LIB/Q0805B (unqualified CALL below)       */
             /* regardless of *LIBL, same reasoning as ju0900c-ticket1.clp */
             /* and za0500h.clp's own ADDLIBLE.                            */
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             CALL       PGM(&LIB/Q0805B) PARM(&RMODE &MINQTY)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('Q0805BH: Q0805B ended abnormally.')
             ENDDO

             RETURN

FAILSAFE:    SNDPGMMSG  MSG('Q0805BH: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
