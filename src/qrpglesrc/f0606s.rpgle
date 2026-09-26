**FREE
//=======================================================================
// F0606A - Built-in functions: strings and dates (Part 6, lesson 06-06).
//
// What this replaces (RPG III, fixed-form):
//   RPG III has no BIFs at all (docs/appendix/f-bif-reference.md: a full
//   grep of the *RPG/400 Reference* text found zero `%`-prefixed BIFs).
//   String work that RPG III did with opcodes/column positions - SUBST,
//   SCAN, CAT, MOVE/MOVEL/Z-ADD for numeric<->character conversion, and
//   the O-spec edit-code column - becomes an expression built from
//   %BIFs here. R0402A (04-02, src/qrpgsrc/r0402s.rpg) is the concrete
//   RPG III reference point: 1580 x 1.10 = 1738.00 (hardware-verified
//   2026-09-25), reused below for the %char/%dec demonstration.
//
// Scope (deliberately trimmed to the design's new-syntax limit - see
// work/design/part06-design-v1.md section 06-06): %trim/%triml/%trimr,
// %subst, %scan, %char, %dec, and the date-BIF family %date/%diff/
// %days. %scanrpl, TEST(DE), and %editc/%editw are READ-ONLY reference
// material for this lesson (see the single commented-out line near the
// bottom) and are NOT exercised as live code here.
//
// Why not DSPLY, and why sendMsg/QCMDEXC instead: ilerpgref75.txt line
// 55828 states "For a batch job, if no message-queue value is specified,
// the default is QSYSOPR" for DSPLY. This program is meant to run
// non-interactively (SSH/batch, same as this repo's verify/ harness),
// so a bare DSPLY here would silently send to QSYSOPR - exactly what
// style-guide.md's "PUB400 etiquette" section forbids (no SNDMSG to
// QSYSOPR/other users). SNDPGMMSG via QCMDEXC, with TOPGMQ(*SAME) and
// MSGTYPE(*INFO), is used instead - this exact combination matches
// this repo's own verify/ harness: verify/lib/clgen.mjs's generated CL
// wrapper (lines 106, 120, 125) sends its own step-result messages with
// `SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA(...) TOPGMQ(*SAME)
// MSGTYPE(*INFO)` (a pattern clgen.mjs's own comment, line 2, says
// follows tools/qclsrc/txsetup.clp's already hardware-verified
// convention), then reads the whole job's log back with `SELECT ...
// FROM TABLE(QSYS2.JOBLOG_INFO('*'))` (clgen.mjs line 115). The one
// difference from the harness's own proven usage: there, SNDPGMMSG
// runs directly in CL at the wrapper's own (outermost) call level;
// here, it runs one call level deeper, from inside a CALLed RPG
// program, via QCMDEXC. That specific combination is not yet
// hardware-verified.
// QCMDEXC/SNDPGMMSG is 06-05's new syntax, not 06-06's, but it is only
// reused here (not re-taught) as this program's output/observation
// channel, the same way any lesson reuses a tool learned in an earlier
// one. Both files duplicate the small qcmdexc prototype and sendMsg
// subprocedure locally, since this repo's part06 design explicitly
// keeps /copy and /include out of scope for Part 6 (design section 1,
// the "not covered" list), so nothing can be shared between
// f0605s.rpgle and f0606s.rpgle here.
//
// STATUS: hardware-UNTESTED (Part 6 draft; SSH access is rate-limited
// as of this writing, 2026-09-26). This source has not been compiled
// or run on PUB400 yet. Treat every runtime claim below as "should
// work per the ILE RPG Language Reference", not as a verified fact.
//
// Verified against work/design/refs/ilerpgref75.txt (the real IBM i 7.5
// ILE RPG Language Reference, 73451 lines) at approximately these line
// numbers:
//   %TRIM (Trim Characters at Edges)       lines 50901-51002 (Figures
//                                           257-258)
//   %TRIML (Trim Leading Characters)       lines 51003-51036 (Figure 259)
//   %TRIMR (Trim Trailing Characters)      lines 51037 onward
//   %SUBST (Get Substring)                 lines 50380-50460
//   %SCAN (Scan for Characters)            lines 49101-49200 (example at
//                                           49153-49190)
//   %CHAR (Convert to Character Data),
//     numeric form                        lines 44254-44306
//   %DEC (Convert to Packed Decimal)       lines 44948-45000
//   %DATE (Convert to Date), and "if the
//     date format is not specified for
//     character or numeric input, the
//     default format is *ISO"             lines 44900-44935, esp. 44913
//   DATE type, D'yyyy-mm-dd' literal form  lines 44196-44198
//   %DAYS (Number of Days)                 lines 44936-44947
//   %DIFF (Difference Between Two Date,
//     Time, or Timestamp Values)           lines 45150-45234 (worked
//                                           example with due_date/today
//                                           at 45195-45219, same shape
//                                           reused below)
//   %LEN (Get or Set Length), "current
//     length" of a BIF result used in an
//     expression (used to explain the
//     trim demo's shape below, even
//     though %len is not itself called)  lines 46859-46899
//   DFTACTGRP(*NO) required for a bound
//     (non-EXTPGM) procedure call such
//     as sendMsg                          lines 25072-25074
//   DSPLY default queue for a batch job    line 55828 (why DSPLY is
//                                           *not* used in this file)
//
// Also grounded against this repo's own verify/ harness (not the ILE
// RPG reference, since SNDPGMMSG itself is a CL command, not an RPG
// construct), and cross-checked against a second primary source:
//   TOPGMQ(*SAME) / MSGTYPE(*INFO) and the    verify/lib/clgen.mjs
//     QSYS2.JOBLOG_INFO capture technique     lines 106, 115, 120, 125
//   QCMDEXC prototype shape (cmd CONST         work/design/refs/
//     OPTIONS(*VARSIZE), cmdlen 15P 5 CONST)   ilerpgprogguide75.txt
//     confirmed again, independently of        (ILE RPG Programmer's
//     ilerpgref75.txt's Figure 275              Guide), Figures 69/73,
//                                                lines 13982-13990,
//                                                14437-14445 (cmd there
//                                                is 3000A, not 200A -
//                                                both valid; 200A fits
//                                                every command string
//                                                actually built here)
//
// TODO: verify - the harness's own SNDPGMMSG usage (cited above) is
// itself only a *convention this repo already trusts* (inherited from
// tools/qclsrc/txsetup.clp), not something confirmed by a primary
// source in work/design/refs/ - SNDPGMMSG is not documented in
// cl_commands_75.txt or ilerpgprogguide75.txt in that directory (both
// checked, zero matches). More importantly, this file calls SNDPGMMSG
// one call level deeper than the harness's own proven usage (from
// inside a CALLed RPG program via QCMDEXC, not directly from the CL
// wrapper), which has not been hardware-verified. Confirm with an
// actual V1/V2 run.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

