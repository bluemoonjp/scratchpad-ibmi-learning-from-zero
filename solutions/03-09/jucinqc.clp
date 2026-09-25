/* JUCINQC - order inquiry, CL version (evolution step 2). Reads JUCHUM   */
/* sequentially and prints the orders for one customer. CL has no CHAIN, */
/* so every record must be read and checked in order (see 03-09).       */
             PGM        PARM(&TOKCD)

             DCLF       FILE(JUCHUM)
             DCL        VAR(&TOKCD) TYPE(*CHAR) LEN(6)
             DCL        VAR(&JUDATEC) TYPE(*CHAR) LEN(8)

LOOP:        RCVF
             MONMSG     MSGID(CPF0864) EXEC(GOTO CMDLBL(END))

             IF         COND(&JUTOK *NE &TOKCD) THEN(GOTO CMDLBL(LOOP))

             CHGVAR     VAR(&JUDATEC) VALUE(&JUDATE)
             SNDPGMMSG  MSG(&JUNO *BCAT %TRIM(&JUDATEC))
             GOTO       CMDLBL(LOOP)

END:         ENDPGM
