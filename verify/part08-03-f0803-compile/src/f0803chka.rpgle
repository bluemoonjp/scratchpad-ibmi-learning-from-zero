**FREE
ctl-opt dftactgrp(*no) actgrp(*new);
dcl-f tokuim keyed usage(*input);
dcl-pi *n;
  custCode char(6) const;
end-pi;
dcl-s custName char(30);
dcl-s foundInd ind;
chain (custCode) tokuim foundInd;
if foundInd;
  custName = toknm;
else;
  custName = 'NOTFOUND';
endif;
*inlr = *on;
return;
