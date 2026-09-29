/* C0906B - exercise (b) of lesson 09-06: C0906A plus a PING request.    */
/* NOT run on a real machine (unverified as of 2026-09-29). Compile it as */
/* member and program C0906B, submit C0906B instead of C0906A.            */
/*                                                                        */
/* Reads requests from data queue Z0906A, answers on data queue Z0906B,   */
/* writes one row per milestone into table W0906A and tells message queue  */
/* Z0906C what it is doing. Same skeleton as JUYAKC (03-13) and JUYAKL     */
/* (07-04): pre / main / post / error.                                    */
/*                                                                        */
/* The job always ends by itself:                                         */
/*   - an END request ends it,                                            */
/*   - at most MAXMSG requests are handled,                               */
/*   - at most MAXIDLE empty waits (WAITSEC seconds each) in TOTAL: a wait  */
/*     that ends with a request does not reset the count.                 */
/* With the values below the job waits two minutes in total at the most,  */
/* plus the time to answer at most ten requests.                          */
/* It is submitted by hand, once. Never resident, never scheduled.        */
/*                                                                        */
/* Submit it (mylib = your development library):                          */
/*   SBMJOB CMD(CALL PGM(mylib/C0906B) PARM('mylib')) JOB(C0906B) +       */
/*            JOBQ(QGPL/QBATCH) CURLIB(mylib) INLLIBL(*JOBD) +          */
/*            INQMSGRPY(*DFT) +                                          */
/*            LOG(4 00 *SECLVL)                                           */
/* PARM: the library that holds the queues, the log table and ZAIKOM.     */
/* No library name is written in this source.                             */
/*                                                                        */
/* Requests (128 bytes at most, the first word decides):                  */
/*   ECHO text     reply: ECHO text                                       */
/*   EXIST name    reply: EXIST name FOUND, or EXIST name MISSING         */
/*   STOCK pcode   logs the ZAIKOM quantity, reply: STOCK pcode LOGGED    */
/*   PING          reply: PONG (exercise b)                               */
/*   END           reply: BYE reason count, then the job ends             */
/* Anything else is answered with UNKNOWN and the request text.           */
/* No request may contain a single quote: every request is pasted into    */
/* the SQL of the log statement (STOCK pastes its code as well).          */
/*                                                                        */
/* Note: CL cannot SELECT INTO a variable, so the stock quantity is       */
/* written to the log table by SQL and not returned in the reply.         */
             PGM        PARM(&LIBP)

             DCL        VAR(&LIBP) TYPE(*CHAR) LEN(32)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&QIN) TYPE(*CHAR) LEN(10) VALUE('Z0906A')
             DCL        VAR(&QOUT) TYPE(*CHAR) LEN(10) VALUE('Z0906B')
             DCL        VAR(&JOB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&NBR) TYPE(*CHAR) LEN(6)
             DCL        VAR(&DATA) TYPE(*CHAR) LEN(128)
             DCL        VAR(&REPLY) TYPE(*CHAR) LEN(128)
             DCL        VAR(&DLEN) TYPE(*DEC) LEN(5 0)
             DCL        VAR(&RLEN) TYPE(*DEC) LEN(5 0) VALUE(128)
             DCL        VAR(&WAITSEC) TYPE(*DEC) LEN(5 0) VALUE(20)
             DCL        VAR(&MAXMSG) TYPE(*DEC) LEN(5 0) VALUE(10)
             DCL        VAR(&MAXIDLE) TYPE(*DEC) LEN(5 0) VALUE(6)
             DCL        VAR(&HANDLED) TYPE(*DEC) LEN(5 0) VALUE(0)
             DCL        VAR(&IDLE) TYPE(*DEC) LEN(5 0) VALUE(0)
             DCL        VAR(&ARG) TYPE(*CHAR) LEN(20)
             DCL        VAR(&OBJ) TYPE(*CHAR) LEN(10)
             DCL        VAR(&WHY) TYPE(*CHAR) LEN(8) VALUE('MAX')
             DCL        VAR(&NUM) TYPE(*CHAR) LEN(5)
             DCL        VAR(&PHASE) TYPE(*CHAR) LEN(8)
             DCL        VAR(&LMSG) TYPE(*CHAR) LEN(90)
             DCL        VAR(&SQL) TYPE(*CHAR) LEN(400)
             DCL        VAR(&STOP) TYPE(*LGL) LEN(1) VALUE('0')
             DCL        VAR(&INERR) TYPE(*LGL) LEN(1) VALUE('0')

             MONMSG     MSGID(CPF0000 MCH0000) EXEC(GOTO CMDLBL(FAILED))

             CHGVAR     VAR(&LIB) VALUE(%SST(&LIBP 1 10))
             RTVJOBA    JOB(&JOB) USER(&USR) NBR(&NBR)

