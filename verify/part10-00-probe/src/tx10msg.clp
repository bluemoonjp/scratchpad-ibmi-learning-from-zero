/* TX10MSG - verify/part10-00-probe helper, NOT part of the curriculum.   */
/* RTVMSG needs receiver variables, and the wrapper offers no DCL to a    */
/* step, so this small program does RTVMSG and echoes the result with     */
/* SNDPGMMSG (the message text then lands in the wrapper job log and in   */
/* VFYLOG). Used for the 10-01 reading box (RTVMSG) and for message text. */
/*                                                                        */
/* PARM: MSGID (7 chars, e.g. CPF9898). Looked up in QCPFMSG.             */
             PGM        PARM(&MSGID)

             DCL        VAR(&MSGID) TYPE(*CHAR) LEN(7)
             DCL        VAR(&M1) TYPE(*CHAR) LEN(132)
             DCL        VAR(&M2) TYPE(*CHAR) LEN(256)

             RTVMSG     MSGID(&MSGID) MSGF(QSYS/QCPFMSG) MSG(&M1) +
                          SECLVL(&M2)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TX10MSG: RTVMSG failed for ' *CAT &MSGID)
                RETURN
             ENDDO

             SNDPGMMSG  MSG('TX10MSG ' *CAT &MSGID *CAT ' first level: ' +
                          *CAT %TRIM(&M1))
             SNDPGMMSG  MSG('TX10MSG ' *CAT &MSGID *CAT ' second level: ' +
                          *CAT %TRIM(&M2))

             ENDPGM
