/* RUNPROBE - verify/part05-txmigr-to2(b) helper, NOT part of the         */
/* curriculum. Isolates 05-09's own central claim (CPF4131 fires when a   */
/* program's baked-in record format level ID for JUCHUM disagrees with    */
/* JUCHUM's CURRENT one) from any RPG-side confound - specifically 05-13  */
/* ticket 1's still-unfixed MINQTY 3,0/5,0 mismatch, which fires inside   */
/* ZA0500 and is never reached here because this program never CALLs      */
/* ZA0500 at all (two-reviewer critique of this manifest's first draft,   */
/* 2026-09-27: RJU0900B/RJU0900A alone could not tell a real CPF4131      */
/* apart from ZA0500's own already-known RPG0907, since JU0900C's own     */
/* MONMSG(CPF0000) on its RCVF swallows CPF4131 into a generic message    */
/* and falls through to CALL ZA0500 regardless - see ju0900c.clp's own    */
/* header comment. insertLog in verify/lib/clgen.mjs also only saves      */
/* SUBSTR(MESSAGE_TEXT,1,200), not MESSAGE_ID, so VFYLOG alone cannot      */
/* reliably tell CPF4131 apart from an unrelated message by ID either).    */
/*                                                                        */
/* Structure deliberately mirrors src/legacy/qclsrc/ju0900c.clp's own      */
/* DCLF-then-later-OVRDBF-then-RCVF sequence (so OVRDBF takes effect      */
/* before DCLF's implicit open at the first RCVF - same reasoning that     */
/* file's own header already relies on) but reads ONLY JUCHUM and never   */
/* touches JUCHUD/ZA0500 at all - no RPG program is ever CALLed from this  */
/* program, so it carries none of ZA0500's own RPG0907 risk. The only      */
/* escapes this program can plausibly raise are CPF4131 or CPF0864 (empty  */
/* file), both ordinary *ESCAPE-class messages a 'cl' step's own MONMSG    */
/* catches without ever reaching an *INQUIRY class message.                */
/*                                                                        */
/* This program MUST be compiled as a source member INSIDE &LIB2 (not      */
/* &LIB), and the compiled *PGM itself must also live in &LIB2: TXMIGR's    */
/* own Step 3 ("recompile EVERY *PGM object in the library", tools/         */
/* qclsrc/txmigr.clp) only scans the library it is given (&LIB2 here), so   */
/* only a program actually sitting in &LIB2 gets swept up in that          */
/* recompile - exactly like JU0900C/ZA0500/JU0300. If RUNPROBE lived in     */
/* &LIB instead, TXMIGR would never touch it, and calling it again after    */
/* TXMIGR would prove nothing about whether TXMIGR's own recompile pass     */
/* actually reached this program too (advisor review, 2026-09-27).          */
/*                                                                        */
/* PARM: LIB2 (<=10 chars, the library whose JUCHUM to probe).             */
/*                                                                        */
/* MONMSG order below matters: CPF4131 is listed BEFORE the broader        */
/* CPF0864/CPF0000 catch-alls, since CL evaluates a command's own MONMSG   */
/* lines in the order written and the first matching one wins (standard    */
/* CL rule, already relied on throughout this repo's JU0900C/TXMIGR         */
/* MONMSG chains) - a more specific MSGID must precede a broader one that   */
/* would otherwise shadow it.                                              */
             PGM        PARM(&LIB2)

             DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)

             DCLF       FILE(JUCHUM)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             /* JUCHUM must resolve against &LIB2 (not whatever unrelated  */
             /* JUCHUM &LIB may itself hold) - same reasoning ju0900c.clp's */
             /* own header already gives (04-06's RPG1216 hang was caused   */
             /* by exactly this kind of unqualified reference).             */
             ADDLIBLE   LIB(&LIB2) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

             /* FIXED (advisor review, 2026-09-27): a command-level MONMSG */
             /* whose EXEC() is a bare SNDPGMMSG does NOT stop execution -  */
             /* control falls through to the NEXT statement afterward      */
             /* (this is the exact fall-through mechanism this program's   */
             /* own header comment already describes for ju0900c.clp's own */
             /* RCVF/MONMSG). Without an explicit GOTO out of each branch,  */
             /* ALL THREE staged MONMSG below could fire in sequence AND    */
             /* the unconditional "RCVF succeeded" message would ALSO      */
             /* still run every time, producing contradictory VFYLOG lines */
             /* no matter what actually happened. Each branch below now    */
             /* uses the same EXEC(DO) ... GOTO CMDLBL(CLOSE) ... ENDDO     */
             /* idiom ju0900c.clp's own OPNQRYF MONMSG already uses, so    */
             /* exactly one message is sent and DLTOVR still always runs   */
             /* via the shared CLOSE label.                                */
             OVRDBF     FILE(JUCHUM) TOFILE(&LIB2/JUCHUM) SHARE(*NO)
             RCVF
             MONMSG     MSGID(CPF4131) EXEC(DO)
                SNDPGMMSG  MSG('RUNPROBE: CPF4131 CONFIRMED - JUCHUM record +
                             format level check failed.')
                GOTO       CMDLBL(CLOSE)
             ENDDO
             MONMSG     MSGID(CPF0864) EXEC(DO)
                SNDPGMMSG  MSG('RUNPROBE: JUCHUM empty (RCVF got CPF0864, +
                             not CPF4131 - format levels agree).')
                GOTO       CMDLBL(CLOSE)
             ENDDO
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('RUNPROBE: RCVF failed with something other +
                             than CPF4131/CPF0864 - see the raw job log for +
                             the real message.')
                GOTO       CMDLBL(CLOSE)
             ENDDO

             /* Reached only if none of the three MONMSG above fired: RCVF  */
             /* actually read a row cleanly. */
             SNDPGMMSG  MSG('RUNPROBE: RCVF succeeded and read a JUCHUM row +
                          - no CPF4131, format levels agree.')

CLOSE:       DLTOVR     FILE(JUCHUM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('RUNPROBE: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