//-----------------------------------------------------------------------
// dcl-pr / EXTPGM: a prototype for the system API QCMDEXC. Copied
// exactly (types and lengths) from ilerpgref75.txt's own worked example
// at "Figure 275. Calling a Prototyped Program Using CALLP" (approx.
// lines 52637-52644) - the same prototype as f0605s.rpgle, duplicated
// here (see the header note above on why nothing is shared between
// files).
//-----------------------------------------------------------------------
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd    char(200) options(*varsize) const;
  cmdlen packed(15:5) const;
end-pr;

//-----------------------------------------------------------------------
// (a) Name formatting: combining/trimming a first + last name.
//-----------------------------------------------------------------------
dcl-s firstName char(10) inz('Taro');
dcl-s lastName  char(10) inz('Yamada');
dcl-s fullName  char(21);
dcl-s spacePos  zoned(3:0);
dcl-s lastPart  char(10);
dcl-s initial   char(1);

// A second, deliberately padded string to show %trim vs %triml vs
// %trimr side by side (all three share one "new" slot in the design's
// new-syntax count, but the three behave differently). IMPORTANT: the
// three calls below are used directly inside the sendMsg argument
// expression, not assigned to an intermediate fixed-length char(20)
// variable first - per %LEN's documented rule (ilerpgref75.txt lines
// 46896-46899), a BIF result used directly in an expression carries
// its own *current* (trimmed) length, but assigning it into a fixed
// non-varying variable first would immediately re-pad it back out to
// that variable's full declared length and erase the difference
// between %trim/%triml/%trimr.
dcl-s padded char(20) inz('  Taro  ');

//-----------------------------------------------------------------------
// (b) Due-date calculation: %date/%diff/%days.
// orderDate/todayDate are set below via %date() from 8-digit numeric
// YYYYMMDD values (the same shape as RPG III's numeric date fields,
// e.g. ZAUPD 8S0 in db/v1/zaikom.pf) rather than from D'yyyy-mm-dd'
// literals, so %date() itself appears as live code, not just as a
// data type. Fixed numbers (not %date() with no argument, which would
// return today's *system* date) so the result is reproducible for
// V1/V2 checking regardless of which day this program actually runs.
//-----------------------------------------------------------------------
dcl-s orderDate date;
dcl-s dueDays   zoned(3:0) inz(30);
dcl-s dueDate   date;
dcl-s todayDate date;
dcl-s daysLeft  int(10);

