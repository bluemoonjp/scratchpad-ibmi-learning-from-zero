/* TXCAPINF - verify/part10-01-incident helper, NOT part of the           */
/* curriculum. Runs the RTVMSG reading-box example of lesson 10-01        */
/* (design B7) inside a CL program, where a plain CL variable can receive */
/* the value: RTVMSG MSGID(CPF9898) MSGF(QCPFMSG) returns the first-level */
/* and second-level text, which are then sent as messages so they land in */
/* the wrapper's job log (VFYLOG). UNVERIFIED until this batch runs:      */
/* whether MSGDTA substitutes into CPF9898's &1 with the defaults.        */
             PGM

             DCL        VAR(&MSG) TYPE(*CHAR) LEN(132)
             DCL        VAR(&SEC) TYPE(*CHAR) LEN(132)

             RTVMSG     MSGID(CPF9898) MSGF(QSYS/QCPFMSG) +
                          MSGDTA('sample message data') MSG(&MSG) +
                          SECLVL(&SEC)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPINF: RTVMSG failed.')
                RETURN
             ENDDO

             SNDPGMMSG  MSG('TXCAPINF: RTVMSG first level: ' *CAT +
                          %TRIM(&MSG))
             SNDPGMMSG  MSG('TXCAPINF: RTVMSG second level: ' *CAT +
                          %TRIM(&SEC))

             ENDPGM
