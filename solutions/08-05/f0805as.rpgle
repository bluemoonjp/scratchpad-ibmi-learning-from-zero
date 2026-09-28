**FREE
//=======================================================================
// F0805A - lesson 08-05, "characteristics testing" (tokusei kentei)
// rewrite of the legacy JU0300 (src/legacy/qrpgsrc/ju0300.rpg,
// control-level processing over JUCHUL1) as free-form RPG IV, with
// indicators (L1/L2/LR) replaced by an explicit DOW loop + IF-based
// control-break detection + procedure splitting. Faithfully preserves
// JU0300's own printed layout and business logic - this is a "same
// output, different technique" exercise (part08-design-v1.md section
// 0.1/2), not a redesign. See ju0300.rpg's own header for the full
// history of that file's control-level layout (L1=JUDATE minor/inner,
// L2=JUTOK major/outer - matching db/v1/juchul1.lf's own key order,
// K JUTOK then K JUDATE) and its XFOOT/UDS-FTOK-filter mechanics,
// which this file ports rather than re-derives.
//
// STATUS: baseline captured, this file not yet compiled/run -
// blocked-pending-Part-8-own-verification (part08-design-v1.md section
// 0.1) resolved for JU0300 itself by verify/part08-05-legacy-baseline
// (CONFIRMED SUCCESS, docs/probes.md, 2026-09-28): JU0300 executed for
// the first time ever and its real printed output is recorded verbatim
// in verify/part08-05-legacy-baseline/expected/golden-master.md. THIS
// file (F0805A) is the new version to diff against that golden master
// - the diff itself has not run yet. Column positions below were
// derived by counting characters directly in that captured output
// (not from ju0300.rpg's own O-spec end-column numbers, which are
// consistently off by exactly 1 from the real printed positions - see
// golden-master.md's own note and the column derivation in this
// session's own work).
//
// CONTROL-BREAK MODEL (the "characteristics testing" itself - same
// business logic, explicit procedural form instead of the RPG cycle's
// L1/L2/LR):
// JUCHUL1 is keyed JUTOK (major) then JUDATE (minor) - db/v1/juchul1.lf
// - so records naturally arrive grouped by customer, sub-grouped by
// date within each customer. On each record read (after the first),
// this file compares the CURRENT record's JUTOK/JUDATE against the
// PREVIOUS record's (remembered in prevJutok/prevJudate): a JUTOK
// change means both an L2 (customer) AND an L1 (date) break (a new
// customer always starts a new date sub-group too - the same "higher
// level break forces lower levels on" rule ju0300.rpg's own header
// cites for the ORIGINAL indicator-based cycle); a JUDATE change alone
// (same customer, new date) means only an L1 break. Break handling
// (print the OLD group's subtotal, roll counts up, reset) always runs
// BEFORE this record's own counts are added - exactly matching the RPG
// cycle's own execution order (total-time calculations for a record
// run before that same record's detail-time calculations, using the
// OLD, not-yet-reset accumulator values - ilerpgref75.txt's RPG cycle
// description; ju0300.rpg's own header point 6b independently confirms
// this by explaining why indicator 94 only turns on at detail time).
// At end of file (no more records), the last-seen group's L1/L2 breaks
// and the grand total run once more, exactly as JU0300's own LR
// processing does - guarded by firstRec ever having gone *off, the
// same role ju0300.rpg's own indicator 94 plays (an empty JUCHUL1
// prints nothing at all, matching that file's fix 6b).
//
// XFOOT / array-bounds guard: CT is a 50-element array, one slot per
// customer's rolled-up L2CNT, filled via IX (starts at 0, incremented
// before each store). Faithfully ports JU0300's own guard ("IX COMP
// 49" BEFORE incrementing, skip both the increment AND the store when
// IX already equals 49) - see that file's header comment 3 for why
// this specific ordering exists (prevents IX from ever exceeding the
// array's own 50-element bound). Note this guard actually caps usable
// array slots at 49, not 50 (the 50th slot is never written) - a minor
// asymmetry inherited unchanged from the original rather than "fixed",
// since this rewrite's whole point is behavioral equivalence, not
// improvement; with only 6 customers in db/data/load_v1.sql this never
// triggers either way. %XFOOT(ct) sums all 50 declared elements
// (ilerpgref75.txt, %XFOOT (Sum Array Expression Elements)) - unused
// slots stay at their INZ(0) value, so this is safe regardless of how
// many customers were actually seen.
//
// *LDA FTOK FILTER: RPG IV free-form has no UDS auto-load (the
// mechanism ju0300.rpg's own I-spec "U" option used). Ported instead
// via the DTAARA keyword on an unnamed data structure with an explicit
// IN operation - ilerpgref75.txt's own worked example ("Free-form
// DTAARA keyword for a data structure", the DCL-DS *N DTAARA('...')
// + IN *DTAARA example) is the basis for the shape used below. A
// filler subfield covers *LDA bytes 1-10 (the menu-digit byte MN0000C
// writes, per ju0300.rpg's own header) so FTOK lands at the same bytes
// 11-16 the original UDS used. Only IN is needed (this program only
// READS the filter, never writes it) - the *USRCTL default (implied
// when *AUTO is not specified) is what makes IN/OUT usable at all.
//
// PUB400 placeholders: <lib> stands for the learner's own library; no
// real PUB400 user or library name appears in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f juchul1 usage(*input) keyed;
dcl-f qsysprt printer(132) usage(*output);