/* --- Pre: say that we are alive --- */
             CALLSUBR   SUBR(PRE)

/* --- Main: one request per turn --- */
NXTREQ:      IF         COND(&HANDLED *GE &MAXMSG) THEN(DO)
                CHGVAR     VAR(&WHY) VALUE('MAX')
                GOTO       CMDLBL(DONE)
             ENDDO
             IF         COND(&IDLE *GE &MAXIDLE) THEN(DO)
                CHGVAR     VAR(&WHY) VALUE('IDLE')
                GOTO       CMDLBL(DONE)
             ENDDO

/* A returned length of 0 means: the wait time ran out, nothing came.   */
             CHGVAR     VAR(&DLEN) VALUE(0)
             CHGVAR     VAR(&DATA) VALUE(' ')
             CALL       PGM(QRCVDTAQ) PARM(&QIN &LIB &DLEN &DATA &WAITSEC)

             IF         COND(&DLEN *EQ 0) THEN(DO)
                CHGVAR     VAR(&IDLE) VALUE(&IDLE + 1)
                CHGVAR     VAR(&NUM) VALUE(&IDLE)
                CHGVAR     VAR(&PHASE) VALUE('WAIT')
                CHGVAR     VAR(&LMSG) VALUE('timeout, empty waits so far ' +
                             *CAT &NUM)
                CALLSUBR   SUBR(LOG)
                GOTO       CMDLBL(NXTREQ)
             ENDDO

             CHGVAR     VAR(&HANDLED) VALUE(&HANDLED + 1)
             CALLSUBR   SUBR(MAIN)
             IF         COND(&STOP) THEN(DO)
                CHGVAR     VAR(&WHY) VALUE('END')
                GOTO       CMDLBL(DONE)
             ENDDO
             GOTO       CMDLBL(NXTREQ)

/* --- Post: log first, answer BYE last (the caller waits for BYE) --- */
DONE:        CALLSUBR   SUBR(POST)
             RETURN

/* --- Error: log and notify, then end quietly (no escape message) --- */
FAILED:      IF         COND(&INERR) THEN(RETURN)
             CHGVAR     VAR(&INERR) VALUE('1')
             CALLSUBR   SUBR(ERRSUBR)
             RETURN

/* ===== Pre ============================================================ */
             SUBR       SUBR(PRE)
                CHGVAR     VAR(&PHASE) VALUE('PRE')
                CHGVAR     VAR(&LMSG) VALUE('start job ' *CAT &NBR *CAT +
                             '/' *CAT %TRIM(&USR) *CAT '/' *CAT +
                             %TRIM(&JOB))
                CALLSUBR   SUBR(LOG)
             ENDSUBR

