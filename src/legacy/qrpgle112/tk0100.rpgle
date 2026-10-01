      * HAND CONVERSION - UNVERIFIED (2026-10-01): not yet compiled with CRTBNDRPG nor
      * compared to the real CVTRPGSRC output; replace by real output (verify batch
      * part05-lgcvt) and keep the RPG III original (src/legacy/qrpgsrc) in sync.
      *
      * Made by converting src/legacy/qrpgsrc/tk0100.rpg column for column, as CVTRPGSRC
      * does. Only three edits were made on purpose: this header, the H spec
      * (DFTACTGRP(*YES)) and the 100-column limit of QRPGLE112. Code lines and
      * the comment lines inside the code are not modernized. Changes that
      * follow from the RPG III -> RPG IV layout:
      *  - EXCPT -> EXCEPT, SETOF -> SETOFF, UPDAT -> UPDATE, DEFN -> DEFINE,
      *    *NAMVAR -> *DTAARA, *IN,60 -> *IN(60), col 53 P -> MOVEL(P).
      *  - RPG IV allows one conditioning indicator per line (cols 9-11). A line
      *    with more than one is split: first indicator on its own line, the
      *    other ones on CAN lines, with the operation on the last CAN line.
      *    (Layout of these CAN lines is UNVERIFIED against real CVTRPGSRC.)
      *  - Resulting indicators moved from cols 54-59 to cols 71-76.
      *
      * TK0100 - TOKUIM (customer master) inquiry on the display file TK0100D.
      * Legacy system, fixed-form RPG IV (QRPGLE112, CRTBNDRPG). Shows the same
      * screen behavior as the RPG III TK0100. Reading material for the old
      * opcodes and the indicator map (lesson 05-02).
      *
      * The program only uses the record format INQFMT (EXFMT). TK0100D also
      * defines a customer-list subfile (SFL1/SFL1CTL) and a message subfile
      * (MSGSFL/MSGCTL) that this program does not drive, so the F spec has no
      * SFILE keyword (the RPG III source had no SFILE line either). Whether
      * CRTBNDRPG accepts a WORKSTN file with subfile formats and no SFILE is
      * UNVERIFIED. Driving the subfiles would need SFILE(format:rrn) and READC.
      *
      * INQFMT fields: TOKCD (6A, input), TOKNM (30A), TOKZIP (7A), TOKTAN (6A),
      * TOKUPD (8S 0), all output. They match the TOKUIM field names, so a found
      * CHAIN fills them by name. On a not-found CHAIN the buffer stays as it
      * was, so TOKZIP, TOKTAN and TOKUPD are cleared on indicator 50. INQFMT
      * has no rep-name field: TANNM is computed but not displayed yet.
      *
      * F3 = Exit: TK0100D has CF03(03), so indicator 03 is the exit signal.
      * KC (the F3 function key indicator) is tested as a second, redundant
      * exit line; it costs nothing if KC never turns on.
      *
      * Before running, the data area LASTCD must exist:
      *   CRTDTAARA DTAARA(<LIB>/LASTCD) TYPE(*CHAR) LEN(6)
      * RPG III declared it with *NAMVAR DEFN (RPG IV: *DTAARA DEFINE). It is
      * read with IN *LOCK and written back with OUT, which also unlocks it.
      *
      * TANTOM field names TANTOCODE and TANTONAME are renamed to TANCD and
      * TANNM on the I spec (external name cols 21-30, program name 49-62).
      *
      * Indicator map:
      *   03     TK0100D CF03(03): F3 = exit.
      *   50/51  CHAIN not found (TOKUIM/TANTOM). Cleared with SETOFF first,
      *          because a result indicator keeps its old value when its CHAIN
      *          line is skipped by a conditioning indicator.
      *   60/61  cosmetic MOVEA demo only (clears *IN(60) and *IN(61)).
      *          Nothing tests 60/61.
      *   H1     halt indicator used as the error indicator of IN *LOCK. When
      *          it is on, the final OUT is skipped (N H1): OUT on an area that
      *          never got locked would fail itself.
      *   U1     external indicator (a job switch set by CHGJOB or CRTJOBD SWS,
      *          not from *LDA). Gates one cosmetic MOVE only.
      *   KC     function key indicator for F3 (redundant, see above).
      *   OA-OG  not used: there is no PRINTER file.
      *
     H DFTACTGRP(*YES)
     FTK0100D   CF   E             WORKSTN
     FTOKUIM    IF   E           K DISK
     FTANTOM    IF   E           K DISK
     ITANTOR
     I              TANTOCODE                   TANCD
     I              TANTONAME                   TANNM
      * -- declaratives --
     C     *LIKE         DEFINE    TOKUPD        SAVUPD
     C     *DTAARA       DEFINE                  LASTCD            6
      * -- one-time init: load last-queried code, lock for later OUT --
     C     *LOCK         IN        LASTCD                               H1
      * -- main loop --
     C     LOOP          TAG
     C                   EXFMT     INQFMT
      * 03 = confirmed F3 signal (TK0100D CF03(03)); KC = redundant
      * KA-KY exercise only - see header note.
     C   03              GOTO      ENDPGM
     C   KC              GOTO      ENDPGM
     C     TOKCD         CASEQ     ' '           DFLTSR
     C                   CAS                     LKUPSR
     C                   ENDCS
     C                   GOTO      LOOP
     C     ENDPGM        TAG
      * write LASTCD back, unlocked (Factor 1 blank -> unlock on OUT,
      * p.317); skip if LOCK IN above failed (H1 on) - see indicator
      * map H1 note: OUT on a never-locked area would itself error,
      * and a halt indicator still on at LR ends the program
      * abnormally regardless, so there is nothing to gain by trying.
     C  NH1              OUT       LASTCD
     C                   SETON                                            LR
      * -- subroutines --
     CSR   DFLTSR        BEGSR
      * blank entry -> restore the last code, then actually redo the
      * lookup (EXSR into LKUPSR - p.203/263: one subroutine calling
      * another is fine; TOKCD is I-only on INQFMT, so just moving
      * LASTCD into it here would not even show up, let alone CHAIN).
     C                   MOVEL     LASTCD        TOKCD
     C                   EXSR      LKUPSR
     CSR                 ENDSR
     CSR   LKUPSR        BEGSR
      * clear both not-found indicators first - see indicator map
      * note above (same reason as ZA0500 SETOF 9091).
     C                   SETOFF                                       5051
      * MOVEA: old-style equivalent of SETOF 6061, shown once here
      * purely as a reading-material demo (indicator array *IN,60 as
      * MOVEA result, Reference p.295/177) - nothing tests 60/61.
     C                   MOVEA     '00'          *IN(60)
     C     TOKCD         CHAIN     TOKUIM                             50
     C  N50              MOVEL     TOKCD         LASTCD
      * cosmetic old-style demo only (MOVE, right-adjust, plain copy
      * of a *LIKE-defined field); gated by U1 (CL job switches -
      * CHGJOB/CRTJOBD SWS, see corrected header note) so it never
      * affects correctness either way.
     C  N50
     CAN U1              MOVE      TOKUPD        SAVUPD
      * P extender (col 53): without it, a literal shorter than its
      * result field leaves the field's old tail untouched (Reference
      * p.302-303 MOVEL rule 3.b) - so a customer found on a PRIOR
      * inquiry, followed by a not-found code, would show e.g.
      * 'NOTFOUNDDING CO' (old TOKNM tail surviving) instead of a
      * clean 'NOTFOUND'. P blank-pads the remainder (p.302-303 rule
      * 4; col 53 Operation Extender, p.163).
     C   50              MOVEL(P)  'NOTFOUND'    TOKNM
     C   50              MOVEL(P)  'NOTFOUND'    TANNM
      * TOKZIP/TOKTAN/TOKUPD are also INQFMT output fields TOKUIM auto-
      * fills by name on a successful CHAIN (TOKUPD per tk0100d.dspf's
      * own "Contract with tk0100.rpg" header note); a failed CHAIN
      * leaves the WHOLE record buffer as it was (probes.md's own CHAIN-
      * not-found finding), so without this they would still show the
      * PREVIOUS customer's zip/rep code/update date next to today's
      * NOTFOUND name. *BLANKS takes on the length of its result field
      * automatically (Reference p.384, Figurative Constants), so no P
      * extender is needed for TOKZIP/TOKTAN. TOKUPD is numeric (8S 0),
      * and BLANK/BLANKS is "valid only for character fields" (p.384),
      * so it is zeroed with Z-ADD instead.
     C   50              MOVEL     *BLANKS       TOKZIP
     C   50              MOVEL     *BLANKS       TOKTAN
     C   50              Z-ADD     0             TOKUPD
      * CABxx: skip the TANTOM lookup when this customer has no rep
      * code on file, rather than CHAINing on a blank key.
     C  N50TOKTAN        CABEQ     ' '           NOREP
     C  N50TOKTAN        CHAIN     TANTOM                             51
     C                   GOTO      TANDN
     C     NOREP         TAG
     C                   MOVEL(P)  'NOREP'       TANNM
     C     TANDN         TAG
     C   51              MOVEL(P)  'NOTFOUND'    TANNM
     CSR                 ENDSR
