             PGM
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10) VALUE('QSYS2')

             IF         COND(&LIB *EQ 'QSYS') THEN(DO)
                SNDPGMMSG  MSG('This is the system library.')
             ENDDO
             ELSE       CMD(DO)
                SNDPGMMSG  MSG('This is not QSYS.')
             ENDDO

             ENDPGM
