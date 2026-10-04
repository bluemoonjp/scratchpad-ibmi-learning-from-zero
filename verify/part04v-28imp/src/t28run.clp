/* T28RUN - verify/part04v-28imp helper, NOT part of the curriculum.       */
/* Two modes, because the harness wrapper has no IF/GOTO between steps:    */
/*   MUT  if the gate row exists in VFY28G (DBVER 1, JUDLV absent, the     */
/*        three legacy RPG programs are still RPG III), flag the change in */
/*        QTEMP and compile JU0300/ZA0500/TK0100 from QRPGLE112 with       */
/*        CRTBNDRPG over the same names. Also builds JUCINQC from the      */
/*        03-09 source when the library does not have it yet (flag        */
/*        T28JIC), so the DCLF case of the lesson has a subject.           */
/*   RST  if the QTEMP flag exists, put the RPG III programs back with     */
/*        CRTRPGPGM from QRPGSRC (same call as TXLEGACY LOADRPG), delete   */
/*        a JUCINQC that this batch built, and run TXRESET.                */
/* Called as CALL PGM(lib/T28RUN) PARM('lib' 'MUT') and PARM('lib' 'RST'). */
/* The literals are far below 32 bytes, so the CALL padding trap does not  */
/* apply to the declared lengths below.                                    */
             PGM        PARM(&LIB &MODE)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&MODE) TYPE(*CHAR) LEN(3)
             DCL        VAR(&N) TYPE(*DEC) LEN(10 0)
             DCL        VAR(&CMD) TYPE(*CHAR) LEN(40)
             DCL        VAR(&CMDLEN) TYPE(*DEC) LEN(15 5)
             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB1) TYPE(*CHAR) LEN(11)

             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000) +
                          EXEC(GOTO CMDLBL(FAILSAFE))

/* Take <USER>1 off the library list (job scoped) so that unqualified    */
/* file names in the compiles below resolve in &LIB, not in <USER>1.      */
             RTVJOBA    CURUSER(&USR)
             CHGVAR     VAR(&LIB1) VALUE(%TRIM(&USR) *TCAT '1')
             RMVLIBLE   LIB(&LIB1)
             MONMSG     MSGID(CPF0000)

             IF         COND(&MODE *EQ 'MUT') THEN(GOTO CMDLBL(MUT))
             IF         COND(&MODE *EQ 'RST') THEN(GOTO CMDLBL(RST))
             SNDPGMMSG  MSG('T28RUN: unknown mode, nothing done.')
             RETURN

MUT:         RTVMBRD    FILE(&LIB/VFY28G) NBRCURRCD(&N)
             IF         COND(&N *EQ 0) THEN(DO)
                SNDPGMMSG  MSG('T28RUN: gate row missing, nothing changed.')
                RETURN
             ENDDO
             CRTDTAARA  DTAARA(QTEMP/T28MUT) TYPE(*CHAR) LEN(1) VALUE('Y')
             MONMSG     MSGID(CPF0000)
/* The gate also passes when the three programs do not exist at all   */
/* (cause unknown). Flag that, so RST deletes them    */
/* again instead of creating RPG III programs that were not there.    */
             CHKOBJ     OBJ(&LIB/JU0300) OBJTYPE(*PGM)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                CRTDTAARA  DTAARA(QTEMP/T28ABS) TYPE(*CHAR) LEN(1) +
                             VALUE('Y')
                MONMSG     MSGID(CPF0000)
             ENDDO
             CRTBNDRPG  PGM(&LIB/JU0300) SRCFILE(&LIB/QRPGLE112) +
                          SRCMBR(JU0300) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
             CRTBNDRPG  PGM(&LIB/ZA0500) SRCFILE(&LIB/QRPGLE112) +
                          SRCMBR(ZA0500) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
             CRTBNDRPG  PGM(&LIB/TK0100) SRCFILE(&LIB/QRPGLE112) +
                          SRCMBR(TK0100) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
             CHKOBJ     OBJ(&LIB/JUCINQC) OBJTYPE(*PGM)
             MONMSG     MSGID(CPF9801) EXEC(DO)
                CRTCLPGM   PGM(&LIB/JUCINQC) SRCFILE(&LIB/QCLSRC) +
                             SRCMBR(JUCINQC) REPLACE(*YES)
                MONMSG     MSGID(CPF0000)
                CRTDTAARA  DTAARA(QTEMP/T28JIC) TYPE(*CHAR) LEN(1) +
                             VALUE('Y')
                MONMSG     MSGID(CPF0000)
             ENDDO
             SNDPGMMSG  MSG('T28RUN: MUT done.')
             RETURN

RST:         CHKOBJ     OBJ(QTEMP/T28MUT) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('T28RUN: no flag, nothing to restore.')
                RETURN
             ENDDO
             CHKOBJ     OBJ(QTEMP/T28ABS) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF9801) EXEC(GOTO CMDLBL(RSTRPG))
             DLTPGM     PGM(&LIB/JU0300)
             MONMSG     MSGID(CPF0000)
             DLTPGM     PGM(&LIB/ZA0500)
             MONMSG     MSGID(CPF0000)
             DLTPGM     PGM(&LIB/TK0100)
             MONMSG     MSGID(CPF0000)
             GOTO       CMDLBL(RSTJIC)
RSTRPG:      CRTRPGPGM  PGM(&LIB/JU0300) SRCFILE(&LIB/QRPGSRC) +
                          SRCMBR(JU0300) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
             CRTRPGPGM  PGM(&LIB/ZA0500) SRCFILE(&LIB/QRPGSRC) +
                          SRCMBR(ZA0500) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
             CRTRPGPGM  PGM(&LIB/TK0100) SRCFILE(&LIB/QRPGSRC) +
                          SRCMBR(TK0100) REPLACE(*YES)
             MONMSG     MSGID(CPF0000 RNS0000 RNF0000 MCH0000)
RSTJIC:      CHKOBJ     OBJ(QTEMP/T28JIC) OBJTYPE(*DTAARA)
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(RSTDATA))
             DLTPGM     PGM(&LIB/JUCINQC)
             MONMSG     MSGID(CPF0000)
RSTDATA:     CHGVAR     VAR(&CMD) VALUE('TXRESET LIB(' *TCAT %TRIM(&LIB) +
                          *TCAT ')')
             CHGVAR     VAR(&CMDLEN) VALUE(40)
             CALL       PGM(QCMDEXC) PARM(&CMD &CMDLEN)
             MONMSG     MSGID(CPF0000)
             SNDPGMMSG  MSG('T28RUN: RST done.')
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('T28RUN: stopped on an unexpected error. See +
                          the job log.')
             ENDPGM
