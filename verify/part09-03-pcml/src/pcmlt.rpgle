**FREE
//=======================================================================
// PCMLT - tiny NOMAIN module used only to probe what PGMINFO(*PCML *STMF)
// emits for exported procedures. Fixed-length parameters, no pointers,
// one data structure in, one result code out - the shape 09-03 teaches.
// No files are opened, so it compiles without any library list set up.
// Throw-away probe source (verify/part09-03-pcml), not a lesson file.
//=======================================================================
ctl-opt nomain;

dcl-ds ReqDs qualified template;
  prodCode char(6);
  qty packed(7:0);
end-ds;

dcl-proc plusOne export;
  dcl-pi *n int(10);
    n int(10) value;
  end-pi;

  return n + 1;
end-proc;

dcl-proc statusOf export;
  dcl-pi *n char(2);
    req likeds(ReqDs) const;
  end-pi;

  if req.qty > 0;
    return '00';
  endif;
  return '01';
end-proc;