// *LDA FTOK filter - see header. Bytes 1-10 are filler (MN0000C's own
// menu-digit byte plus padding), bytes 11-16 are FTOK, matching
// ju0300.rpg's own "*LDA (11 6)" position exactly.
dcl-ds ldaDs dtaara('*LDA');
  filler char(10) pos(1);
  ftok   char(6)  pos(11);
end-ds;

dcl-ds line len(132) end-ds;

dcl-s ct packed(5:0) dim(50) inz(0);
dcl-s ix packed(3:0) inz(0);
dcl-s l1cnt packed(5:0) inz(0);
dcl-s l2cnt packed(5:0) inz(0);
dcl-s gcnt  packed(5:0) inz(0);
dcl-s xtot  packed(5:0) inz(0);

dcl-s prevJutok  like(jutok);
dcl-s prevJudate like(judate);
dcl-s firstRec ind inz(*on);

in ldaDs;

read juchul1;
dow not %eof(juchul1);
  if not firstRec;
    if jutok <> prevJutok;
      l1Break();
      l2Break();
    elseif judate <> prevJudate;
      l1Break();
    endif;
  endif;
  firstRec = *off;

  gcnt += 1;
  l1cnt += 1;

  if ftok = *blanks or ftok = jutok;
    printDetail();
  endif;

  prevJutok  = jutok;
  prevJudate = judate;

  read juchul1;
enddo;

if not firstRec;
  l1Break();
  l2Break();
  grandTotal();
endif;

*inlr = *on;
return;

//=======================================================================
// printDetail - one DTL line. Column positions (empirically derived
// from verify/part08-05-legacy-baseline/expected/golden-master.md, see
// header): JUNO@6(6) JUTOK@16(6) JUDATEZ@26(8, edit code Z) JUTAN@38(6).
//=======================================================================
dcl-proc printDetail;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:6:6)  = juno;
  %subst(line:16:6) = jutok;
  %subst(line:26:8) = %editc(judate:'Z');
  %subst(line:38:6) = jutan;
  write qsysprt line;
end-proc;

//=======================================================================
// l1Break - closes out the OLD date sub-group (prevJutok/prevJudate -
// the group that just ended, NOT the new record's own values). Column
// positions: JUTOK@6(6) JUDATEZ@16(8) 'DATE TOTAL'@37(10) L1CNT@52(5,
// edit code Z). Rolls L1CNT into L2CNT, then resets L1CNT for the next
// date sub-group - same order as ju0300.rpg's own CL1-conditioned
// calculations.
//=======================================================================
dcl-proc l1Break;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:6:6)   = prevJutok;
  %subst(line:16:8)  = %editc(prevJudate:'Z');
  %subst(line:37:10) = 'DATE TOTAL';
  %subst(line:52:5)  = %editc(l1cnt:'Z');
  write qsysprt line;

  l2cnt += l1cnt;
  l1cnt = 0;
end-proc;

//=======================================================================
// l2Break - closes out the OLD customer group (prevJutok). Column
// positions: JUTOK@6(6) 'CUST TOTAL'@37(10) L2CNT@52(5, edit code Z).
// Stores L2CNT into the CT array (bounds-guarded, see header), then
// resets L2CNT for the next customer.
//=======================================================================
dcl-proc l2Break;
  dcl-pi *n;
  end-pi;

  if ix <> 49;
    ix += 1;
    ct(ix) = l2cnt;
  endif;

  clear line;
  %subst(line:6:6)   = prevJutok;
  %subst(line:37:10) = 'CUST TOTAL';
  %subst(line:52:5)  = %editc(l2cnt:'Z');
  write qsysprt line;

  l2cnt = 0;
end-proc;

//=======================================================================
// grandTotal - LR processing. Column positions: 'GRAND TOTAL'@11(11)
// GCNT@27(5, edit code Z) 'XFOOT='@36(6) XTOT@47(5, edit code Z)
// 'OK'@60(2) or 'MISMATCH'@63(8).
//=======================================================================
dcl-proc grandTotal;
  dcl-pi *n;
  end-pi;

  dcl-s xfootMatch ind;

  xtot = %xfoot(ct);
  xfootMatch = (xtot = gcnt);

  clear line;
  %subst(line:11:11) = 'GRAND TOTAL';
  %subst(line:27:5)  = %editc(gcnt:'Z');
  %subst(line:36:6)  = 'XFOOT=';
  %subst(line:47:5)  = %editc(xtot:'Z');
  if xfootMatch;
    %subst(line:60:2) = 'OK';
  else;
    %subst(line:63:8) = 'MISMATCH';
  endif;
  write qsysprt line;
end-proc;
