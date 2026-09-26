# part03-rtvjoba-fix の期待値

このバッチは、2026-09-26に直した `RTVJOBA USER()` → `RTVJOBA CURUSER()`
の修正(`docs/appendix/c-troubleshooting.md` 節3)を、公開済みの第3部
ソース側(`setenv.clp`・`juyakc.clp`)で初めて実機確認する。

## 手順の要点

- `SETENV`・`JUYAKC` とも `CRTCLPGM` でコンパイルするだけ(V1)。
- `SETENV` は `PARM('*DEV')` で実際に `CALL` する(V2)。`*DEV` 分岐は
  `CHGCURLIB CURLIB(&LIB1)`(`&LIB1` = `CURUSER` + `'1'`)と
  `RMVLIBLE LIB(&LIB2)`(`<USER>2` が元々ライブラリー・リストに無くても
  `MONMSG MSGID(CPF2105)` で無視される)を行い、最後に
  `SNDPGMMSG MSG('SETENV: now *DEV (curlib=' *TCAT %TRIM(&LIB1) *TCAT ')')`
  を送る。
- `JUYAKC` はコンパイルのみで `CALL` はしない(`JUNODA`・`JUMSGF` を
  このバッチでは用意していないため、意図的な範囲外。同じ `CURUSER` 修正の
  実行確認は `verify/part07-04-actgrp-cl` の `JUYAKL`(ILE CL 版)経由で
  既に取れている)。

## 期待される結果

- `CPSETENV`・`CPJUYAKC` とも Highest Severity 00 で成功する。
- `RUNSETENV` が成功し、`VFYLOG` のダンプに
  `SETENV: now *DEV (curlib=<CURUSER>1)` という1行が現れる。ここで
  `<CURUSER>` は実際にサインオン(このハーネスの場合は鍵認証で SSH
  接続した)ユーザー名そのものであるべきで、`QUSER1` になっていたら
  修正が効いていない(`RTVJOBA CURUSER()` ではなく実質 `USER()` と
  同じ値が返っている)ことを意味する。
- FAIL は想定していない。もし `RUNSETENV` が FAIL と判定された場合、
  `MCH0000`(呼び出し自体のエラー)か `CPF2105` 以外の `RMVLIBLE` の
  エラーが疑われる。

## この結果が付録Cに与える影響

- `<CURUSER>1` が正しく報告された場合: `docs/appendix/c-troubleshooting.md`
  節3の「まだ実機で確認していない」という注記を、`docs/probes.md` への
  日付付き記録とともに「実機で確認済み(V2)」に更新する。
- `QUSER1` のままだった場合: 修正そのものが誤りだった(`RTVJOBA` の
  キーワード解釈を再度一次資料に当たり直す)ことになるので、
  `txsetup.clp`/`juyakl.clle` で既に確認済みの挙動との食い違いを先に
  洗い出してから再修正する。
