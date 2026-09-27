**FREE
//=======================================================================
// F0611BA - Product master (SHOHIM) maintenance: list + add/change/
// delete, with exclusive-lock discipline. Lesson 06-11b. Companion
// display file: src/qddssrc/d0611bs.dspf (object D0611BA) - see its
// header for the full DDS-side rationale. This header covers the
// RPG-side half of that same contract.
//
// *** THIS PROGRAM PERFORMS REAL UPDATE/DELETE/WRITE AGAINST THE ***
// *** SHARED SHOHIM TABLE. RUN TXRESET AFTER USING IT.           ***
// SHOHIM (product master, 6 rows as of this writing) is also read by:
//   - 04-13 (product stock-shortage report, R0413A)
//   - 06-07's exercise (array + %LOOKUP port of 04-13's own logic)
//   - 06-15's checkpoint (stock inquiry)
// Every add/change/delete run through this program is a REAL,
// PERSISTENT change to that same shared physical file - not a copy, not
// QTEMP. Any of the three lessons above that runs AFTER this one has
// been exercised will see whatever this program left behind (an added/
// renamed/removed row, changed price or reorder point). Per this
// repo's own established convention - 04-09's own lesson text (which
// instructs the learner, in Japanese, to always run TXRESET after the
// exercise to restore the stock quantity) - and 06-08/f0608a's own
// header, which cites 04-09's exact same
// requirement for its own shared-table exercise (ZAIKOM) - this
// program's lesson text (docs/part06/06-11b-..., not yet written) MUST
// instruct learners to run <USER>1/TXRESET immediately after trying
// this exercise, before moving on to 04-13, 06-07's exercise, or
// 06-15's checkpoint. This is not optional cleanup; skipping it will
// make those lessons' expected output stop matching what they document.
//
// HARDWARE-UNTESTED (V1 only, compile-check): this program has not
// been compiled or run on real hardware this session. Interactive
// subfile/EXFMT execution is V1-only in this repo's established
// workflow - SSH non-interactive batches cannot drive a real 5250
// device (same WORKSTN/EXFMT limitation as 04-11, tk0100.rpg, and
// f0604s.rpgle/f0611s.rpgle). Verify with CRTBNDRPG, then a real 5250
// session, before relying on this source. The task's own suggested
// exercise (open a second 5250 session and try to change a row this
// program already has locked, per 06-09's design precedent for the
// same "verify/ cannot reproduce a 2-session lock collision" reason)
// is V3-only and left to the learner's own hands, same as 06-09.
//
// EXCLUSIVE-LOCK DISCIPLINE (this lesson's core new concept). Verified
// against work/design/refs/ilerpgref75.txt:
//   - CHAIN (no operation extender) on an update-capable file LOCKS the
//     retrieved record (~line 53190-53193: "If you are reading from an
//     update disk file, you can specify an N operation extender to
//     indicate that no lock should be placed" - i.e. a lock IS placed
//     by default, without N).
//   - UPDATE "modifies the last locked record retrieved... No other
//     operation should be performed on the file between the input
//     operation that retrieved the record and the UPDATE operation"
//     (~line 65818-65820) and "Before UPDATE is issued... a valid input
//     operation with lock... must be issued to the same file" (~line
//     65863-65867). This program's CHAIN and matching UPDATE/DELETE are
//     always on the SAME file (shohim) with only WORKSTN operations
//     (a different file) in between - satisfying that rule exactly the
//     way 04-09's own CHAIN->UPDAT pattern does, just with a screen
//     shown in between instead of straight-line code.
//   - The lock is released automatically in two cases this program
//     relies on: (a) a successful UPDATE or DELETE consumes/releases it
//     (04-09's own lesson text states plainly that the lock is
//     released automatically once you write with UPDAT); DELETE
//     likewise removes the locked record, so there is nothing left to
//     unlock; (b) if the user instead PRESSES
//     F12 (cancel) after a successful CHAIN - so no UPDATE/DELETE ever
//     runs - the lock would otherwise be held until this program ends
//     or the row is read again. This program explicitly calls UNLOCK in
//     every F12/cancel/not-found path instead of letting a stale lock
//     linger (~line 65758-65761, "Releasing record locks": "The UNLOCK
//     operation also allows the most recently locked record to be
//     unlocked for an update disk file").
//   - DELETE requires USAGE(*DELETE) explicitly in free-form (~line
//     23371-23373: "You must explicitly specify USAGE(*DELETE) for a
//     free-form file definition, if you want the file to be opened to
//     allow delete operations") and, combined with add (*OUTPUT) and
//     update, matches the exact free-form-equivalent keyword combo the
//     reference's own fixed-to-free-form table gives for fixed-form
//     type U with file addition (~line 26150-26159): USAGE(*UPDATE :
//     *DELETE : *OUTPUT).
//
// DELETE CONFIRMATION (F12=cancel) is a SEPARATE record format
// (DLTCONFFMT, d0611bs.dspf) shown BEFORE the actual DELETE runs -
// per the task instructions, since delete is irreversible. The CHAIN
// (and its lock) happens BEFORE this confirmation screen is shown, not
// after - so the record stays locked (protected from a concurrent
// update by another session) for the whole time the confirmation is on
// screen, and is either deleted or explicitly unlocked depending on
// what the user presses.
//
// SHOCD KEY PROTECTION DURING CHANGE (see d0611bs.dspf's own header for
// why DDS alone cannot protect this field): DTLFMT's SHOCD field is
// input-capable in both add and change mode. In change mode, this
// program saves the selected row's code into savedShocd BEFORE
// EXFMT-ing DTLFMT, and explicitly re-assigns shocd = savedShocd
// immediately before UPDATE - regardless of whatever the user may have
// typed into the SHOCD field on screen - so UPDATE can never silently
// rewrite the wrong key or collide with a different existing product
// code. This is a compensating RPG-side control for a DDS-side
// protection this file's "no conditioning indicators" policy does not
// provide.
//
// RELOAD-WITHOUT-SFLCLR (reloadSfl2 below): per d0611bs.dspf's header,
// this program reuses the exact technique tk0100d.dspf's own header
// already names as the alternative to SFLCLR - CHAIN the subfile by
// relative record number, then UPDATE (or WRITE, the first time) that
// row in place, blank-filling any RRN beyond the current live SHOHIM
// row count so a shrinking list (after a DELETE) does not leave stale
// rows on screen. This runs once at startup and once after every
// successful add/change/delete.
//
// Verified against work/design/refs/ilerpgref75.txt at these further
// locations:
//   SFILE(recformat:rrnfield) keyword          ~line 28400-28437
//   READC free-form syntax                     ~line 62000-62029
//   CHAIN by relative record number / DELETE    ~line 55198-55207
//     search-arg as an RRN ("If access is by      (DELETE's own RRN-
//     relative record number, search-arg           as-search-arg
//     must be an integer literal or a numeric       wording; CHAIN by
//     field with zero decimal positions")           RRN follows the
//                                                    same search-arg
//                                                    shape)
//   DCL-F free-form KEYED keyword, USAGE        ~line 26074-26079
//     combinations table (fixed-form file-type    (Table, "Equivalent
//     letter -> free-form USAGE(...))              Free-form Coding
//                                                   for Fixed-Form
//                                                   File Entries")
//   CLOSE/OPEN (reopen without USROPN)          pages 814/925, same
//                                                citation f0604s.rpgle
//                                                already uses
//   DCL-PR / EXTPGM zero-parameter form         ~line 8730-8756
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f d0611ba workstn sfile(sfl2:rrn2);
dcl-f shohim disk usage(*update : *delete : *output) keyed;

