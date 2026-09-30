/* ZA0STMB - verify/part10-03-modernize helper, NOT part of the         */
/* curriculum. Finds out which CRTSQLRPGI spelling works for a stream    */
/* file source, WITHOUT touching the real ZA0500: every try builds a     */
/* scratch program named ZA0STM and deletes it again.                    */
/*                                                                        */
/* Why the tries go through QCMDEXC: the lesson line in the design       */
/* (part10-design-v3 B4) says TGTCCSID(*JOB) and BNDDIR(ZAISRVBD) on     */
/* CRTSQLRPGI. The command reference in work/design/refs lists neither   */
/* keyword for CRTSQLRPGI (it lists CVTCCSID and COMPILEOPT). A wrong    */
/* keyword is a compile-time error (CPD0043) for a CL program, which     */
/* would cost the whole connection, so each spelling is a run-time       */
/* string here and its result is one message in the job log:             */
/*   TRY-A  the design line (TGTCCSID + BNDDIR keywords)                 */
/*   TRY-B  CVTCCSID(*JOB), the documented UTF-8 source conversion       */
/*   TRY-C  CVTCCSID(*JOB) plus COMPILEOPT('TGTCCSID(*JOB)')             */
/* The binding directory is not on any of these lines: the source has    */
/* ctl-opt bnddir('ZAISRVBD').                                           */
/*                                                                        */
/* A stream file path needs the real user name, which a cl step of the   */
/* harness cannot expand, and the SQL precompile needs the work library  */
/* on the library list, which a qsh system() call does not have. So the  */
/* path is built from CURUSER (same idea as TXLEGACY) and the library    */
/* list is the wrapper's own. The scratch directory must exist (an sh    */
/* step creates it).                                                     */
/*                                                                        */
/* PARM: LIB  work library holding QRPGLESRC(ZA0500) and ZAISRVBD.       */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&STMF) TYPE(*CHAR) LEN(200)
             DCL        VAR(&FROMMBR) TYPE(*CHAR) LEN(100)
             DCL        VAR(&HEAD) TYPE(*CHAR) LEN(200)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(500)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5) VALUE(500)

             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             RTVJOBA    CURUSER(&USR)
             CHGVAR     VAR(&STMF) VALUE('/home/' *TCAT %TRIM(&USR) *TCAT +
                          '/vfy/part10-03-modernize/stmf/za0500s.sqlrpgle')
             CHGVAR     VAR(&FROMMBR) VALUE('/QSYS.LIB/' *TCAT %TRIM(&LIB) +
                          *TCAT '.LIB/QRPGLESRC.FILE/ZA0500.MBR')

             CPYTOSTMF  FROMMBR(&FROMMBR) TOSTMF(&STMF) STMFOPT(*REPLACE) +
                          STMFCCSID(1208) ENDLINFMT(*LF)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0STMB: CPYTOSTMF FAILED')
                RETURN
             ENDDO

/* Common start of every try.                                            */
             CHGVAR     VAR(&HEAD) VALUE('CRTSQLRPGI OBJ(' *TCAT %TRIM(&LIB) +
                          *TCAT '/ZA0STM) SRCSTMF(''' *TCAT %TRIM(&STMF) +
                          *TCAT ''') OBJTYPE(*PGM) COMMIT(*NONE) ')

/* TRY-A: the design line.                                               */
             CHGVAR     VAR(&CMD) VALUE(%TRIM(&HEAD) *BCAT 'TGTCCSID(*JOB) +
                          BNDDIR(ZAISRVBD) REPLACE(*YES)')
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000 SQL0000 RNF0000 MCH0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0STMB: TRY-A design line FAILED')
                GOTO       CMDLBL(TRYB)
             ENDDO
             SNDPGMMSG  MSG('ZA0STMB: TRY-A design line OK')
             DLTPGM     PGM(&LIB/ZA0STM)
             MONMSG     MSGID(CPF0000)

/* TRY-B: documented conversion keyword.                                 */
TRYB:        CHGVAR     VAR(&CMD) VALUE(%TRIM(&HEAD) *BCAT 'CVTCCSID(*JOB) +
                          REPLACE(*YES)')
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000 SQL0000 RNF0000 MCH0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0STMB: TRY-B CVTCCSID FAILED')
                GOTO       CMDLBL(TRYC)
             ENDDO
             SNDPGMMSG  MSG('ZA0STMB: TRY-B CVTCCSID OK')
             DLTPGM     PGM(&LIB/ZA0STM)
             MONMSG     MSGID(CPF0000)

/* TRY-C: conversion keyword plus compiler options.                      */
TRYC:        CHGVAR     VAR(&CMD) VALUE(%TRIM(&HEAD) *BCAT 'CVTCCSID(*JOB) +
                          COMPILEOPT(''TGTCCSID(*JOB)'') REPLACE(*YES)')
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000 SQL0000 RNF0000 MCH0000) EXEC(DO)
                SNDPGMMSG  MSG('ZA0STMB: TRY-C COMPILEOPT FAILED')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('ZA0STMB: TRY-C COMPILEOPT OK')
             DLTPGM     PGM(&LIB/ZA0STM)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('ZA0STMB: stopped on an unexpected error.') +
                          MSGTYPE(*COMP)

             ENDPGM
