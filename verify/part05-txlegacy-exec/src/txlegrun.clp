/* TXLEGRUN - verify/part05-txlegacy-exec helper, NOT part of the         */
/* curriculum. Calls TXLEGACY (a *CMD) via QCMDEXC from inside a CL       */
/* wrapper program that has no DCL section of its own available to any    */
/* individual step (verify/lib/clgen.mjs's buildClWrapperSource puts      */
/* MONMSG/CHGJOB/ADDLIBLE as the very first executable statements, using  */
/* up the only position CL allows a DCL - see work/design/part08-design-  */
/* v1.md's own finding on this). A literal `TXLEGACY LIB(...)` statement  */
/* embedded directly in a step's own cmd text would also fail for a       */
/* different reason: the CL compiler resolves a *CMD's syntax at COMPILE  */
/* time, but TXLEGACY's own *CMD is only created by an earlier step's     */
/* RUNTIME action inside the same wrapper, not yet existing when the      */
/* wrapper itself is compiled (advisor review, 2026-09-27; the same       */
/* problem P0-3 already solved for JUCINQ in verify/part06-12-prtf-cpp-   */
/* swap/manifest.json, whose PRESWAPRUN/POSTSWAPRUN steps call QCMDEXC    */
/* the same way this file does).                                         */
/*                                                                        */
/* PARM: LIB - target library (<=10 chars). Builds 'TXLEGACY LIB(...)'    */
/* at runtime (safe from the 32-byte CALL/PARM literal-padding trap - see */
/* docs/part03/03-08-parameters-and-call.md's own real-hardware finding - */
/* because LIB's own declared length here is 10, well under the 32-byte  */
/* boundary where that trap starts). CMDLEN is the DS's own full 40-byte  */
/* size, not the shorter true command length - trailing blanks in a CL    */
/* command are tolerated (same reasoning src/legacy/qrpgsrc/za0510.rpg's  */
/* header note 9 already documents for its own QCMDEXC call).             */
/*                                                                        */
/* After the QCMDEXC call, also reports TXLEGST's own value (RTVDTAARA +  */
/* SNDPGMMSG, not DSPDTAARA - this program runs inside a qsh-invoked      */
/* batch-like job with no real display device, and DSPDTAARA's actual    */
/* behavior there is unconfirmed; RTVDTAARA+SNDPGMMSG is the same proven  */
/* pattern verify/part05-qcmdexc-runtime/src/vlda.clp already uses for    */
/* *LDA). MONMSG here means "TXLEGST does not exist" is reported as a     */
/* value, not a wrapper-level step failure - TXLEGACY not having created  */
/* it yet (e.g. it failed before reaching that point) IS the evidence.    */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(40)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)
             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(1)

             CHGVAR     VAR(&CMD) VALUE('TXLEGACY LIB(' *TCAT %TRIM(&LIB) +
                          *TCAT ')')
             CHGVAR     VAR(&CMDLEN) VALUE(40)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)

             RTVDTAARA  DTAARA(&LIB/TXLEGST (1 1)) RTNVAR(&FLAG)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXLEGRUN: TXLEGST does not exist (TXLEGACY +
                             did not reach that point).')
                GOTO       CMDLBL(TXLEGRUN_END)
             ENDDO
             SNDPGMMSG  MSG('TXLEGRUN: TXLEGST=[' *CAT &FLAG *CAT ']')

TXLEGRUN_END:  ENDPGM
