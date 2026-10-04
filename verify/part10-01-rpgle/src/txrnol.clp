/* TXRNOL - verify/part10-0x-rpgle helper, NOT part of the curriculum.    */
/* Removes the author's private library 1 (the user profile name plus     */
/* '1') from this job's library list, so nothing from it can shadow the   */
/* objects under test. The name is built from the job's user at run time, */
/* so no real name is written in the repository. A library that is not on */
/* the list, or a failed RMVLIBLE, is only reported (the wrapper goes on).*/
/* The message does not contain the library name.                         */
             PGM

             DCL        VAR(&USR) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB1) TYPE(*CHAR) LEN(10)

             RTVJOBA    USER(&USR)
             CHGVAR     VAR(&LIB1) VALUE(%TRIM(&USR) *CAT '1')
             RMVLIBLE   LIB(&LIB1)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXRNOL: RMVLIBLE of library 1 failed or +
                             it was not on the list.')
                RETURN
             ENDDO
             SNDPGMMSG  MSG('TXRNOL: library 1 removed from the library +
                          list.')

             ENDPGM
