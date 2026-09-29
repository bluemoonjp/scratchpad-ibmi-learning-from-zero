/* TXCAPOBJ - verify/part10-01-incident helper, NOT part of the           */
/* curriculum. Runs the RTVOBJD reading-box example of lesson 10-01       */
/* (design B7) inside a CL program: RTVOBJD returns the creation date,    */
/* the owner and the text of one object into CL variables, which are then */
/* sent as a message so they land in the wrapper's job log (VFYLOG).      */
/* UNVERIFIED until this batch runs: the keyword names CRTDATE, OWNER and */
/* TEXT were taken from memory, not from a primary source. If the compile */
/* of this helper fails (CPD0043), that is the finding; the rest of the   */
/* batch does not depend on it.                                           */
/*                                                                        */
/* PARM: LIB (10 chars), the library holding JU0900C.                     */
             PGM        PARM(&LIB)

             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&CRT) TYPE(*CHAR) LEN(13)
             DCL        VAR(&OWN) TYPE(*CHAR) LEN(10)
             DCL        VAR(&TXT) TYPE(*CHAR) LEN(50)

             RTVOBJD    OBJ(&LIB/JU0900C) OBJTYPE(*PGM) OWNER(&OWN) +
                          CRTDATE(&CRT) TEXT(&TXT)
             MONMSG     MSGID(CPF0000) EXEC(DO)
                SNDPGMMSG  MSG('TXCAPOBJ: RTVOBJD failed.')
                RETURN
             ENDDO

             SNDPGMMSG  MSG('TXCAPOBJ: owner: ' *CAT %TRIM(&OWN) *CAT +
                          ' crtdate: ' *CAT &CRT *CAT ' text: ' *CAT +
                          %TRIM(&TXT))

             ENDPGM
