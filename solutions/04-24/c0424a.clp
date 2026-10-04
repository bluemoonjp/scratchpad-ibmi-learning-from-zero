/* C0424A - CL caller: &QTY is *DEC 3 0 but V0424C expects 5,0.       */
/* Same mismatch as JU0900C (&MINQTY 3 0) against ZA0500 (MINQTY 5 0). */
             PGM
             DCL        VAR(&QTY) TYPE(*DEC) LEN(3 0) VALUE(5)
             DCL        VAR(&FLG) TYPE(*CHAR) LEN(1) VALUE('-')
             CALL       PGM(V0424C) PARM(&QTY &FLG)
             MONMSG     MSGID(CPF0000 MCH0000 RNQ0000 RNX0000) EXEC(DO)
                SNDPGMMSG  MSG('C0424A: V0424C ended abnormally.')
             ENDDO
             SNDPGMMSG  MSG('C0424A: FLG after the call is' *BCAT &FLG)
             ENDPGM
