/* C0308S - calls C0308T the SAFE way: from inside a CL program, with a   */
/* variable declared with the SAME type/length as the target's PARM.     */
/* Compare with calling C0308T directly from the command line (03-08).   */
             PGM

             DCL        VAR(&NUM) TYPE(*DEC) LEN(5 0) VALUE(123)

             CALL       PGM(C0308T) PARM(&NUM)

             ENDPGM
