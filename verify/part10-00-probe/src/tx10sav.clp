/* TX10SAV - verify/part10-00-probe helper, NOT part of the curriculum.   */
/* Looks for the dated backup SAVF that TXLEGACY FORCE(*YES) names        */
/* LG<QDATE> (tools/qclsrc/txlegacy.clp builds the name the same way, in  */
/* the library <profile>B) and prints its contents.                       */
/*                                                                        */
/* PARM: LIBB (the library that should hold the SAVF, <=10 chars).        */
/* Called from an sh step (own job) so that DSPSAVF OUTPUT(*PRINT) comes  */
/* back in the qsh output (see docs/probes.md, DSPSAVF finding).          */
             PGM        PARM(&LIBB)

             DCL        VAR(&LIBB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&DATE) TYPE(*CHAR) LEN(6)
             DCL        VAR(&SAVF) TYPE(*CHAR) LEN(10)

             RTVSYSVAL  SYSVAL(QDATE) RTNVAR(&DATE)
             CHGVAR     VAR(&SAVF) VALUE('LG' *TCAT &DATE)
             CHKOBJ     OBJ(&LIBB/&SAVF) OBJTYPE(*FILE)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                SNDPGMMSG  MSG('TX10SAV: no SAVF named ' *CAT &SAVF *CAT +
                             ' in ' *CAT &LIBB)
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TX10SAV: SAVF exists: ' *CAT &LIBB *CAT '/' +
                          *CAT &SAVF)
             DSPSAVF    FILE(&LIBB/&SAVF) OUTPUT(*PRINT)
             MONMSG     MSGID(CPF0000) EXEC(SNDPGMMSG MSG('TX10SAV: +
                          DSPSAVF failed. See job log.'))

             ENDPGM
