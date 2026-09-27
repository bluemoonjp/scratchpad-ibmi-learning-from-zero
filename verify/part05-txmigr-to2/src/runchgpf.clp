/* RUNCHGPF - verify/part05-txmigr-to2 helper, NOT part of the            */
/* curriculum. Applies db/v2/juchum.pf by hand (05-09's own manual         */
/* walkthrough steps 1-4, and the same thing tools/qclsrc/txmigr.clp's     */
/* own "Step 1" does), deliberately BEFORE TXMIGR ever runs: TXMIGR's own  */
/* CHGPF, DSPDBR-based LF rebuild attempt, and DSPOBJD-based full-*PGM     */
/* recompile all happen back-to-back inside ONE CALL with no gap to CALL   */
/* JU0900C/JU0300 in between and actually observe CPF4131 - so the only    */
/* way to see CPF4131 actually happen is to apply the format change        */
/* ourselves first (advisor review, 2026-09-27).                          */
/*                                                                        */
/* This exists as its OWN small CL program (not inline in the wrapper's    */
/* per-step CL text) for the same reason runsetup.clp/runtxmigr.clp do:    */
/* the wrapper program (verify/lib/clgen.mjs) has no DCL section available */
/* to any individual step, and this needs its own working variables to     */
/* compute CLONEDIR - a raw CL statement embedded in a step's own cmd text */
/* cannot DCL anything of its own.                                        */
/*                                                                        */
/* PARM: LIB2 (<=10 chars, the library to apply the change to). CLONEDIR  */
/* is computed here exactly the way tools/qclsrc/txsetup.clp/txmigr.clp    */
/* already do it (RTVJOBA CURUSER, not USER - see docs/probes.md's own     */
/* QUSER-vs-CURUSER finding), landing on the SAME real                     */
/* $HOME/ibmi-kyozai/db/v2/juchum.pf path this manifest's own CVT-JUCHUMV2 */
/* sh step already converted to genuine CCSID 1208 (see this manifest's    */
/* own description for why CCSID matters here: heredoc'd files default to */
/* CCSID 273/EBCDIC, and CPYFRMSTMF's STMFCCSID(1208) below would          */
/* otherwise misinterpret those correct EBCDIC bytes as if they were       */
/* already ASCII, per docs/probes.md's own CPFA0A2/CPFA095 finding for     */
/* exactly this combination).                                             */
             PGM        PARM(&LIB2)

             DCL        VAR(&LIB2) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USRPRF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&HOMEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&SRC) TYPE(*CHAR) LEN(200)
             DCL        VAR(&TOMBR) TYPE(*CHAR) LEN(200)

             RTVJOBA    CURUSER(&USRPRF)
             CHGVAR     VAR(&HOMEDIR) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                          *TCAT '/ibmi-kyozai')
             CHGVAR     VAR(&SRC) VALUE(&HOMEDIR *TCAT '/db/v2/juchum.pf')
             CHGVAR     VAR(&TOMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB2) +
                          *TCAT '.LIB/QDDSSRC.FILE/JUCHUM.MBR')

             CPYFRMSTMF FROMSTMF(&SRC) TOMBR(&TOMBR) MBROPT(*REPLACE) +
                          STMFCCSID(1208)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('RUNCHGPF: CPYFRMSTMF failed - could not +
                             stage v2 DDS into JUCHUM member. See job log.')
                GOTO       CMDLBL(ENDIT)
             ENDDO

             CHGPF      FILE(&LIB2/JUCHUM) SRCFILE(&LIB2/QDDSSRC) +
                          SRCMBR(JUCHUM)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('RUNCHGPF: CHGPF +
                          failed. See job log.'))

ENDIT:       ENDPGM
