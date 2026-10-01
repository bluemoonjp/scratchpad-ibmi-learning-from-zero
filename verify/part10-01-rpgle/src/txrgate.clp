/* TXRGATE - verify/part10-0x-rpgle helper, NOT part of the curriculum.   */
/* Precondition gate. Reads the sample database version (TXSTATE, the     */
/* same RTVDTAARA form as tools/qclsrc/txstatus.clp) and the legacy       */
/* source language (TXLEGLNG; a missing area counts as *RPG, the same     */
/* rule TXLEGACY uses for *SAME). When DBVER is 1 and the language equals */
/* WANT, it creates the data area QTEMP/VFYGOOD. The wrapper step that    */
/* follows does CHKOBJ QTEMP/VFYGOOD and jumps to its stop label when the */
/* area is missing (the wrapper has no variables of its own, so a flag    */
/* object is the only way to branch on a value read here; QTEMP is shared */
/* because this program runs in the wrapper's own job).                   */
/*                                                                        */
/* PARM: LIB (10 chars), WANT ('*RPG' or '*RPGLE', 7 chars).              */
/* The values it saw are sent as a message, so they land in VFYLOG.       */
             PGM        PARM(&LIB &WANT)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&WANT) TYPE(*CHAR) LEN(7)
             DCL        VAR(&DBVER) TYPE(*DEC) LEN(3 0)
             DCL        VAR(&DBVERC) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LANG) TYPE(*CHAR) LEN(7)

             DLTDTAARA  DTAARA(QTEMP/VFYGOOD)
             MONMSG     MSGID(CPF0000)

             RTVDTAARA  DTAARA(&LIB/TXSTATE) RTNVAR(&DBVER)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRGATE: TXSTATE cannot be read.')
                RETURN
             ENDDO
             CHGVAR     VAR(&LANG) VALUE(' ')
             RTVDTAARA  DTAARA(&LIB/TXLEGLNG (1 7)) RTNVAR(&LANG)
             MONMSG     MSGID(CPF0000) EXEC(CHGVAR VAR(&LANG) +
                          VALUE('*RPG'))
             IF         COND(&LANG *EQ ' ') THEN(CHGVAR VAR(&LANG) +
                          VALUE('*RPG'))

             CHGVAR     VAR(&DBVERC) VALUE(&DBVER)
             SNDPGMMSG  MSG('TXRGATE: DBVER=' *CAT %TRIM(&DBVERC) *CAT +
                          ' TXLEGLNG=' *CAT %TRIM(&LANG) *CAT +
                          ' want=' *CAT %TRIM(&WANT))

             IF         COND(&DBVER *EQ 1 *AND &LANG *EQ &WANT) THEN(DO)
                CRTDTAARA  DTAARA(QTEMP/VFYGOOD) TYPE(*CHAR) LEN(1) +
                             VALUE('Y')
                MONMSG     MSGID(CPF0000)
                SNDPGMMSG  MSG('TXRGATE: precondition met.')
             ENDDO
             ELSE       CMD(SNDPGMMSG MSG('TXRGATE: precondition NOT +
                          met.'))

             ENDPGM
