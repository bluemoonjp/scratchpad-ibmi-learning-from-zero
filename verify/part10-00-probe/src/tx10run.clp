/* TX10RUN - verify/part10-00-probe helper, NOT part of the curriculum.   */
/* Runs one of the tools/ commands via QCMDEXC from inside a CL wrapper   */
/* program. The wrapper (verify/lib/clgen.mjs) is compiled BEFORE the     */
/* *CMD objects it would call exist (they are created by earlier steps    */
/* of the same wrapper), so a literal command statement fails with        */
/* CPD0030. Same reason and pattern as verify/part05-txlegacy-exec/src/   */
/* txlegrun.clp, but this one supports FORCE(*YES) (txlegrun does not).   */
/*                                                                        */
/* PARM: WHAT (6 chars) picks the command:                                */
/*   LEGACY  TXLEGACY LIB(tgt) FORCE(*YES)                                */
/*   RESET   TXRESET LIB(tgt)                                             */
/*   MIGR2   TXMIGR TO(2) LIB(tgt)                                        */
/*   SETUP   TXSETUP LIB(tgt) FORCE(*YES)                                 */
/*   TOOL = library holding the *CMD objects, TGT = library acted on.     */
/* CLONEDIR is left out on purpose so each *CMD applies its own DFT.      */
/* The command buffer is 80 bytes; trailing blanks are tolerated.         */
             PGM        PARM(&WHAT &TOOL &TGT)

             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(6)
             DCL        VAR(&TOOL) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TGT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(80)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)

             IF         COND(&WHAT *EQ 'LEGACY') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&TOOL) *TCAT '/TXLEGACY LIB(' *TCAT +
                          %TRIM(&TGT) *TCAT ') FORCE(*YES)'))
             IF         COND(&WHAT *EQ 'RESET') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&TOOL) *TCAT '/TXRESET LIB(' *TCAT +
                          %TRIM(&TGT) *TCAT ')'))
             IF         COND(&WHAT *EQ 'MIGR2') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&TOOL) *TCAT '/TXMIGR TO(2) LIB(' +
                          *TCAT %TRIM(&TGT) *TCAT ')'))
             IF         COND(&WHAT *EQ 'SETUP') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&TOOL) *TCAT '/TXSETUP LIB(' *TCAT +
                          %TRIM(&TGT) *TCAT ') FORCE(*YES)'))
             IF         COND(&CMD *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TX10RUN: unknown WHAT value - nothing run.')
                RETURN
             ENDDO

             SNDPGMMSG  MSG('TX10RUN: running ' *CAT %TRIM(&CMD))
             CHGVAR     VAR(&CMDLEN) VALUE(80)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TX10RUN: the +
                          command ended with an escape message. See job +
                          log.'))
             SNDPGMMSG  MSG('TX10RUN: returned from ' *CAT %TRIM(&WHAT))

             ENDPGM
