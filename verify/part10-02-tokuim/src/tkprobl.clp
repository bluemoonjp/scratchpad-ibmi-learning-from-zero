/* TKPROBL - verify/part10-02-tokuim helper, NOT part of the curriculum. */
/* Reads one TOKUIL1 record with DCLF/RCVF, so the record format LEVEL    */
/* CHECK done at open time can be observed without any 5250 screen.      */
/* Same idea as verify/part05-txmigr-to2/src/runprobe.clp (which did     */
/* this for JUCHUM); TK0100 itself cannot be called in a batch job       */
/* because it opens a display file.                                      */
/*                                                                       */
/* The manifest compiles this member twice: TKPROBL before CHGPF (bakes  */
/* in the v1 level ID) and TKPROBL3 after CHGPF (bakes in the v3 level    */
/* ID). Calling each one before/after the change shows which side of    */
/* the level check fails.                                                */
/*                                                                       */
/* PARM: LIB (library that holds TOKUIL1, <=10 chars), TAG (free text     */
/* up to 10 chars, printed in every message so VFYLOG lines can be told  */
/* apart).                                                               */
             PGM        PARM(&LIB &TAG)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)

             DCLF       FILE(TOKUIL1)

             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))

             OVRDBF     FILE(TOKUIL1) TOFILE(&LIB/TOKUIL1) SHARE(*NO)
             RCVF
             MONMSG     MSGID(CPF4131) EXEC(DO)
                SNDPGMMSG  MSG('TKPROBL ' *CAT %TRIM(&TAG) *CAT ': CPF4131 +
                             CONFIRMED - TOKUIL1 level check failed.')
                GOTO       CMDLBL(CLOSE)
             ENDDO
             MONMSG     MSGID(CPF0864) EXEC(DO)
                SNDPGMMSG  MSG('TKPROBL ' *CAT %TRIM(&TAG) *CAT ': TOKUIL1 +
                             is empty (CPF0864, no level error).')
                GOTO       CMDLBL(CLOSE)
             ENDDO
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TKPROBL ' *CAT %TRIM(&TAG) *CAT ': RCVF +
                             failed with something other than CPF4131. See +
                             the raw job log.')
                GOTO       CMDLBL(CLOSE)
             ENDDO

             SNDPGMMSG  MSG('TKPROBL ' *CAT %TRIM(&TAG) *CAT ': RCVF read +
                          a TOKUIL1 row, no CPF4131, levels agree.')

CLOSE:       DLTOVR     FILE(TOKUIL1)
             MONMSG     MSGID(CPF0000)
             RETURN

FAILSAFE:    SNDPGMMSG  MSG('TKPROBL: stopped on an unexpected error. See +
                          the job log for the real message.') MSGTYPE(*COMP)

             ENDPGM
