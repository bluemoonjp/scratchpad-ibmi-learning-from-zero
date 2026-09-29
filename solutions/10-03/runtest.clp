/* RUNTEST - one-command regression for lesson 10-03 (Capstone D).       */
/*                                                                        */
/* Runs TSTJUCSRV, TSTZAISRV and TSTZA0500 in ONE job, then counts the   */
/* PASS and FAIL rows in TESTRES and sends one summary message:          */
/*   RUNTEST: PASS=nnnnnnnnnn FAIL=nnnnnnnnnn                            */
/* It does not send an escape message, so a failing test never stops     */
/* the caller. Read the FAIL count.                                      */
/*                                                                        */
/* Order matters, and each step exists for a reason:                     */
/*  1. CHGCURLIB first. TESTKIT creates TESTRES with an unqualified      */
/*     CREATE TABLE, which lands in the current library.                 */
/*  2. DELETE FROM TESTRES first. testInit() only creates the table; it  */
/*     never clears it, so old rows would be counted again.              */
/*  3. ZAIKOM is copied to QTEMP and redirected with OVRDBF              */
/*     OVRSCOPE(*JOB), so no test touches the shared ZAIKOM. QTEMP and   */
/*     the override live only in this job, so all three tests must be    */
/*     called from here (08-04 isolation trick).                         */
/*                                                                        */
/* PARM:                                                                  */
/*   LIB   work library holding the programs and TESTRES. Blank means    */
/*         the current library of the job.                                */
/*                                                                        */
/* Expected today: 23 assertions from TSTJUCSRV and TSTZAISRV plus the   */
/* TSTZA0500 assertions. FAIL must be 0.                                  */
/* STATUS: UNVERIFIED (2026-09-30).                                       */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&SQL) TYPE(*CHAR) LEN(200)
             DCL        VAR(&NPASS) TYPE(*DEC) LEN(10 0) VALUE(0)
             DCL        VAR(&NFAIL) TYPE(*DEC) LEN(10 0) VALUE(0)
             DCL        VAR(&TPASS) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TFAIL) TYPE(*CHAR) LEN(10)

             /* Safety net: an unmonitored escape must not hang a batch  */
             /* job. See tools/qclsrc/txsetup.clp.                       */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LIB *EQ ' ' *OR &LIB *EQ '*CURLIB') +
                          THEN(RTVJOBA CURLIB(&LIB))
             IF         COND(&LIB *EQ '*NONE') THEN(DO)
                SNDPGMMSG  MSG('RUNTEST: no library given and the job has +
                             no current library.')
                RETURN
             ENDDO

/* 1. Current library first, then make the work library reachable.       */
             CHGCURLIB  CURLIB(&LIB)
             ADDLIBLE   LIB(&LIB) POSITION(*FIRST)
             MONMSG     MSGID(CPF2103)

/* 2. Clear old results. The table may not exist on the first run.       */
             CHGVAR     VAR(&SQL) VALUE('DELETE FROM ' *TCAT %TRIM(&LIB) +
                          *TCAT '/TESTRES')
             RUNSQL     SQL(&SQL) COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000)

/* 3. Isolate ZAIKOM. Seed one row with a value the real table does not  */
/*    have, so the results themselves show which table was opened.       */
             DLTF       FILE(QTEMP/ZAIKOM)
             MONMSG     MSGID(CPF0000)
             CRTDUPOBJ  OBJ(ZAIKOM) FROMLIB(&LIB) OBJTYPE(*FILE) +
                          TOLIB(QTEMP) DATA(*YES)
             CHGVAR     VAR(&SQL) VALUE('UPDATE QTEMP/ZAIKOM SET ZASU = 7 +
                          WHERE ZASHO = ''P00001''')
             RUNSQL     SQL(&SQL) COMMIT(*NONE)
             OVRDBF     FILE(ZAIKOM) TOFILE(QTEMP/ZAIKOM) WAITRCD(3) +
                          OVRSCOPE(*JOB)

/* 4. The three test programs, one job. A test that ends with an error   */
/*    is reported and the run continues.                                  */
             CALL       PGM(&LIB/TSTJUCSRV)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 CEE0000) +
                          EXEC(SNDPGMMSG MSG('RUNTEST: TSTJUCSRV ended +
                          with an error.'))
             CALL       PGM(&LIB/TSTZAISRV)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 CEE0000) +
                          EXEC(SNDPGMMSG MSG('RUNTEST: TSTZAISRV ended +
                          with an error.'))
             CALL       PGM(&LIB/TSTZA0500)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000 CEE0000) +
                          EXEC(SNDPGMMSG MSG('RUNTEST: TSTZA0500 ended +
                          with an error.'))

/* 5. Put the job back the way it was found.                             */
             DLTOVR     FILE(ZAIKOM) LVL(*JOB)
             MONMSG     MSGID(CPF0000)
             DLTF       FILE(QTEMP/ZAIKOM)
             MONMSG     MSGID(CPF0000)

/* 6. Count. Two small QTEMP tables, then RTVMBRD reads their sizes.     */
             CHGVAR     VAR(&SQL) VALUE('CREATE OR REPLACE TABLE +
                          QTEMP/TRPASS AS (SELECT * FROM ' *TCAT +
                          %TRIM(&LIB) *TCAT '/TESTRES WHERE RESULT = +
                          ''PASS'') WITH DATA')
             RUNSQL     SQL(&SQL) COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000)
             RTVMBRD    FILE(QTEMP/TRPASS) NBRCURRCD(&NPASS)
             MONMSG     MSGID(CPF0000)
             CHGVAR     VAR(&SQL) VALUE('CREATE OR REPLACE TABLE +
                          QTEMP/TRFAIL AS (SELECT * FROM ' *TCAT +
                          %TRIM(&LIB) *TCAT '/TESTRES WHERE RESULT <> +
                          ''PASS'') WITH DATA')
             RUNSQL     SQL(&SQL) COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000)
             RTVMBRD    FILE(QTEMP/TRFAIL) NBRCURRCD(&NFAIL)
             MONMSG     MSGID(CPF0000)

             IF         COND(&NPASS *EQ 0 *AND &NFAIL *EQ 0) THEN(DO)
                SNDPGMMSG  MSG('RUNTEST: no rows in TESTRES. The tests did +
                             not run or TESTRES is in another library.')
                RETURN
             ENDDO

             CHGVAR     VAR(&TPASS) VALUE(&NPASS)
             CHGVAR     VAR(&TFAIL) VALUE(&NFAIL)
             SNDPGMMSG  MSG('RUNTEST: PASS=' *CAT &TPASS *CAT ' FAIL=' +
                          *CAT &TFAIL) MSGTYPE(*COMP)
             RETURN

FAILSAFE:    DLTOVR     FILE(ZAIKOM) LVL(*JOB)
             MONMSG     MSGID(CPF0000)
             SNDPGMMSG  MSG('RUNTEST: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
