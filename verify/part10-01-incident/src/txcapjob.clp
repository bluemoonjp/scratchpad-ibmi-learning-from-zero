/* TXCAPJOB - verify/part10-01-incident helper, NOT part of the           */
/* curriculum. Submitted with SBMJOB; runs JU0900C in *TEST mode (the     */
/* same call the lesson makes: CALL JU0900C PARM('*TEST' lib)) and then   */
/* keeps two copies of what that job produced, INSIDE the same job, so    */
/* no job number has to be looked up from another job:                    */
/*   1. its printed output: CPYSPLF FILE(QSYSPRT) JOB(*) SPLNBR(*LAST)    */
/*      into the physical file VFYP<TAG> (created by the wrapper, record  */
/*      length 133, same form as verify/part06-01-cvtrpgsrc). Whether a   */
/*      spooled file exists at all after the failing run is part of the   */
/*      finding: a CPYSPLF failure is reported as a message, and its      */
/*      message id shows in the job log copy below.                       */
/*   2. its job log: JOBLOG_INFO('*') into VFYJ10. First the proven form  */
/*      (ORDINAL_POSITION and MESSAGE_TEXT, as verify/lib/clgen.mjs), tag */
/*      = TAG. Then, as a separate statement so a wrong column name can   */
/*      not lose the first copy, a variant with MESSAGE_ID, tag = TAG     */
/*      with -ID appended.                                                */
/* PARM: TAG (10 chars, for example BASE, FAIL, FIXD; keep it under 7    */
/* characters), LIB (10 chars, library holding JU0900C, VFYJ10, VFYPxxxx).*/
/* JU0900C's own MONMSG handles the ZA0500 failure, so this program      */
/* normally ends normally.                                                */
             PGM        PARM(&TAG &LIB)

             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&PF) TYPE(*CHAR) LEN(10)

             CALL       PGM(&LIB/JU0900C) PARM('*TEST' &LIB)
             MONMSG     MSGID(CPF0000)

             CHGVAR     VAR(&PF) VALUE('VFYP' *CAT %TRIM(&TAG))
             CPYSPLF    FILE(QSYSPRT) TOFILE(&LIB/&PF) JOB(*) +
                          SPLNBR(*LAST) CTLCHAR(*NONE) MBROPT(*REPLACE)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPJOB: CPYSPLF of QSYSPRT failed.')
             ENDDO

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/VFYJ10 (TAG, SEQ, TXT) SELECT ''' *CAT +
                          %TRIM(&TAG) *CAT ''', ORDINAL_POSITION, +
                          SUBSTR(MESSAGE_TEXT, 1, 200) FROM +
                          TABLE(QSYS2.JOBLOG_INFO(''*'')) X') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/VFYJ10 SELECT ''' *CAT %TRIM(&TAG) *CAT +
                          '-ID'', ORDINAL_POSITION, MESSAGE_ID, +
                          SUBSTR(MESSAGE_TEXT, 1, 200) FROM +
                          TABLE(QSYS2.JOBLOG_INFO(''*'')) X') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             ENDPGM
