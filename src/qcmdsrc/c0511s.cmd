/* C0511S command - wraps the C0511S *PGM so parameters are always       */
/* padded to their declared length by the command processor (avoids the */
/* 32-byte literal-padding trap of a raw CALL PGM(...) PARM(...) - the   */
/* same reason tools/qcmdsrc/txsetup.cmd/txreset.cmd/txlegacy.cmd exist, */
/* and the same bug this repo's own C0511RUN helper works around for    */
/* verify/'s own connections). FIXED (2026-09-27, advisor review): 05-11 */
/* itself only ever told learners to CALL C0511S directly with a literal */
/* CLONEDIR argument - that path was never actually run on real hardware */
/* (every verify/ connection went through C0511RUN instead) and would    */
/* leave &CLONEDIR reading up to 168 bytes past what a 32-byte-padded    */
/* literal actually supplies. This command exists so the lesson's own    */
/* 実演 can invoke C0511S the safe way (matching how 05-02/05-06/07-04    */
/* etc. already teach *CMD wrappers for exactly this trap).              */
             CMD        PROMPT('C0511S - plant a decimal data error')
             PARM       KWD(LIB) TYPE(*CHAR) LEN(10) DFT(*CURLIB) +
                          PROMPT('Target library')
             PARM       KWD(CLONEDIR) TYPE(*CHAR) LEN(200) DFT(' ') +
                          PROMPT('Clone directory')
