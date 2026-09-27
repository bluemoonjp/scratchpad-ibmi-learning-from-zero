**FREE
//==================================================================
// Q0614BB - THROWAWAY comparison candidate for the part06-14b-null
// re-verification connection ONLY - not a shipped lesson source. See
// src/qrpglesrc/q0614bs.sqlrpgle's "DESIGN FLAW" header note for the
// bug this and that file both fix (static cursor SELECT against a
// QTEMP table that does not exist at CRTSQLRPGI precompile time).
//
// This is candidate 2 from jiggly-greeting-crystal.md A-3: instead of
// making the cursor dynamic (candidate 1, the shipped q0614bs.sqlrpgle),
// this candidate keeps the cursor STATIC but moves the work table out
// of QTEMP into a real, learner-owned PERSISTENT library, created
// BEFORE this member is even compiled (via a separate RUNSQLSTM CL
// step in this same verify manifest - see manifest.json's
// PERSISTPRIME step). Static SQL against a table that already exists
// at precompile time needs no PREPARE/DECLARE-FOR-prepared-statement
// gymnastics at all. Section 0.6 (part06-design-v1.md:321) still
// holds: this table is NOT the shared sample-DB schema, just a
// different (non-QTEMP) home for the same private demo table.
//
// If this candidate also works, whichever one the connection prefers
// wins; if only one works, that is decisive. Either way this file is
// deleted after the connection (see docs/probes.md's part06-14b-null
// re-verification section for the decision actually made).
//==================================================================

ctl-opt dftactgrp(*no) actgrp(*new) alwnull(*usrctl);

dcl-f qsysprt printer(132) usage(*output);

dcl-ds prtLine len(132);
  prtText char(132) pos(1);
end-ds;

dcl-s wTokcd char(6);
dcl-s wToknm varchar(30);
dcl-s wLastOrderInd int(5);
dcl-s wLastOrderSql date;
dcl-s wTokLts timestamp;
dcl-s wLastOrder date NULLIND;

exec sql SET OPTION commit = *none, naming = *sys;

// No DROP/CREATE here - W0614BP already exists in &LIB (created by
// this manifest's PERSISTPRIME step, via RUNSQLSTM, before this
// member was even compiled).

// --- static cursor, no PREPARE needed - the table already existed
//     at CRTSQLRPGI precompile time.
exec sql DECLARE C2 CURSOR FOR
  SELECT TOKCD, TOKNM, TOKLORD, TOKLTS
    FROM W0614BP
    ORDER BY TOKCD;

exec sql OPEN C2;

if SQLCODE < 0;
  prtText = 'OPEN C2 failed, SQLCODE=' + %char(SQLCODE);
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;

exec sql
  FETCH C2 INTO :wTokcd, :wToknm, :wLastOrderSql :wLastOrderInd,
                :wTokLts;

dow SQLSTATE = '00000';
  if wLastOrderInd < 0;
    %nullind(wLastOrder) = *on;
  else;
    %nullind(wLastOrder) = *off;
    wLastOrder = wLastOrderSql;
  endif;

  if %nullind(wLastOrder);
    prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
            + ': last order date is NULL (unknown), last touched '
            + %char(wTokLts);
  else;
    prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
            + ': last order ' + %char(wLastOrder) + ', last touched '
            + %char(wTokLts);
  endif;
  write qsysprt prtLine;

  exec sql
    FETCH C2 INTO :wTokcd, :wToknm, :wLastOrderSql :wLastOrderInd,
                  :wTokLts;
enddo;

exec sql CLOSE C2;

*inlr = *on;
return;
