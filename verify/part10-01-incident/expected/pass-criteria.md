# part10-01-incident: pass criteria

Read the saved result file (work/verify/results/part10-01-incident-*.json, anonymized) in this order.
Everything marked UNVERIFIED is a recording target, not an assumption: write the actual outcome into docs/probes.md.

## 0. Pre-checks (a failure here invalidates the rest)

| Where | Look for | Meaning |
|---|---|---|
| vfylog | no line `<LABEL> FAILED` for CPTXCKM .. CHKCAPPGM | every build step worked (incl. TXRESET, compiled by this batch), TXCAPST program and command exist (PASS item "TXCAPST command exists") |
| vfylog | `TXCAPRUN: TXLEGST value: Y` after LEGBOOT | TXLEGACY FORCE(*YES) ran (also check `TXLEGACY: done`) |
| vfylog | `TXRESET: data restored to the initial state.` | RESET worked |
| collect VFY10 | `A-RESET` JUCHUM=8, JUCHUD=12, SENTINEL=0, SENTINELM=0; `A-DBVER JUCHUM-COLS` = 4 | clean DBVER 1 start (design assumption "TXRESET reloads 8 orders / 12 lines" is confirmed by the counts). If JUCHUM-COLS = 5 the library is at DBVER 2: the rest is the DBVER 2 experiment (UNVERIFIED branch of TXCAPST, ZA0500 26-byte F-spec), record it as such |
| collect DATA_AREA_INFO | TXSTATE value | DBVER (1 expected); best effort, the service call itself is unverified |
| sh(after) MKFILES section | `TREE-KEEP` lines followed by two `cksum` lines per file, or `TREE-CREATED` | whether the clone under $HOME/ibmi-kyozai was used as is. For each TREE-KEEP file the two checksums (clone file, uploaded member) should be equal; a difference for za0500.rpg / ju0900c.clp / jubadd.pf means TXLEGACY compiled an older or newer copy than the repo, which can change the statement number (6400) |

## 1. Baseline (job TXC1BASE, before TXCAPST)

- Print lines: most likely route is the in-job copy, collect `SELECT * FROM VFYPBASE` (helper TXCAPJOB, job TXC1BASED, CPYSPLF JOB(*) into a 133-byte physical file); second route is sh(after) SPLBASE (QSYSPRT of TXC1BASE via SYSTOOLS.SPOOLED_FILE_DATA). Neither is proven for a submitted batch job: whichever works, 12 print lines, OK 10 / SHORT 2 / NOTFOUND 0, equal to verify/part08-05-legacy-baseline/expected/golden-master.md. No RPG0907 (this is the "ticket 1 fixed, ticket 3 not applied" combination, design H0 step 4). If both fail, the job log copy (VFYJ10 tag BASE) must at least show no RPG0907 and a normal end; record the CPYSPLF message id from the VFYJ10 rows.
- VFY10 `A-ZAI BEFORE-BASE` equals `A-ZAI AFTER-BASE` (`*TEST` writes nothing). Same equality later for `C-AFTFAIL ZAI-SUM` and `G-ZAI AFTER-FIXD`.
- If SPLBASE fails to read (db2 error text), the job log route (below) still shows whether the job ended normally.

## 2. TXCAPST plant (step RUNCAP)

- vfylog: `TXCAPST: incident condition prepared in library <lib>.` and `TXCAPRUN: TXCAPFL value: Y`.
- VFY10 `B-PLANT`: row JUNO=J00000, K2=001, V=`4B4B4B4B4B` (the planted bytes, PASS: HEX(JUSU)); JUCHUM row K2=C00001, V=`T00001/20260930`; CNT-D = 1, CNT-M = 1.
- `B-PLANT JUDLV`: at DBVER 1 this step is expected to show `OB5 FAILED` in vfylog (column absent). At DBVER 2 the value is what TXCAPST supplied (2026-09-30): UNVERIFIED branch, record it.
- No CPF2816 (QTEMP staging built and copied inside the one TXCAPST job). Any `CPF` line from CPYF in vfylog is a failure.

