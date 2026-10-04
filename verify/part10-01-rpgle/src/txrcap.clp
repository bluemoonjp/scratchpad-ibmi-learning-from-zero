/* TXRCAP - verify/part10-0x-rpgle helper, NOT part of the curriculum.    */
/* Submitted with SBMJOB. Runs one program of the legacy system and then  */
/* keeps two copies of what that job produced, INSIDE the same job (the   */
/* only routes proven in part10-01-incident: CPYSPLF JOB(*) and           */
/* JOBLOG_INFO('*')):                                                      */
/*   1. its printed output: CPYSPLF FILE(QSYSPRT) JOB(*) SPLNBR(*LAST)    */
/*      into the physical file VFYP<TAG> (created here, record length    */
/*      133). A failed CPYSPLF is reported as a message; its id in the   */
/*      job log copy says whether any spooled file existed.              */
/*   2. its job log, three INSERT statements into tables made by the     */
/*      wrapper, so a wrong guessed column name cannot lose the others:  */
/*      a. table JT: TAG, SEQ, TXT (ORDINAL_POSITION, MESSAGE_TEXT -     */
/*         the proven form).                                              */
/*      b. table JT: TAG with '-ID' appended, SEQ, MID, TXT (adds         */
/*         MESSAGE_ID).                                                   */
/*      c. table JT with 'X' appended to its name (UNVERIFIED columns    */
/*         MESSAGE_TYPE, SEVERITY, FROM_PROGRAM, FROM_INSTRUCTION,       */
/*         TO_PROGRAM, TO_INSTRUCTION).                                   */
/* PARM:                                                                  */
/*   TAG   up to 6 characters, becomes part of the file name VFYP<TAG>   */
/*   LIB   library holding the programs and the tables                   */
/*   WHAT  ZAT    CALL JU0900C PARM('*TEST' lib)                          */
/*         ZAL    CALL JU0900C PARM('*LIVE' lib)                          */
/*         JU0300 CALL JU0300                                             */
/*         PROBE  CALL V10PRB (part10-02-rpgle probe)                    */
/*         TK0100 CALL TK0100 (display file program; run in batch only   */
/*                to see its messages, the wrapper ends the job)         */
/*   JT    name of the job log table (10 chars); JT||X must exist too    */
/* The call is monitored for CPF, MCH, RNQ, RNX and CEE escapes, so the   */
/* job log copy is made even when an ILE escape leaves the called program.*/
/* The message sent after the call says which way it ended.               */
             PGM        PARM(&TAG &LIB &WHAT &JT)

             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&JT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&PF) TYPE(*CHAR) LEN(10)

             CHGVAR     VAR(&PF) VALUE('VFYP' *CAT %TRIM(&TAG))
             DLTF       FILE(&LIB/&PF)
             MONMSG     MSGID(CPF0000)
             CRTPF      FILE(&LIB/&PF) RCDLEN(133) TEXT('verify capture')
             MONMSG     MSGID(CPF0000)

             IF         COND(&WHAT *EQ 'ZAT') THEN(DO)
                CALL       PGM(&LIB/JU0900C) PARM('*TEST' &LIB)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'ZAL') THEN(DO)
                CALL       PGM(&LIB/JU0900C) PARM('*LIVE' &LIB)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'JU0300') THEN(DO)
                CALL       PGM(&LIB/JU0300)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'PROBE') THEN(DO)
                CALL       PGM(&LIB/V10PRB)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'TK0100') THEN(DO)
                CALL       PGM(&LIB/TK0100)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             SNDPGMMSG  MSG('TXRCAP: unknown WHAT value.')
             GOTO       CMDLBL(CAPT)

OKEND:       SNDPGMMSG  MSG('TXRCAP: the call ended normally.')
             GOTO       CMDLBL(CAPT)
ESC:         SNDPGMMSG  MSG('TXRCAP: the call ended with an escape +
                          message.')

CAPT:        CPYSPLF    FILE(QSYSPRT) TOFILE(&LIB/&PF) JOB(*) +
                          SPLNBR(*LAST) CTLCHAR(*NONE) MBROPT(*REPLACE)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRCAP: CPYSPLF of QSYSPRT failed.')
             ENDDO

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT '/' *CAT +
                          %TRIM(&JT) *CAT ' (TAG, SEQ, TXT) SELECT ''' *CAT +
                          %TRIM(&TAG) *CAT ''', ORDINAL_POSITION, +
                          SUBSTR(MESSAGE_TEXT, 1, 200) FROM +
                          TABLE(QSYS2.JOBLOG_INFO(''*'')) X') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT '/' *CAT +
                          %TRIM(&JT) *CAT ' SELECT ''' *CAT %TRIM(&TAG) *CAT +
                          '-ID'', ORDINAL_POSITION, MESSAGE_ID, +
                          SUBSTR(MESSAGE_TEXT, 1, 200) FROM +
                          TABLE(QSYS2.JOBLOG_INFO(''*'')) X') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT '/' *CAT +
                          %TRIM(&JT) *CAT 'X SELECT ''' *CAT %TRIM(&TAG) *CAT +
                          ''', ORDINAL_POSITION, MESSAGE_TYPE, SEVERITY, +
                          FROM_PROGRAM, FROM_INSTRUCTION, TO_PROGRAM, +
                          TO_INSTRUCTION, MESSAGE_ID FROM +
                          TABLE(QSYS2.JOBLOG_INFO(''*'')) X') +
                          COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             ENDPGM
