/* TXCAPLIB - verify/part10-01-incident helper, NOT part of the           */
/* curriculum. Submitted with SBMJOB; copies the library list this job    */
/* inherited into the table VFYL10, using the proven route of             */
/* verify/part09-07-checkpoint (QSYS2.LIBRARY_LIST_INFO: ORDINAL_POSITION,*/
/* SCHEMA_NAME, TYPE). TYPE = CURRENT is the current library, USER is a   */
/* user-library-list entry. This answers the P15 recheck (does SBMJOB     */
/* inherit CURLIB/INLLIBL *CURRENT?) without reading any spooled file.    */
/*                                                                        */
/* PARM: TAG (10 chars, label stored in every row), LIB (10 chars,        */
/* library holding VFYL10).                                               */
             PGM        PARM(&TAG &LIB)

             DCL        VAR(&TAG) TYPE(*CHAR) LEN(10)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)

             RUNSQL     SQL('INSERT INTO ' *CAT %TRIM(&LIB) *CAT +
                          '/VFYL10 SELECT ''' *CAT %TRIM(&TAG) *CAT +
                          ''', ORDINAL_POSITION, SCHEMA_NAME, TYPE FROM +
                          QSYS2.LIBRARY_LIST_INFO') COMMIT(*NONE)
             MONMSG     MSGID(CPF0000 SQL0000 SQL9010)

             ENDPGM