dcl-s rrn2   packed(4:0) inz(0);
dcl-s maxRrn packed(4:0) inz(0);
dcl-s savedShocd char(6);

//-----------------------------------------------------------------------
// reloadSfl2: rebuild SFL2's on-screen contents from SHOHIM's current
// (possibly just-changed) rows, WITHOUT SFLCLR - see the header note
// above for why. CLOSE+OPEN rewinds SHOHIM to its first row (same
// technique, same citation, as f0604s.rpgle's own CLOSE/OPEN before
// each customer lookup).
//-----------------------------------------------------------------------
//-----------------------------------------------------------------------
// Mainline. Loop shape (dow not *in03 / exfmt / if not *in03 ...)
// matches f0604s.rpgle's/f0611s.rpgle's own EXFMT loop, per this
// repo's established convention.
//-----------------------------------------------------------------------
reloadSfl2();

dow not *in03;
  // FIXED (part06-screens-compile prep, 2026-09-26): d0611bs.dspf's
  // SFL2CTL used to also carry the STATMSG/F3=Exit footer directly,
  // which CPD7812 on real hardware forbids (see tk0100d.dspf's
  // confirmed fix, docs/probes.md). The footer now lives in its own
  // SFL2FTR record format, and SFL2CTL carries OVERLAY - so it must be
  // WRITEn first, every pass, before SFL2CTL is (re)EXFMT'd on top of
  // it (this also means STATMSG's latest value, set in the branches
  // below, is picked up on the very next loop iteration).
  write sfl2ftr;
  exfmt sfl2ctl;

  if *in03;
    leave;
  endif;

  if *in06;
    //---------------------------------------------------------------
    // F6 = Add. No prior row is selected, so there is nothing to
    // CHAIN/lock yet - only the duplicate-code check below takes a
    // momentary lock, released explicitly if it finds a duplicate.
    //---------------------------------------------------------------
    modetxt = 'ADD';
    shocd = *blanks;
    shonm = *blanks;
    shotnk = 0;
    shohat = 0;
    exfmt dtlfmt;

    if not *in12;
      // chain(e) + %error/%status: a plain CHAIN cannot tell "no such
      // row" apart from "row exists but another session holds it
      // locked" - both leave %found off. The E extender instead sets
      // %error on and %status to the file status (1218 = "record-lock
      // error", ilerpgref75.txt) without ending the program, so both
      // cases can be told apart and handled.
      chain(e) shocd shohim;
      if %error and %status(shohim) = 1218;
        statmsg = 'DUPLICATE CHECK: RECORD LOCKED BY ANOTHER SESSION.';
      elseif %found(shohim);
        // Duplicate code: the CHAIN above DID lock this existing
        // record even though this program never intends to update
        // it - release that lock explicitly (see header note).
        unlock shohim;
        statmsg = 'PRODUCT CODE ALREADY EXISTS - NOT ADDED.';
      else;
        // Not found -> the failed CHAIN took no lock at all (only a
        // record actually retrieved gets locked), so nothing to
        // release here.
        write shohir;
        statmsg = 'PRODUCT ADDED.';
        reloadSfl2();
      endif;
    else;
      statmsg = 'ADD CANCELED.';
    endif;
  else;
    readc sfl2;
    // FIXED (part06-screens-compile, 2026-09-26, real-hardware
    // CRTBNDRPG): %EOF/%FOUND take the WORKSTN FILE name (d0611ba), not
    // the subfile RECORD FORMAT name (sfl2) - RNF0391/RNF0394
    // ("Parameter SFL2 is not valid for built-in function %EOF/
    // %FOUND"). Confirmed against ilerpgref75.txt lines 45624/46001:
    // "%EOF{(file_name)}" / "%FOUND{(file_name)}". Same fix applied
    // below at the two %found(d0611ba) calls (CHAIN rrn2/fillRrn sfl2
    // still targets the record format - only the feedback BIF's own
    // parameter needed to change).
    dow not %eof(d0611ba);
      select;
        when opt = '2';
          //-----------------------------------------------------------
          // Change: CHAIN (with lock) BEFORE showing DTLFMT, so the
          // record stays protected from a concurrent update for the
          // whole time the user is looking at/editing it on screen.
          //-----------------------------------------------------------
          savedShocd = shocd;
          // chain(e) + %error/%status(1218): another session already
          // holding this exact row locked must be told apart from the
          // row simply not existing - see the header's "EXCLUSIVE-LOCK
          // DISCIPLINE" note and the add-mode duplicate check above.
          chain(e) savedShocd shohim;
          if %error and %status(shohim) = 1218;
            statmsg = 'RECORD LOCKED BY ANOTHER SESSION - try again later.';
          elseif %found(shohim);
            // Same-name auto-match already filled shocd/shonm/shotnk/
            // shohat from SHOHIM's own chained values - DTLFMT will
            // display them with no extra assignment needed.
            modetxt = 'CHANGE';
            exfmt dtlfmt;

            if not *in12;
              // Re-assert the key regardless of whatever the user may
              // have typed into SHOCD on screen - see the header's
              // "SHOCD KEY PROTECTION" note. UPDATE then uses the
              // (possibly edited) shonm/shotnk/shohat plus this
              // guaranteed-unchanged shocd.
              shocd = savedShocd;
              update shohir;
              statmsg = 'PRODUCT UPDATED.';
              reloadSfl2();
            else;
              unlock shohim;
              statmsg = 'CHANGE CANCELED.';
            endif;
          else;
            // Stale list - another session (or a previous pass in
            // this same one) removed this row already. No lock was
            // taken (not-found CHAIN locks nothing), so no UNLOCK is
            // needed here.
            statmsg = 'RECORD NOT FOUND - list refreshed, try again.';
            reloadSfl2();
          endif;

        when opt = '4';
          //-----------------------------------------------------------
          // Delete: CHAIN (with lock) BEFORE the confirmation screen,
          // for the same reason as Change above - the row stays
          // protected while the user decides.
          //-----------------------------------------------------------
          savedShocd = shocd;
          chain(e) savedShocd shohim;
          if %error and %status(shohim) = 1218;
            statmsg = 'RECORD LOCKED BY ANOTHER SESSION - try again later.';
          elseif %found(shohim);
            exfmt dltconffmt;

            if not *in12;
              delete shohir;
              statmsg = 'PRODUCT DELETED.';
              reloadSfl2();
            else;
              unlock shohim;
              statmsg = 'DELETE CANCELED.';
            endif;
          else;
            statmsg = 'RECORD NOT FOUND - list refreshed, try again.';
            reloadSfl2();
          endif;

        when opt = ' ';
          // Blank OPT reaching here means the user typed something
          // and then cleared it back to blank - a genuine "changed to
          // blank" case. No action needed either way.

        other;
          statmsg = 'INVALID OPTION - use 2=Change or 4=Delete.';
      endsl;
      readc sfl2;
    enddo;
  endif;
