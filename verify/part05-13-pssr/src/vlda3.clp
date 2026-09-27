/* VLDA3 - verify/part05-13-pssr helper, NOT part of the          */
/* curriculum. Adapted from verify/part05-qcmdexc-runtime/src/vlda.clp -  */
/* same reasoning, different *LDA byte range. *LDA is job-scoped: a       */
/* `collect` step (db2 via qsh) runs in a different job after this        */
/* connection ends, so it cannot see a value CHGDTAARA wrote during this  */
/* connection's wrapper job. This program instead runs INSIDE that same   */
/* wrapper job (CALLed as an ordinary step, same call stack/job as        */
/* RUNCOMBO3's own CALL PGM(&LIB/JU0900C) -> ZA0500 -> *PSSR ->            */
/* CHGDTAARA), reads *LDA back with RTVDTAARA, and reports it via         */
/* SNDPGMMSG so it lands in the wrapper's own job log - which its         */
/* insertLog mechanism (verify/lib/clgen.mjs) always captures into        */
/* VFYLOG regardless of the DONE/FAILSAFE path taken, and regardless of   */
/* whether RUNCOMBO3's own step is marked FAILED.                         */
/*                                                                        */
/* Byte range (21 20), not za0510.rpg/ZA0510V's own (1 20): matches       */
/* solutions/05-13/za0500-ticket3.rpg's own *PSSR                         */
/* (CHGDTAARA DTAARA(*LDA (21 20)) VALUE('ZA0500 SHORT ERR')) - a         */
/* DIFFERENT byte range from ZA0510/ZA0510V's own *LDA use (bytes 1-20)   */
/* so the two programs' flags cannot collide if ever run in the same job, */
/* per that file's own header note.                                      */
             PGM

             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(20)

             RTVDTAARA  DTAARA(*LDA (21 20)) RTNVAR(&FLAG)
             SNDPGMMSG  MSG('VLDA3: *LDA(21,20)=[' *CAT &FLAG *CAT ']')

             ENDPGM
