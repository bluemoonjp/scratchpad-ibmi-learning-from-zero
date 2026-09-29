**FREE
//=======================================================================
// ZAIAPI - a stock lookup shaped for an API boundary (09-03 solution).
// Rules this module follows so that PGMINFO can describe it as PCML:
//   - fixed-length parameters only, no pointers, no *VARSIZE
//   - the result code is the return value and is an int(10)
//     (PGMINFO reports any other return type as an error and the
//     module is then not created: see 09-03 and docs/probes.md)
//   - the answer travels back in an output data structure
// Compile (see solutions/09-03/pcml-cmds.txt):
//   CRTRPGMOD MODULE(<USER>1/ZAIAPI) SRCFILE(<USER>1/QRPGLESRC)
//     SRCMBR(ZAIAPI) PGMINFO(*PCML *STMF) INFOSTMF('<path>/zaiapi.pcml')
//=======================================================================
ctl-opt nomain;

dcl-f zaikom keyed usage(*input) usropn;

dcl-ds ZaiReq qualified template;
  prodCode char(6);
end-ds;

dcl-ds ZaiRes qualified template;
  prodCode char(6);
  stockQty packed(7:0);
  updDate zoned(8:0);
end-ds;

dcl-c RC_OK 0;
dcl-c RC_NOTFOUND 1;

// Look up one product's stock. Reads only; calling it twice is harmless.
dcl-proc zaiApiGet export;
  dcl-pi *n int(10);
    req likeds(ZaiReq) const;
    res likeds(ZaiRes);
  end-pi;

  clear res;
  if not %open(zaikom);
    open zaikom;
  endif;
  chain req.prodCode zaikom;
  if not %found(zaikom);
    return RC_NOTFOUND;
  endif;
  res.prodCode = zasho;
  res.stockQty = zasu;
  res.updDate = zaupd;
  return RC_OK;
end-proc;
