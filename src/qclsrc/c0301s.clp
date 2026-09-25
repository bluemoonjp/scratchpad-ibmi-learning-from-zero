             PGM
             DCL        VAR(&VAL) TYPE(*CHAR) LEN(10)
             RTVSYSVL   SYSVAL(QDATFMT) RTNVAR(&VAL)
             SNDPGMMSG  MSG('Date format: ' *CAT &VAL)
             ENDPGM