## 3. Failing run (jobs TXC1FAIL plain, TXC1FAILD helper copy)

PASS when the job log contains, in this order (from any of: LOGFAIL, LOGFAILB, LOGFAILC, or the in-job copy VFYJ10 rows with TAG `FAIL`, written with the proven ORDINAL_POSITION plus MESSAGE_TEXT form; rows with TAG `FAIL-ID` add MESSAGE_ID and are a separate statement, the whole `FAIL-ID` set may be missing if MESSAGE_ID is not a column):

1. `RPG0907` (decimal-data error) with statement `6400` (za0500.rpg line 64, JUSU I-spec), NOT 8100 (8100 would mean ticket 1 was not applied)
2. `RPG9001` (function check)
3. `CPF9999` "Function check ... unmonitored by JU0900C"
4. `JU0900C: ZA0500 ended abnormally.`

and: zero print lines (collect VFYPFAIL has no rows, or the TXCAPJOB message `CPYSPLF of QSYSPRT failed` plus its CPF id in VFYJ10 says no spooled file exists; SPLFAIL / SPLFAILD as second route), the JU0900C job itself ends normally (collect JOB_INFO: COMPLETION_STATUS normal for TXC1FAIL / TXC1FAILD), no message waits (the job is not stuck in MSGW; INQMSGRPY(*DFT) answered).

Which route reads a submitted job's QPJOBLOG is UNVERIFIED: record which of LOGFAIL (SPOOLED_FILE_DATA joined to JOB_INFO), LOGFAILB (shell-parsed id), LOGFAILC (JOBLOG_INFO with a qualified job name) worked, and whether a QPJOBLOG spooled file exists at all after a job that ended normally with LOG(4 00 *SECLVL) (SPLLIST lists the user's spooled files; output view columns unverified). SPOOLED_FILE_DATA parameter form (JOB_NAME/JOB_USER/JOB_NUMBER separate) is also UNVERIFIED.

State after the failed run: VFY10 `C-AFTFAIL` J00000 row unchanged (`4B4B4B4B4B`), i.e. fix-and-resubmit is safe (first record read, no stock deducted).

## 4. Rerun refusal and FORCE (RUNREF, RUNFRC)

- RUNREF vfylog: `TXCAPST: already prepared in this library. Use FORCE(*YES) to plant it again.` and `D-REFUSE CNT-D` = 1 (unchanged).
- RUNFRC: prepared message again; VFY10 `E-FORCE` CNT-D = 1, CNT-M = 1 (exactly one J00000 row each, PASS "row count of J00000 exactly 1"), HEX = `4B4B4B4B4B` again (same job: QTEMP/JUBADD existed, the CHKOBJ guard skipped CRTPF and DELETE emptied it; a `CPF7302`-like failure here would be a finding).

## 5. Fix and resubmit (FIXUPD, FIXALT, jobs TXC1FIXD / TXC1FIXDD)

- VFY10 `F-FIX`: HEX(JUSU) = `F0F0F0F0F1` (JUSU = 1). If FIXUPD failed but FIXALT worked (or the reverse), record which UPDATE form the SQL engine accepts on a row with an invalid digit.
- Resubmitted run: no RPG0907, job ends normally. Line count (observed in run 2, 2026-09-30: 13 application lines with `J00000  P00001  00001       OK` first, 14 CPYSPLF records with the footer; see section 9). The design derivation said 13 print lines (J00000 line 1 = P00001 qty 1, `*TEST` writes nothing, avail 45 - 1 = 44 >= MINQTY 5 so it prints OK). Record the actual count and the J00000 line text from collect VFYPFIXD (in-job copy, likely route) or SPLFIXD / SPLFIXDD (second route). Do not hard-code 12 or 13 in the lesson or in TXCKM before this is read.

## 6. TXCKM and TXCHECK (TXCHK1, once per job)

vfylog: `TXCHECK PASS:` x4 (TXCAPFL flag exists, ZA0500 program exists, JU0900C program exists, JUCHUD file exists) and `TXCHECK: lesson 10-01 - 0000000004 passed,` / `0000000000 failed.`

