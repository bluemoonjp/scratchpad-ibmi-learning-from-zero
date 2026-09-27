/* RUNSETUP - verify/part05-txmigr-to2 helper, NOT part of the curriculum. */
/* Calls TXSETUP (a *CMD) via QCMDEXC from inside a CL wrapper program     */
/* that has no DCL section of its own available to any individual step    */
/* (verify/lib/clgen.mjs's buildClWrapperSource puts MONMSG/CHGJOB/        */
/* ADDLIBLE as the very first executable statements, using up the only    */
/* position CL allows a DCL). A literal `TXSETUP LIB(...) FORCE(*YES)`     */
/* statement embedded directly in a step's own cmd text would also fail   */
/* for a different reason: the CL compiler resolves a *CMD's syntax at    */
/* COMPILE time, but this manifest's own CPTXSCMD step creates the        */
/* &LIB/TXSETUP *CMD at RUNTIME, inside the SAME wrapper - it does not     */
/* exist yet when the wrapper itself is compiled. Same problem, same fix   */
/* as verify/part05-txlegacy-exec/src/txlegrun.clp (advisor review,        */
/* 2026-09-27).                                                            */
/*                                                                        */
/* PARM: LIB (<=10 chars, the library TXSETUP/its *CMD are compiled into), */
/*       LIB2 (<=10 chars, the library to actually build the sample DB    */
/*       in). Both declared lengths are well under the 32-byte boundary   */
/*       where the CALL/PARM literal-padding trap starts (docs/part03/    */
/*       03-08-parameters-and-call.md's own real-hardware finding), so    */
/*       passing them as short literals from the manifest's own CALL step */
/*       is safe. CLONEDIR is deliberately never mentioned here at all:   */
/*       the command string below omits it, so TXSETUP's *CMD applies its */
/*       own DFT(' ') - fully blank-padded to its declared LEN(200) by the */
/*       command processor itself (not by this program), which is exactly */
/*       the safe pattern docs/probes.md's TXSETUP debugging session      */
/*       confirmed works (a raw CALL PGM(...) PARM() literal, by          */
/*       contrast, is only reliably blank-padded up to 32 bytes).         */
/*                                                                        */
/* CMDLEN is CMD's own full declared size (60), not the shorter true      */
/* command length - trailing blanks in a CL command are tolerated (same   */
/* reasoning verify/part05-txlegacy-exec/src/txlegrun.clp already uses).  */
             PGM        PARM(&LIB &LIB2)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(60)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)

             CHGVAR     VAR(&CMD) VALUE(%TRIM(&LIB) *TCAT '/TXSETUP LIB(' +
                          *TCAT %TRIM(&LIB2) *TCAT ') FORCE(*YES)')
             CHGVAR     VAR(&CMDLEN) VALUE(60)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000)

             ENDPGM
