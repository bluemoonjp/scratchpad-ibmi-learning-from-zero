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
// STATUS: CONFIRMED (part08-05-f0805a, 4th connection, 2026-09-28).
// JU0300's own golden master is CONFIRMED (verify/part08-05-legacy-
// baseline, docs/probes.md - see golden-master.md). This file's 1st
// compile attempt failed: RNF7064 severity 30, "The Factor 2 operand
// LDADS of IN or OUT is not a data area" - the original draft wrote
// DTAARA('*LDA') (a quoted string literal), which the compiler treats
// as a data area LITERALLY NAMED "*LDA" (not a valid object name), not
// as the reserved *LDA keyword. FIXED (verified against
// ilerpgref75.txt's own worked example, lines 16345-16349: "DCL-DS
// LDA_DS DTAARA(*LDA); SUBFLD CHAR(600); END-DS; IN LDA_DS;" - an
// UNQUOTED *lda is the correct form). The 3rd connection compiled this
// file cleanly (00 highest severity) and ran it, but its printed
// output was found to be JU0300's own real output shifted exactly 1
// column right on every line (byte-for-byte diff confirmed - see
// docs/probes.md, part08-05-f0805a) - the column positions below were
// FIXED (see printDetail's own header note). The 4th connection
// recompiled and reran this file (00 highest severity) and confirmed,
// via a strict byte-for-byte diff (no transform) of the same
// connection's own captured output, that this file's printed output is
// now IDENTICAL to JU0300's own printed output, which is itself
// IDENTICAL to golden-master.md's own recorded text - "characteristics
// testing" fully confirmed for this file.
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
// via the DTAARA keyword on a NAMED data structure with an explicit IN
// operation - ilerpgref75.txt lines 16345-16349 ("DCL-DS LDA_DS
// DTAARA(*LDA); SUBFLD CHAR(600); END-DS; IN LDA_DS; OUT LDA_DS;",
// prose: "explicitly based on the *LDA... it must be handled using IN
// and OUT operations") is the exact shape used below - note *LDA is
// the UNQUOTED reserved keyword, not the quoted string literal
// '*LDA' (which the compiler instead treats as a data area literally
// named "*LDA" and rejects - RNF7064, confirmed the hard way on this
// file's own 1st compile attempt, see STATUS above). A filler subfield
// covers *LDA bytes 1-10 (the menu-digit byte MN0000C writes, per
// ju0300.rpg's own header) so FTOK lands at the same bytes 11-16 the
// original UDS used. Only IN is needed (this program only READS the
// filter, never writes it) - the *USRCTL default (implied when *AUTO
// is not specified) is what makes IN/OUT usable at all.
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
dcl-ds ldaDs dtaara(*lda);
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
// printDetail - one DTL line. Column positions (FIXED, part08-05-f0805a
// 3rd connection, 2026-09-28 - see docs/probes.md and this file's own
// STATUS note: the 1st draft's positions were golden-master.md's own
// OBSERVED columns (e.g. JUNO's observed start column 6, copied
// directly). That was wrong - a byte-for-byte diff showed F0805A's
// real printed output was JU0300's own real printed output shifted
// exactly 1 column right, uniformly, on every line. golden-master.md
// (corrected after this finding to document it - it did NOT note this
// beforehand) shows the actual pattern: for JU0300's OWN O-spec, the
// naive start column derived from the O-spec's own stated end column
// (end - length + 1; e.g. JUNO's O-spec end column 10, length 6, gives
// 5) is consistently 1 LESS than the column where that field is
// actually observed to print (6). This same +1 print-shift turned out
// to apply to THIS program too: declaring %subst position 6 (the
// OBSERVED column, already one more than the O-spec-derived value)
// made F0805A print at column 7 - one too many. FIXED by declaring
// each %subst position as the O-SPEC-DERIVED start column instead
// (JUNO: 5, not 6) - since both JU0300's O-spec-based printing AND
// F0805A's %subst-based printing exhibit the identical +1 shift from
// their own declared/derived start to their real printed column, using
// the O-spec-derived value here reproduces JU0300's real observed
// output exactly. The mechanism behind this shared +1 shift is NOT
// established (true of both program styles alike, so it is not a
// WRITE-vs-O-spec artifact) - only the empirical fix is confirmed.):
// JUNO@5(6) JUTOK@15(6) JUDATEZ@25(8, edit code Z) JUTAN@37(6).
//=======================================================================
dcl-proc printDetail;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:5:6)  = juno;
  %subst(line:15:6) = jutok;
  %subst(line:25:8) = %editc(judate:'Z');
  %subst(line:37:6) = jutan;
  write qsysprt line;
end-proc;

//=======================================================================
// l1Break - closes out the OLD date sub-group (prevJutok/prevJudate -
// the group that just ended, NOT the new record's own values). Column
// positions (FIXED, see printDetail's own note - same -1 correction):
// JUTOK@5(6) JUDATEZ@15(8) 'DATE TOTAL'@36(10) L1CNT@51(5, edit code Z).
// Rolls L1CNT into L2CNT, then resets L1CNT for the next date sub-group
// - same order as ju0300.rpg's own CL1-conditioned calculations.
//=======================================================================
dcl-proc l1Break;
  dcl-pi *n;
  end-pi;

  clear line;
  %subst(line:5:6)   = prevJutok;
  %subst(line:15:8)  = %editc(prevJudate:'Z');
  %subst(line:36:10) = 'DATE TOTAL';
  %subst(line:51:5)  = %editc(l1cnt:'Z');
  write qsysprt line;

  l2cnt += l1cnt;
  l1cnt = 0;
end-proc;

//=======================================================================
// l2Break - closes out the OLD customer group (prevJutok). Column
// positions (FIXED, see printDetail's own note - same -1 correction):
// JUTOK@5(6) 'CUST TOTAL'@36(10) L2CNT@51(5, edit code Z). Stores L2CNT
// into the CT array (bounds-guarded, see header), then resets L2CNT for
// the next customer.
//=======================================================================
dcl-proc l2Break;
  dcl-pi *n;
  end-pi;

  if ix <> 49;
    ix += 1;
    ct(ix) = l2cnt;
  endif;

  clear line;
  %subst(line:5:6)   = prevJutok;
  %subst(line:36:10) = 'CUST TOTAL';
  %subst(line:51:5)  = %editc(l2cnt:'Z');
  write qsysprt line;

  l2cnt = 0;
end-proc;

//=======================================================================
// grandTotal - LR processing. Column positions (FIXED, see printDetail's
// own note - same -1 correction): 'GRAND TOTAL'@10(11) GCNT@26(5, edit
// code Z) 'XFOOT='@35(6) XTOT@46(5, edit code Z) 'OK'@59(2) or
// 'MISMATCH'@62(8).
//=======================================================================
dcl-proc grandTotal;
  dcl-pi *n;
  end-pi;

  dcl-s xfootMatch ind;

  xtot = %xfoot(ct);
  xfootMatch = (xtot = gcnt);

  clear line;
  %subst(line:10:11) = 'GRAND TOTAL';
  %subst(line:26:5)  = %editc(gcnt:'Z');
  %subst(line:35:6)  = 'XFOOT=';
  %subst(line:46:5)  = %editc(xtot:'Z');
  if xfootMatch;
    %subst(line:59:2) = 'OK';
  else;
    %subst(line:62:8) = 'MISMATCH';
  endif;
  write qsysprt line;
end-proc;