//-----------------------------------------------------------------------
// %char / %dec: numeric <-> character, the way MOVE/Z-ADD did it in
// RPG III (04-02). Reuses R0402A's verified result, 1738.00.
//-----------------------------------------------------------------------
dcl-s totalPacked packed(9:2) inz(1738.00);
dcl-s totalText   char(15);
dcl-s totalBack   packed(9:2);

//-----------------------------------------------------------------------
// Mainline.
//-----------------------------------------------------------------------

// (a) Name formatting.
fullName = %trim(firstName) + ' ' + %trim(lastName);
sendMsg('F0606A: fullName = ' + %trim(fullName));

spacePos = %scan(' ' : fullName);
sendMsg('F0606A: spacePos = ' + %char(spacePos));

lastPart = %subst(fullName : spacePos + 1);
sendMsg('F0606A: lastPart = ' + %trim(lastPart));

initial = %subst(%trim(lastName) : 1 : 1);
sendMsg('F0606A: initial = ' + initial);

// %trim strips both sides; %triml only the left; %trimr only the
// right. '<'/'>' delimiters make the difference visible in the sent
// message text (style-guide.md bans the CCSID 273 variable characters
// from distributed source, which rules out the more usual vertical-bar
// delimiter here).
sendMsg('F0606A: trim  <' + %trim(padded)  + '>');
sendMsg('F0606A: triml <' + %triml(padded) + '>');
sendMsg('F0606A: trimr <' + %trimr(padded) + '>');
// TODO: verify these three messages on real hardware once V1/V2
// testing is possible (see STATUS above) - in particular that %trimr
// leaves the leading blanks of 'padded' visible before the closing
// '>', and %triml leaves the trailing ones visible before it.

// (b) Due-date calculation.
// ilerpgref75.txt line 44913: "If the date format is not specified for
// character or numeric input, the default format is *ISO" - *iso is
// given explicitly below for clarity, but could be omitted per that
// rule.
orderDate = %date(20260901 : *iso);
todayDate = %date(20260926 : *iso);

// 2026-09-01 + 30 days = 2026-10-01.
dueDate = orderDate + %days(dueDays);
sendMsg('F0606A: dueDate = ' + %char(dueDate));

// 2026-10-01 minus 2026-09-26 = 5 days.
daysLeft = %diff(dueDate : todayDate : *days);
sendMsg('F0606A: daysLeft = ' + %char(daysLeft));
// TODO: verify these two messages on real hardware once V1/V2 testing
// is possible - the arithmetic above was checked by hand (2026 is not
// a leap-relevant edge case for this range) but the exact %CHAR(date)
// rendering (*ISO by default: 'yyyy-mm-dd') has not been confirmed
// against a live IBM i 7.5 system yet.

// %char / %dec: R0402A's verified total, round-tripped through
// character form and back.
totalText = %trim(%char(totalPacked));
sendMsg('F0606A: totalText = ' + totalText);

totalBack = %dec(totalText : 9 : 2);
sendMsg('F0606A: totalBack = ' + %char(totalBack));

// Read-only reference only (see appendix F /
// docs/appendix/f-bif-reference.md) - %SCANRPL, TEST(DE), and
// %EDITC/%EDITW are NOT exercised as live code in this lesson (the
// design deliberately trims the new-syntax list to stay within the
// 9-item limit). One commented-out line to show the shape, not to run:
// sendMsg(%editc(totalPacked : '1'));   // NOT executed - reference only

*inlr = *on;
return;

//=======================================================================
// sendMsg: this program's only observation channel (see the "Why not
// DSPLY" note in the header). Builds one SNDPGMMSG command with %TRIM
// and string concatenation and runs it through QCMDEXC. Identical to
// f0605s.rpgle's sendMsg, duplicated here rather than shared (no
// /copy in Part 6 - see the header note above).
//=======================================================================
dcl-proc sendMsg;
  dcl-pi *n;
    text char(60) const;
  end-pi;

  dcl-s cmdString char(200);

  // '' inside a string literal is how RPG IV escapes a literal single
  // quote inside a character constant. TOPGMQ(*SAME)/MSGTYPE(*INFO)
  // match this repo's own verify/ harness convention exactly (see the
  // header comment above) rather than being invented here.
  cmdString = 'SNDPGMMSG MSG(''' + %trim(text)
    + ''') TOPGMQ(*SAME) MSGTYPE(*INFO)';
  // The full declared length (200), not %len(%trim(cmdString)): CL
  // command parsing tolerates trailing blank padding after a complete
  // command, and this keeps this file's BIF list to exactly the
  // design's approved scope for 06-06 (no %len).
  callp qcmdexc(cmdString : 200);
end-proc;
