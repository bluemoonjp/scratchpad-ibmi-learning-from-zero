/* LGLRUN - verify/part05-lglang helper, NOT part of the curriculum.      */
/* Same idea as verify/part05-txlegacy-exec/src/txlegrun.clp (a CL wrapper*/
/* step cannot name a *CMD that an earlier step creates at run time, so   */
/* the command is built here and run via QCMDEXC), extended with LANG and */
/* FORCE and with two more modes. Every parameter is declared with its    */
/* real length and each is <=10 chars, so the 32-byte CALL/PARM literal   */
/* padding trap (docs/part03/03-08) does not apply to the literals the    */
/* manifest passes. The 200-byte CLONEDIR of the OLD3 mode is a local     */
/* variable here, so the CALL below passes its full declared length.      */
/*                                                                        */
/* PARM: MODE  4 chars: 'CMD ' run the TXLEGACY *CMD via QCMDEXC          */
/*                      'OLD3' CALL the TXLEGACY *PGM with only 3 parms   */
/*                             (LIB CLONEDIR FORCE), as an older *CMD     */
/*                             would: the program must treat the missing  */
/*                             4th parm (&LANG, MCH3601) as *SAME         */
/*                      'SNAP' report TXLEGLNG and TXLEGST of the library */
/*       TGT   target library (<=10 chars)                                */
/*       LANG  'OMIT' leaves LANG() off the command (default *SAME),      */
/*             else *SAME, *RPG or *RPGLE (CMD mode only)                 */
/*       FORCE 'OMIT' leaves FORCE() off (default *NO), else *NO / *YES;  */
/*             in OLD3 mode it is passed as is, so give *NO or *YES       */
/*       TAG   label for the report lines (<=10 chars)                    */
             PGM        PARM(&MODE &TGT &LANG &FORCE &TAG)

             DCL        VAR(&MODE) TYPE(*CHAR) LEN(4)
             DCL        VAR(&TGT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LANG) TYPE(*CHAR) LEN(7)
             DCL        VAR(&FORCE) TYPE(*CHAR) LEN(4)
             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CLONEDIR) TYPE(*CHAR) LEN(200)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(100)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)
             DCL        VAR(&LNG) TYPE(*CHAR) LEN(7)
             DCL        VAR(&ST) TYPE(*CHAR) LEN(1)

             IF         COND(&MODE *EQ 'SNAP') THEN(GOTO CMDLBL(SNAP))
             IF         COND(&MODE *EQ 'OLD3') THEN(GOTO CMDLBL(OLD3))
             IF         COND(&MODE *NE 'CMD') THEN(DO)
                SNDPGMMSG  MSG('LGLRUN: unknown MODE - nothing run.')
                RETURN
             ENDDO

/* --- CMD mode: TXLEGACY LIB(x) [LANG(y)] [FORCE(z)] --- */
             CHGVAR     VAR(&CMD) VALUE(%TRIM(&TGT) *TCAT +
                          '/TXLEGACY LIB(' *TCAT %TRIM(&TGT) *TCAT ')')
             IF         COND(&LANG *NE 'OMIT') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&CMD) *TCAT ' LANG(' *TCAT +
                          %TRIM(&LANG) *TCAT ')'))
             IF         COND(&FORCE *NE 'OMIT') THEN(CHGVAR VAR(&CMD) +
                          VALUE(%TRIM(&CMD) *TCAT ' FORCE(' *TCAT +
                          %TRIM(&FORCE) *TCAT ')'))
             SNDPGMMSG  MSG('LGLRUN: ' *CAT %TRIM(&TAG) *CAT ' running ' +
                          *CAT %TRIM(&CMD))
             CHGVAR     VAR(&CMDLEN) VALUE(100)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('LGLRUN: ' *CAT +
                          %TRIM(&TAG) *CAT ' the command ended with an +
                          escape message. See job log.'))
             SNDPGMMSG  MSG('LGLRUN: ' *CAT %TRIM(&TAG) *CAT ' returned.')
             RETURN

/* --- OLD3 mode: an old-style caller with three parameters --- */
OLD3:        CHGVAR     VAR(&CLONEDIR) VALUE(' ')
             SNDPGMMSG  MSG('LGLRUN: ' *CAT %TRIM(&TAG) *CAT ' calling the +
                          TXLEGACY program with 3 parameters, FORCE=' *CAT +
                          &FORCE)
             CALL       PGM(&TGT/TXLEGACY) PARM(&TGT &CLONEDIR &FORCE)
             MONMSG     MSGID(CPF0000 MCH0000) EXEC(SNDPGMMSG MSG('LGLRUN: ' +
                          *CAT %TRIM(&TAG) *CAT ' the 3-parameter call +
                          ended with an escape message. See job log.'))
             SNDPGMMSG  MSG('LGLRUN: ' *CAT %TRIM(&TAG) *CAT ' returned.')
             RETURN

/* --- SNAP mode: TXLEGLNG / TXLEGST values, as a message --- */
SNAP:        RTVDTAARA  DTAARA(&TGT/TXLEGLNG (1 7)) RTNVAR(&LNG)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&LNG) +
                          VALUE('(none)'))
             RTVDTAARA  DTAARA(&TGT/TXLEGST (1 1)) RTNVAR(&ST)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&ST) VALUE('-'))
             SNDPGMMSG  MSG('LGLRUN: ' *CAT %TRIM(&TAG) *CAT ' TXLEGLNG=[' +
                          *CAT &LNG *CAT '] TXLEGST=[' *CAT &ST *CAT ']')

             ENDPGM
