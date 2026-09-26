/* VLDA - verify/part05-qcmdexc-runtime helper, NOT part of the           */
/* curriculum. *LDA is job-scoped: a `collect` step (db2 via qsh) runs in */
/* a different job after the connection ends, so it cannot see a value    */
/* CHGDTAARA wrote during this connection's wrapper job. This program     */
/* instead runs INSIDE that same wrapper job (CALLed as an ordinary step, */
/* same call stack/job as ZA0510V's own CHGDTAARA), reads *LDA back with  */
/* RTVDTAARA, and reports it via SNDPGMMSG so it lands in the wrapper's   */
/* own job log - which its insertLog mechanism (verify/lib/clgen.mjs)     */
/* always captures into VFYLOG regardless of the DONE/FAILSAFE path       */
/* taken.                                                                  */
             PGM

             DCL        VAR(&FLAG) TYPE(*CHAR) LEN(20)

             RTVDTAARA  DTAARA(*LDA (1 20)) RTNVAR(&FLAG)
             SNDPGMMSG  MSG('VLDA: *LDA(1,20)=[' *CAT &FLAG *CAT ']')

             ENDPGM
