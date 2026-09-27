/* C0511RUN - verify/part05-13-pssr helper, NOT part of the       */
/* curriculum. Adapted verbatim from                                      */
/* verify/part05-mch1202-corrupt/src/c0511run.clp (same manifest-self-     */
/* containment reasoning this repo already uses elsewhere - each manifest */
/* compiles its own copy of small verify-only helpers rather than reading */
/* a sibling manifest's directory). Calls C0511S (src/qclsrc/c0511s.clp)  */
/* with a properly *CHAR LEN(200)-sized &CLONEDIR argument, not a bare    */
/* CALL...PARM() literal. C0511S's own *ENTRY PLIST declares &CLONEDIR as */
/* LEN(200), but a literal typed directly in CALL PGM(...) PARM('...') is */
/* only padded up to 32 bytes by the CALL command itself (docs/probes.md's*/
/* own "32-byte literal" finding - the same reason tools/qclsrc/txsetup.  */
/* clp/txreset.clp/txlegacy.clp all grew *CMD wrappers, and the same      */
/* reason verify/part05-txlegacy-exec/src/txlegrun.clp exists). Passing a */
/* blank literal here for &CLONEDIR would leave C0511S reading up to 168  */
/* bytes of whatever happened to sit past that 32-byte argument as part   */
/* of its own LEN(200) variable, instead of the genuinely all-blank buffer*/
/* its own `IF COND(&CLONEDIR *EQ ' ')` check needs to correctly trigger  */
/* its CURUSER-based default (this is the same class of bug as 05-13     */
/* ticket 1's own MINQTY mismatch - a receiver reading past what the      */
/* caller actually passed). A properly DCL'd LEN(200) CL variable, passed */
/* by reference (not a literal), does not have this problem: CALL passes */
/* the variable's own full declared length regardless of what it holds.  */
/*                                                                        */
/* &CLONEDIR is left blank on purpose (not computed here) so this run     */
/* actually exercises C0511S's own CURUSER-based default-directory logic  */
/* (05-11's own lesson text recommends always passing CLONEDIR explicitly */
/* - but a verify manifest cannot hardcode the real signed-on user's home */
/* directory without leaking a private username into a committed file,   */
/* so this is the one caller that must rely on the default instead).      */
/*                                                                        */
/* UNVERIFIED, same as the original: this reasoning mirrors the already-   */
/* established pattern behind the tools above; the C0511RUN -> C0511S     */
/* call itself was hardware-confirmed by part05-mch1202-corrupt only if   */
/* that manifest's own connection ran BEFORE this one - check its own      */
/* work/verify/results/ (gitignored) before assuming this part is settled.*/
/*                                                                        */
/* PARM: LIB - library to run C0511S against (<=10 chars, safe from the    */
/*             32-byte trap either way, matching txlegrun.clp's own       */
/*             precedent for its own single LIB parameter).               */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             CHGVAR     VAR(&CLONEDIR) VALUE(' ')

             CALL       PGM(&LIB/C0511S) PARM(&LIB &CLONEDIR)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('C0511RUN: C0511S ended abnormally.')
                GOTO       CMDLBL(ENDIT)
             ENDDO

             SNDPGMMSG  MSG('C0511RUN: C0511S returned normally.')

ENDIT:       RETURN

FAILSAFE:    SNDPGMMSG  MSG('C0511RUN: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
