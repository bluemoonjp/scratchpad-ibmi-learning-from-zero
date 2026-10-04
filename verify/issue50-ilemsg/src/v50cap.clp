/* V50CAP - verify/issue50-ilemsg helper, NOT part of the curriculum.     */
/* Submitted with SBMJOB (INQMSGRPY(*DFT)). Runs ONE program and then     */
/* copies what that job produced INSIDE the same job (the only routes     */
/* proven in part10-01-incident): the job log through JOBLOG_INFO('*')    */
/* and, for WHAT=ZAT only, the printed output through CPYSPLF JOB(*).     */
/* Job log copies go to two tables made by the wrapper:                   */
/*   JT      TAG, SEQ, MID, TXT           (the form that worked)          */
/*   JT||X   TAG, SEQ, MTYPE, SEV, FPGM, FINS, TPGM, TINS, MID            */
/* PARM:                                                                  */
/*   TAG   up to 6 characters, becomes part of the file name VFYP<TAG>    */
/*   LIB   library holding the programs and the tables                    */
/*   WHAT  ZAT  CALL JU0900C PARM('*TEST' lib)                            */
/*         NB1  CALL V50NB1 (CALL to a missing program, no error ind.)    */
/*         NB2  CALL V50NB2 (CALL to a callee that divides by zero)       */
/*   JT    name of the job log table (10 chars); JT||X must exist too     */
/* The call is monitored for CPF, MCH, RNQ, RNX and CEE escapes, so the   */
/* job log copy is made even when an ILE escape leaves the called pgm.    */
             PGM        PARM(&TAG &LIB &WHAT &JT)

             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&WHAT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&JT) TYPE(*CHAR) LEN(10)
             DCL        VAR(&PF) TYPE(*CHAR) LEN(10)

             CHGVAR     VAR(&PF) VALUE('VFYP' *CAT %TRIM(&TAG))
             IF         COND(&WHAT *NE 'ZAT') THEN(GOTO CMDLBL(RUN))
             DLTF       FILE(&LIB/&PF)
             MONMSG     MSGID(CPF0000)
             CRTPF      FILE(&LIB/&PF) RCDLEN(133) TEXT('verify capture')
             MONMSG     MSGID(CPF0000)

RUN:         IF         COND(&WHAT *EQ 'ZAT') THEN(DO)
                CALL       PGM(&LIB/JU0900C) PARM('*TEST' &LIB)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'NB1') THEN(DO)
                CALL       PGM(&LIB/V50NB1)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             IF         COND(&WHAT *EQ 'NB2') THEN(DO)
                CALL       PGM(&LIB/V50NB2)
                MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 +
                             CEE0000) EXEC(GOTO CMDLBL(ESC))
                GOTO       CMDLBL(OKEND)
             ENDDO
             SNDPGMMSG  MSG('V50CAP: unknown WHAT value.')
             GOTO       CMDLBL(CAPT)

OKEND:       SNDPGMMSG  MSG('V50CAP: the call ended normally.')
             GOTO       CMDLBL(CAPT)
ESC:         SNDPGMMSG  MSG('V50CAP: the call ended with an escape +
                          message.')

CAPT:        IF         COND(&WHAT *NE 'ZAT') THEN(GOTO CMDLBL(JLOG))
             CPYSPLF    FILE(QSYSPRT) TOFILE(&LIB/&PF) JOB(*) +
                          SPLNBR(*LAST) CTLCHAR(*NONE) MBROPT(*REPLACE)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('V50CAP: CPYSPLF of QSYSPRT failed.')
             ENDDO

JLOG:        RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT '/' *CAT +
                          %TRIM(&JT) *CAT ' SELECT ''' *CAT +
                          %TRIM(&TAG) *CAT ''', ORDINAL_POSITION, +
                          MESSAGE_ID, SUBSTR(MESSAGE_TEXT, 1, 200) FROM +
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
