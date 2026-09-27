/* RUNTXMIGR - verify/part05-txmigr-to2b helper, NOT part of the          */
/* curriculum. Calls TXMIGR (a *CMD) via QCMDEXC, for exactly the same     */
/* reason and in exactly the same shape as runsetup.clp in the sibling     */
/* connection A directory (verify/part05-txmigr-to2/src/runsetup.clp) -    */
/* TXMIGR's own *CMD is created at runtime by this manifest's own          */
/* CPTXMCMD step, inside the same wrapper job, so a literal `TXMIGR        */
/* TO(2) LIB(...)` statement embedded directly in a step's cmd text        */
/* would fail to compile. Byte-for-byte identical to the copy in           */
/* verify/part05-txmigr-to2/src/runtxmigr.clp except for this header       */
/* comment - duplicated rather than shared so this connection's own        */
/* directory is self-contained (each verify/part05-* batch carries its     */
/* own src/, same convention every other manifest in this repo follows).   */
/*                                                                        */
/* PARM: LIB (<=10 chars, where TXMIGR/its *CMD are compiled), LIB2       */
/* (<=10 chars, the library to migrate). CLONEDIR is omitted from the     */
/* command string on purpose (see runsetup.clp) so TXMIGR's *CMD applies  */
/* its own DFT(' '), safely blank-padded to LEN(200) by the command       */
/* processor. TO is hardcoded to 2 in the command string itself (this     */
/* manifest only ever tests TO(2) - see docs/part05/                      */
/* 05-09-add-field-level-check.md).                                       */
             PGM        PARM(&LIB &LIB2)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(60)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)

             CHGVAR     VAR(&CMD) VALUE(%TRIM(&LIB) *TCAT '/TXMIGR TO(2) +
                          LIB(' *TCAT %TRIM(&LIB2) *TCAT ')')
             CHGVAR     VAR(&CMDLEN) VALUE(60)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000)

             ENDPGM