/* ===== Main: answer one request ======================================= */
             SUBR       SUBR(MAIN)
                CHGVAR     VAR(&REPLY) VALUE('UNKNOWN' *BCAT +
                             %SST(&DATA 1 40))

                IF         COND(%SST(&DATA 1 4) *EQ 'ECHO') THEN(DO)
                   CHGVAR     VAR(&ARG) VALUE(%SST(&DATA 6 20))
                   CHGVAR     VAR(&REPLY) VALUE('ECHO' *BCAT &ARG)
                ENDDO

                IF         COND(%SST(&DATA 1 4) *EQ 'PING') THEN(DO)
                   CHGVAR     VAR(&REPLY) VALUE('PONG')
                ENDDO

                IF         COND(%SST(&DATA 1 5) *EQ 'EXIST') THEN(DO)
                   CHGVAR     VAR(&OBJ) VALUE(%SST(&DATA 7 10))
                   CHGVAR     VAR(&REPLY) VALUE('EXIST' *BCAT &OBJ *BCAT +
                                'FOUND')
                   CHKOBJ     OBJ(&LIB/&OBJ) OBJTYPE(*FILE)
                   MONMSG     MSGID(CPF9801) EXEC(CHGVAR VAR(&REPLY) +
                                VALUE('EXIST' *BCAT &OBJ *BCAT 'MISSING'))
                ENDDO

                IF         COND(%SST(&DATA 1 5) *EQ 'STOCK') THEN(DO)
                   CHGVAR     VAR(&ARG) VALUE(%SST(&DATA 7 6))
                   CHGVAR     VAR(&SQL) VALUE('INSERT INTO ' *CAT +
                                %TRIM(&LIB) *CAT '/W0906A (PHASE, MSG) +
                                SELECT ''STOCK'', ''STOCK ' *CAT +
                                %TRIM(&ARG) *CAT ' QTY='' CONCAT CAST(+
                                INT(ZASU) AS VARCHAR(9)) FROM ' *CAT +
                                %TRIM(&LIB) *CAT '/ZAIKOM WHERE ZASHO = +
                                ''' *CAT %TRIM(&ARG) *CAT '''')
                   RUNSQL     SQL(&SQL) COMMIT(*NONE)
                   MONMSG     MSGID(CPF0000 SQL0000) EXEC(DO)
                      SNDPGMMSG  MSG('C0906A: stock lookup failed') +
                                   TOMSGQ(&LIB/Z0906C) MSGTYPE(*INFO)
                      MONMSG     MSGID(CPF0000)
                   ENDDO
                   CHGVAR     VAR(&REPLY) VALUE('STOCK' *BCAT &ARG *BCAT +
                                'LOGGED')
                ENDDO

                IF         COND(%SST(&DATA 1 3) *EQ 'END') THEN(DO)
                   CHGVAR     VAR(&STOP) VALUE('1')
                   CHGVAR     VAR(&REPLY) VALUE('BYE')
                ENDDO

                CHGVAR     VAR(&PHASE) VALUE('MAIN')
                CHGVAR     VAR(&LMSG) VALUE('req=' *CAT %SST(&DATA 1 30) +
                             *BCAT 'reply=' *CAT %SST(&REPLY 1 40))
                CALLSUBR   SUBR(LOG)

/* The BYE answer of an END request is sent by the post phase.           */
                IF         COND(*NOT &STOP) THEN(DO)
                   CALL       PGM(QSNDDTAQ) PARM(&QOUT &LIB &RLEN &REPLY)
                ENDDO
             ENDSUBR

/* ===== Post =========================================================== */
             SUBR       SUBR(POST)
                CHGVAR     VAR(&NUM) VALUE(&HANDLED)
                CHGVAR     VAR(&PHASE) VALUE('POST')
                CHGVAR     VAR(&LMSG) VALUE('end why=' *CAT &WHY *BCAT +
                             'handled=' *CAT &NUM)
                CALLSUBR   SUBR(LOG)
                CHGVAR     VAR(&REPLY) VALUE('BYE' *BCAT &WHY *BCAT &NUM)
                CALL       PGM(QSNDDTAQ) PARM(&QOUT &LIB &RLEN &REPLY)
             ENDSUBR

/* ===== Error ========================================================== */
             SUBR       SUBR(ERRSUBR)
                CHGVAR     VAR(&PHASE) VALUE('ERROR')
                CHGVAR     VAR(&LMSG) VALUE('worker failed, see the job +
                             log')
                CALLSUBR   SUBR(LOG)
                CHGVAR     VAR(&REPLY) VALUE('ERROR worker failed')
                CALL       PGM(QSNDDTAQ) PARM(&QOUT &LIB &RLEN &REPLY)
                MONMSG     MSGID(CPF0000 MCH0000)
             ENDSUBR

/* ===== Log: one table row and one message for the learner ============ */
/* Every command has its own MONMSG so that a failing log never stops   */
/* the worker (and the error path can never loop).                       */
             SUBR       SUBR(LOG)
                CHGVAR     VAR(&SQL) VALUE('INSERT INTO ' *CAT +
                             %TRIM(&LIB) *CAT '/W0906A (PHASE, MSG) +
                             VALUES(''' *CAT %TRIM(&PHASE) *CAT ''', ''' +
                             *CAT %TRIM(&LMSG) *CAT ''')')
                RUNSQL     SQL(&SQL) COMMIT(*NONE)
                MONMSG     MSGID(CPF0000 SQL0000)
                SNDPGMMSG  MSG('C0906A' *BCAT %TRIM(&PHASE) *BCAT +
                             %TRIM(&LMSG)) +
                             TOMSGQ(&LIB/Z0906C) MSGTYPE(*INFO)
                MONMSG     MSGID(CPF0000)
             ENDSUBR

             ENDPGM