## 7. Reading-box examples and B6

- INFMSG (TXCAPINF): vfylog has `TXCAPINF: RTVMSG first level: ...` (record whether `sample message data` was substituted into CPF9898) and second level; `TXCAPINF: RTVMSG failed.` means RTVMSG needs other parameters (record).
- INFOBJD (TXCAPOBJ): `TXCAPOBJ: owner: ... crtdate: ... text: ...`. A compile failure `CPAPOBJ FAILED` (CPD0043) means the RTVOBJD keyword names in the reading box are wrong (record, fix the lesson, not this batch).
- P15 recheck, primary route (proven view QSYS2.LIBRARY_LIST_INFO, no spool reading): collect VFYL10. Tags `W-BEFORE` / `W-AFTER` = the wrapper's own list before and after `CHGCURLIB CURLIB(<lib>)`; tags `J-BEFORE` / `J-AFTER` = the list of the SBMJOB job (helper TXCAPLIB) submitted right before / after it. PASS (P15 inherited *CURRENT confirmed): `J-BEFORE` equals `W-BEFORE` and `J-AFTER` equals `W-AFTER`, with a row of TYPE `CURRENT` naming the library only in the AFTER pair. Anything else is a P15 finding, record it.
- Second look: LIBLA / LIBLB (QPDSPLIB spool of the two DSPLIBL jobs; spool file name and reader UNVERIFIED). `SETENV *PRD` itself is not run (SETENV lives in the private library 1, which batches never touch); CHGCURLIB is what `SETENV *PRD` does first.

## 8. Cleanup (end state)

collect: SENTINEL_LEFT = 0, TXCKM_1001_LEFT = 0; VFY10 `Z-CLEAN` all 0; TXCAPFL no longer listed in the OBJECT_STATISTICS collect. Left in place on purpose: JU0900C compiled from the ticket-1 solution, VFY10 / VFYJ10 evidence tables, TXCHECK / TXCKM / TXCHKRUN / TXLEGACY / TXCAPST / helper programs, backup SAVF LG<date> in the B library written by TXLEGACY FORCE(*YES).

## 9. Corrections after the first real run (2026-09-30, read of the 2026-09-29 result)

- Print line counts: CPYSPLF into a 133-byte file returns the application lines PLUS one PUB400 footer record `-=* http://pub400.com *=-`. Baseline: 13 records = 12 application lines + footer. Count application lines (rows before the footer). The same footer will be in every copy.
- Section 5 (fix and resubmit) failed for the wrong reason in run 1: RPG1031 "JUCHUM match field is out of sequence". ZA0500 reads JUCHUM in arrival order, and J00000 was appended after J00008. TXCAPST now empties JUCHUM (CLRPFM), inserts J00000 first and puts the other headers back in JUNO order. New checks: VFY10 `B-PLANT JUCHUM-RRN` rows list JUNO by relative record number, J00000 must be first (RRN 1). Expected after the fix (UNVERIFIED until re-run): no RPG1031, 13 application lines (J00000 P00001 00001 OK first, then the 12 golden master lines), 14 CPYSPLF records with the footer, a `FIXD` job log without `ended abnormally`.
- Section 3: the failing job leaves no QSYSPRT (CPF3309 "No files named QSYSPRT are active") when the decimal error is on the first JUCHUD read. That stays the case with the fix.
- Section 7 P15: compare only the CURRENT and USER rows. The wrapper (started from qsh) also has a `QSHELL PRODUCT` row that the submitted job does not have, so W-BEFORE never equals J-BEFORE literally.
- PRECLEAN FAILED in vfylog is expected when TXCAPFL does not exist yet (harness prints FAILED for any monitored message). OB5 FAILED at DBVER 1 is expected (JUDLV absent, SQL0206).
- JOB_INFO collect (COMPLETION_STATUS) returned 0 rows in run 1; do not rely on it. Normal end is read from the in-job log copy (RETURN reached).
