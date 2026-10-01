      * HAND CONVERSION - UNVERIFIED (2026-10-01): not yet compiled with CRTBNDRPG nor
      * compared to the real CVTRPGSRC output; replace by real output (verify batch
      * part05-lgcvt) and keep the RPG III original (src/legacy/qrpgsrc) in sync.
      *
      * Made by converting src/legacy/qrpgsrc/za0500.rpg column for column, as CVTRPGSRC
      * does. Only three edits were made on purpose: this header, the H spec
      * (DFTACTGRP(*YES)) and the 100-column limit of QRPGLE112. Code lines are
      * not modernized. Changes that follow from the RPG III -> RPG IV layout:
      *  - EXCPT -> EXCEPT, SETOF -> SETOFF, UPDAT -> UPDATE, DEFN -> DEFINE,
      *    array notation CT,IX -> CT(IX), *IN,60 -> *IN(60).
      *  - RPG IV allows one conditioning indicator per line (cols 9-11). A line
      *    with more than one is split: first indicator on its own line, the
      *    other ones on CAN lines, with the operation on the last CAN line.
      *    (Layout of these CAN lines is UNVERIFIED against real CVTRPGSRC.)
      *  - Resulting indicators moved from cols 54-59 to cols 71-76.
      *
      * ZA0500 - allocate stock for order lines (JUCHUD) matched to their order
      * header (JUCHUM), M1/MR processing. Legacy system, fixed-form RPG IV
      * (QRPGLE112, CRTBNDRPG). Prints the same lines as the RPG III ZA0500.
      * JUCHUD is opened by JU0900C via OVRDBF SHARE(*YES); this program only
      * opens JUCHUM and ZAIKOM directly.
      *
      * BUG (05-13 ticket 1): *ENTRY PLIST below declares MINQTY as 5,0, but
      * JU0900C declares the CL variable it passes as 3,0. Left in on purpose;
      * the fix is LEN(5 0) in JU0900C (solutions/05-13/ju0900c-ticket1.clp).
      *
      * JUCHUD (primary, IP) and JUCHUM (secondary, IS) are program-described
      * files; each has one record type, so the sequence entry AA and the
      * record identifying indicator (01 for JUCHUD, 02 for JUCHUM) are
      * required. JUNO is the match field (M1) in both.
      *
      * The allocation block runs only when 01 and MR are both on. A matched
      * pair is processed as two detail cycles and MR stays on for both, so
      * without 01 the JUCHUM side would run the block a second time.
      * There is no SETON LR on every cycle: the primary file turns LR on by
      * itself at its end, and JU0900C calls this program once for all lines.
      * Mode '*LIVE' updates ZAIKOM; any other mode only reports.
      *
      * Indicators: 90 ZAIKOM row not found, 91 AVAIL < MINQTY (the stock left
      * after the line is below the minimum). Printed as NOTFOUND, SHORT or OK.
      * 9091 are cleared first because a result indicator keeps its old value
      * when the line that sets it is skipped.
      * GOTO/TAG is used for the branch: DOLIVE is a TAG label, so CABEQ (not
      * CASEQ) is the right test.
      *
     H DFTACTGRP(*YES)
     FJUCHUD    IP   F   27        DISK
     FJUCHUM    IS   F   26        DISK
     FZAIKOM    UF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     IJUCHUD    AA  01
     I                                  1    6  JUNO            M1
     I                                  7    9 0JULINE
     I                                 10   15  JUSHO
     I                                 16   20 0JUSU
     I                                 21   27 2JUTNK
     IJUCHUM    AA  02
     I                                  1    6  JUNO            M1
     I                                  7   12  JUTOK
     I                                 13   20 0JUDATE
     I                                 21   26  JUTAN
     C     *ENTRY        PLIST
     C                   PARM                    RMODE            10
     C                   PARM                    MINQTY            5 0
     C   01
     CAN MR              GOTO      PROCLN
     C                   GOTO      SKPALL
     C     PROCLN        TAG
     C                   SETOFF                                       9091
     C     JUSHO         CHAIN     ZAIKOM                             90
     C  N90              Z-ADD     ZASU          AVAIL             7 0
     C  N90              SUB       JUSU          AVAIL
     C  N90AVAIL         COMP      MINQTY                               91
     C  N90
     CANN91RMODE         CABEQ     '*LIVE'       DOLIVE
     C                   GOTO      SKPUPD
     C     DOLIVE        TAG
     C                   Z-ADD     AVAIL         ZASU
     C                   UPDATE    ZAIKOR
     C     SKPUPD        TAG
     C                   EXCEPT
     C     SKPALL        TAG
     OQSYSPRT   E
     O                       JUNO                 6
     O                       JUSHO               14
     O                       JUSU                21
     O               90                          30 'NOTFOUND'
     O              N90 91                       30 'SHORT'
     O              N90N91                       30 'OK'
