**FREE
//=======================================================================
// F0615A - Stock inquiry checkpoint (06-15), subfile half. Reproduces
// R0413A's (04-13) and F0607A's (06-07) LOWSTOCK judgment (ZASU <
// SHOHAT) as a read-only, load-all subfile - no OPT/selection field at
// all, since nothing here needs to be acted on (part06-design-v1.md's
// own 06-15 section states its content as "no new syntax at all"). This
// is the SUBFILE half of the checkpoint; see q0615s.sqlrpgle for the
// SQL half (a non-interactive batch report using an embedded SQL
// cursor JOIN instead of CHAIN, confirmable over SSH).
//
// Companion display file: solutions/06-15/d0615s.dspf (object
// D0615A) - see its header for the full DDS-side rationale.
//
// WARM-UP CHECK (lesson text must state this): this checkpoint reads
// SHOHIM, which 06-11b's own maintenance screen (F0611BA) can add/
// change/delete. Before running this checkpoint, confirm 06-11b's own
// TXRESET cleanup has already been done (part06-design-v1.md:338) -
// otherwise this checkpoint's LOWSTOCK judgment may not match the
// grading table below, through no fault of this program.
//
// GRADING TABLE (confirmed real hardware, F0607A, docs/probes.md's
// part06-0509-procs-files section, fresh/reset ZAIKOM+SHOHIM): 6 rows
// total, exactly 2 are LOWSTOCK - P00002 (OFFICE CHAIR, qty 3, reorder
// point 5) and P00005 (USB CABLE, qty 12, reorder point 50). The other
// 4 (P00001/P00003/P00004/P00006) print with no LOWSTOCK flag.
//
// HARDWARE STATUS: CONFIRMED V1 (compile-check, part06-15-checkpoint,
// 2026-09-27): CRTBNDRPG Highest Severity 00. Interactive execution
// (V3) is still untested - WORKSTN/EXFMT, same limitation as every
// other Part 6 screen (SSH non-interactive batches cannot drive a
// real 5250 device).
//
// LOAD-ALL (06-11's technique, not new here): every ZAIKOM row is
// WRITEn into SFL1 before the first EXFMT. ZAIKOM has 6 rows as of
// this writing (never 0), so the empty-subfile edge case (d0611s.dspf
// header) does not need handling here.
//
// CROSS-FILE CHAIN (R0413A's own technique, ported as-is): ZAIKOM's
// key field is ZASHO; SHOHIM's key field is SHOCD (different names,
// same product-code concept, db/v1/zaikom.pf + db/v1/shohim.pf) - so
// "chain zasho shohim;" is a cross-field-name CHAIN, exactly like
// R0413A's own "ZASHO CHAINSHOHIM". Once found, SHOHIM's own fields
// (SHONM/SHOHAT) are auto-matched by name into the identically-named
// SFL1 output fields on WRITE - no explicit assignment needed for
// those two, same trick R0408A/f0604s.rpgle/f0611bs.rpgle all rely on.
// ZASHO/ZASU are similarly auto-matched from ZAIKOM's own current row.
// STATUS (screen-only, not in either DB file) is the one field this
// program assigns explicitly, same plain-output-field technique
// R0413A's own O-spec conditioning (60 70'LOWSTOCK') and F0607A's
// %subst equivalent both use.
//
// Verified against work/design/refs/ilerpgref75.txt (same citations
// already established by d0611s.dspf/f0611s.rpgle for this exact
// load-all/SFILE/CHAIN/%EOF/%FOUND shape - not re-derived here):
//   SFILE(recformat:rrnfield) keyword          ~line 28400-28437
//   CHAIN search-argument forms (cross-field   ~line 53190-53235
//     name, matches R0413A's own ZASHO/SHOHIM)
//   %EOF takes the WORKSTN FILE name, not the  ~line 45624 (RNF0391/
//     subfile record format name (part06-        RNF0394, confirmed
//     screens-compile real-hardware finding)      real hardware,
//                                                  d0611s.dspf/
//                                                  f0611s.rpgle)
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f d0615a workstn sfile(sfl1:rrn1);
dcl-f zaikom disk keyed usage(*input);
dcl-f shohim disk keyed usage(*input);

dcl-s rrn1 packed(4:0) inz(0);

//-----------------------------------------------------------------------
// Load-all: WRITE every ZAIKOM row into SFL1 before the first EXFMT.
//-----------------------------------------------------------------------
read zaikom;
dow not %eof(zaikom);
  rrn1 += 1;

  chain zasho shohim;
  if not %found(shohim);
    // Defensive only - every ZAIKOM row is expected to have a matching
    // SHOHIM row (same reasoning R0413A's own design assumes); this
    // repo has no referential-integrity enforcement, so a miss is
    // handled rather than assumed away.
    shonm = 'UNKNOWN PRODUCT';
    shohat = 0;
  endif;

  if zasu < shohat;
    status = 'LOWSTOCK';
  else;
    status = *blanks;
  endif;

  write sfl1;
  read zaikom;
enddo;

more = 'BOTTOM';

dow not *in03;
  write sfl1ftr;
  exfmt sfl1ctl;
enddo;

*inlr = *on;
return;
