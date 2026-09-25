             PGM
             DCL        VAR(&FIRST) TYPE(*CHAR) LEN(10) VALUE('TARO')
             DCL        VAR(&LAST) TYPE(*CHAR) LEN(10) VALUE('YAMADA')
             DCL        VAR(&MSG1) TYPE(*CHAR) LEN(30)
             DCL        VAR(&MSG2) TYPE(*CHAR) LEN(30)
             DCL        VAR(&MSG3) TYPE(*CHAR) LEN(30)

             CHGVAR     VAR(&MSG1) VALUE(&FIRST *CAT &LAST)
             CHGVAR     VAR(&MSG2) VALUE(&FIRST *TCAT &LAST)
             CHGVAR     VAR(&MSG3) VALUE(&FIRST *BCAT &LAST)

             SNDPGMMSG  MSG('CAT  =[' *TCAT &MSG1 *TCAT ']')
             SNDPGMMSG  MSG('TCAT =[' *TCAT &MSG2 *TCAT ']')
             SNDPGMMSG  MSG('BCAT =[' *TCAT &MSG3 *TCAT ']')
             ENDPGM