enddo;

*inlr = *on;
return;

// FIXED (2026-09-26, repo-wide sweep after part06-gen-probe's
// connection-2 finding): reloadSfl2 used to sit BEFORE the mainline
// above. ilerpgref75.txt's RPG IV Concepts chapter is explicit that a
// subprocedure must be defined AFTER the main source section (the
// mainline) - see docs/probes.md's part06-gen-probe section for the
// full citation. Moved here to match.
dcl-proc reloadSfl2;
  dcl-pi *n;
  end-pi;

  dcl-s r packed(4:0) inz(0);
  dcl-s fillRrn packed(4:0);

  close shohim;
  open shohim;

  read shohim;
  dow not %eof(shohim);
    r += 1;
    rrn2 = r;
    opt = *blanks;
    chain rrn2 sfl2;
    if %found(d0611ba);
      update sfl2;
    else;
      write sfl2;
    endif;
    read shohim;
  enddo;

  // Blank-fill any RRN this program has used before but SHOHIM no
  // longer has a row for (a previous DELETE shrank the live row
  // count) - the "blank-filling a short last page" half of the
  // technique named in the header note above.
  if r < maxRrn;
    fillRrn = r + 1;
    dow fillRrn <= maxRrn;
      chain fillRrn sfl2;
      if %found(d0611ba);
        opt = *blanks;
        shocd = *blanks;
        shonm = *blanks;
        shotnk = 0;
        shohat = 0;
        update sfl2;
      endif;
      fillRrn += 1;
    enddo;
  endif;

  if r > maxRrn;
    maxRrn = r;
  endif;
end-proc;
