/* TXSNAP - copy the most recent spooled file from a program into a      */
/*          labeled member of TXSNAPT, for before/after regression        */
/*          comparison (05-08: "did my fix change the printed output?"). */
/*                                                                        */
/* Two snapshots under different LABELs land in two members of the same  */
/* database file, so they can be compared with CMPPFM or SQL (SELECT ...  */
/* FROM &LIB/TXSNAPT LABEL1 EXCEPT SELECT ... FROM &LIB/TXSNAPT LABEL2,   */
/* naming the member with the file(member) qualifier).                   */
/*                                                                        */
/* PARM:                                                                  */
/*   LABEL   member name for this snapshot (e.g. BEFORE, AFTER). Up to   */
/*           10 characters, required.                                     */
/*   LIB     library to snapshot from/into. Default *CURLIB.              */
/*   SPLF    spooled file name to copy. Default QSYSPRT.                  */
/*   JOB     job that owns the spooled file. Default *(this job).         */
/*   SPLNBR  spooled file number. Default *LAST.                          */
             PGM        PARM(&LABEL &LIB &SPLF &JOB &SPLNBR)

             /* Parameters must not have an initial VALUE; the caller     */
             /* supplies it. See tools/qclsrc/txsetup.clp for why.        */
             DCL        VAR(&LABEL) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&SPLF) TYPE(*CHAR) LEN(10)
             DCL        VAR(&JOB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&SPLNBR) TYPE(*CHAR) LEN(10)

             /* Safety net: see tools/qclsrc/txsetup.clp for why this      */
             /* matters (an unmonitored *ESCAPE can hang a non-interactive */
             /* job forever instead of failing).                          */
             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             IF         COND(&LABEL *EQ ' ') THEN(DO)
                SNDPGMMSG  MSG('TXSNAP: LABEL is required (e.g. BEFORE, +
                             AFTER).')
                RETURN
             ENDDO
             IF         COND(&LIB *EQ ' ') THEN(CHGVAR VAR(&LIB) +
                          VALUE('*CURLIB'))
             IF         COND(&SPLF *EQ ' ') THEN(CHGVAR VAR(&SPLF) +
                          VALUE('QSYSPRT'))
             IF         COND(&JOB *EQ ' ') THEN(CHGVAR VAR(&JOB) VALUE('*'))
             IF         COND(&SPLNBR *EQ ' ') THEN(CHGVAR VAR(&SPLNBR) +
                          VALUE('*LAST'))

             /* FIXED (2026-09-27): this comment used to claim CPYSPLF     */
             /* creates &LIB/TXSNAPT itself the first time it is used.     */
             /* Confirmed wrong via IBM's own CPYSPLF reference: "If the   */
             /* user specifies the name of a database file and the file    */
             /* does not exist at the time of the copy, the copy will      */
             /* fail" - TOFILE must already exist. Only TOMBR auto-creates */
             /* ("If this member does not exist, a member is created and   */
             /* the copy continues"). &LIB/TXSNAPT must be created by the  */
             /* caller before the first TXSNAP call (05-08's own lesson    */
             /* text already does this correctly: CRTPF ... RCDLEN(133)    */
             /* MAXMBRS(*NOMAX) before the first TXSNAP call - that hedge   */
             /* was the right call, this comment's claim was not). Later   */
             /* calls with a new LABEL do just add another member.         */
             CPYSPLF    FILE(&SPLF) TOFILE(&LIB/TXSNAPT) JOB(&JOB) +
                          SPLNBR(&SPLNBR) TOMBR(&LABEL) MBROPT(*REPLACE)

             SNDPGMMSG  MSG('TXSNAP: saved ' *CAT %TRIM(&SPLF) *CAT ' to ' +
                          *CAT %TRIM(&LIB) *CAT '/TXSNAPT(' *CAT +
                          %TRIM(&LABEL) *CAT ').')
             GOTO       CMDLBL(TXEND)

FAILSAFE:    SNDPGMMSG  MSG('TXSNAP: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

TXEND:       ENDPGM
