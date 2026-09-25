**FREE
// ハーネス自己診断: わざとゼロ除算させ、RPG0102(照会・重大度99)が
// CHGJOB INQMSGRPY(*DFT) によって自動応答され、非対話ジョブがハングしないことを確認する。
// (04-12 で確認した RPG0102 の再現手順と同じ形。)
dcl-s a int(10) inz(10);
dcl-s b int(10) inz(0);
dcl-s c int(10);

c = a / b;

*inlr = *on;
