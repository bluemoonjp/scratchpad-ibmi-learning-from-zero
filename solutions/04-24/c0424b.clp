/* C0424B - CL caller, fixed: &QTY is *DEC 5 0, same as V0424C's QTY.      */
             PGM
             DCL        VAR(&QTY) TYPE(*DEC) LEN(5 0) VALUE(5)
             DCL        VAR(&FLG) TYPE(*CHAR) LEN(1) VALUE('-')
             CALL       PGM(V0424C) PARM(&QTY &FLG)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000) EXEC(DO)
                SNDPGMMSG  MSG('C0424B: V0424C ended abnormally.')
             ENDDO
             SNDPGMMSG  MSG('C0424B: FLG after the call is' *BCAT &FLG)
             ENDPGM
