# part10-00b-dbver2 の期待値(手計算、実機未確認)

第10部H0の後半。TXMIGR TO(2)でJUCHUMをv2(JUDLV付き)にする。**対象は
`<USER>B`(`library2: "*B"`)であり`<USER>2`ではない**(`part05-txmigr-to2`と同じ)。
`<USER>2`はDBVER 1のまま残る。**`part10-00-probe`の後に実行する。**

## 読む順序(ゲート)

1. `VFYLOG`の`TXSETUP: done. DBVER=1.`(`TX10RUN`経由)。無ければ`B1-V1`以降は無意味。
   `TXSETUP`は失敗しても`*COMP`で正常終了する(`part05-txmigr-to2/expected`参照)。
2. `VFY10CNT`の`B1-V1`: `JUCHUM cols`=4、`JUDLV col`=0。これが4でなければ
   PRECLEANが効かず(JUCHUMに依存するLFが他にある等)、v2のまま始まっている。
3. `VFYLOG`に`TXMIGR: done.`(接頭辞だけで判定。`DBVER=`の桁はゼロ埋めされうる)。
4. `B0-LIB`/`B0-LIB2`(開始時点の状態): `<USER>B`が前回の`to2b`でv2のまま残っていれば
   `B0-LIB2`の`JUDLV col`=1になる(異常ではない。PRECLEANが直す)。

## ステップごとの合格基準と記録

| ステップ | 合格基準 | 記録するもの |
|---|---|---|
| PRECLEAN + TXSETUP FORCE | `B1-V1`: cols=4, JUDLV=0。`ST1LIB2`が`DBVER=...1` | `<USER>B`がv1に戻ったこと。`ST1RAW`(TXSETUP直後の生の値)が`2`なら、TXSETUPは既存のTXSTATEを1に戻さない(データエリアが無いときだけ作る)という確認になる。`SETDBV1`が手で1に戻す |
| TXLEGACY FORCE(<USER>B) | `VFYLOG`に`TXLEGACY: done.` | `<USER>B`にレガシー・プログラム一式ができたこと |
| チケット1修正をメンバーJU0900Cへ | `FIXMBR`成功、`CPJU0900C`成功 | TXMIGRがメンバーから全*PGMを再コンパイルするため、TXMIGR**前**にメンバーを直しておく(直さないと3,0のバグが戻りRPG0907がDBVER 2の影響に見える) |
| TXRESET(v1) | `B2-V1-RESET`: JUCHUM=8, JUCHUD=12 | |
| 列指定INSERT(v1) | `B5-V1`: INSERT後1、DELETE後0 | |
| TXMIGR TO(2) | `B5-POST-MIGR`/`B6-POSTMIGR`: cols=5, `JUDLV col`=1 | `ST2LIB2`は**まだ`DBVER=1`**のはず(TXMIGRはTXSTATEを書かない。05-09の記述どおり) |
| (a) 列指定INSERT、JUDLV省略(v2) | `B6-V2-COLLIST`の行が1なら成功。`VFY10TXT`の`JUDLV=<...>`が既定値 | **成功か`SQL0407`か、成功なら格納された日付(`0001-01-01`等)。TXCAPSTのDBVER 2分岐の要否を決める** |
| (b) JUDLV明示INSERT(v2) | `B6-V2-EXPLICIT`=1、`JUDLV=<2026-09-30>` | (a)が失敗した場合の代替が使えること |
| TXRESET(v2)(リスク6) | `B7-V2-RESET`: 8/12/6行、`VFY10TXT`の`B7-V2-RESET`行にJUDLV | `load_v1.sql`はJUDLVなしの列指定INSERTなので、(a)と同じ結果になるはず。失敗すれば行数が0/部分的 |
| CHGDBVER | `ST3LIB2`が`DBVER=...2`。`ST3LIB`(<USER>2)は`...1`のまま | `<USER>2`が動いていないこと |
| **最後のclステップ** JU0900C(v2) | 12行(OK 10、SHORT 2)なら合格。それ以外は**そのまま記録** | ZA0500が`JUCHUM IS F 26 DISK`のままv2(32バイト)を読んで動くか(リスク2)。失敗ならRPG/CPFのメッセージIDを`VFYLOG`から書き写す |

## 注意

- v1の12行は`part10-00-probe`で確認する(`JU0900C`はこの接続では、`TXMIGR`のCHGPFが
  開いたままのODPに邪魔される恐れがあるためv1では実行しない)。
- JU0900Cの印字行はrunセクションに出る。
- この接続の後、`<USER>B`はv2レイアウト+`TXSTATE=2`。**元に戻す手順は
  `work/verify/handoff-10-00.md`の「戻し方」を読むこと。**
- `TXMIGR`のStep 2(LFの再作成、DLTFなしのCRTLF)は`JUCHUL1`が既にあるので
  失敗する見込み(`part05-txmigr-to2b`の結論)。このバッチは`DLTJUL1`/`CRTJUL1`で作り直す。

## 実機結果 2026-09-29(part10-00b-dbver2-2026-09-29T23-09-48-930Z.json)

手計算どおり全ステップ合格。(a) 列指定INSERT・JUDLV省略はDBv2でも成功し、JUDLVは
`CURRENT_DATE`(SYSCOLUMNSのCOLUMN_DEFAULT、NOT NULL)が入る(`JUDLV=<2026-09-29>`。SQL0407は出ない)。
(b) 明示INSERTも成功。TXRESET(v2)は8/12/6行、全JUCHUM行のJUDLVは投入日。JU0900C(v2)は
12行(OK 10、SHORT 2)。ZAIKOMの合計は392のまま。`ST2LIB2`は`DBVER=1`(TXMIGRはTXSTATEを書かない)。
`TXMIGR: done. DBVER=0000000002`という完了メッセージは列の有無から出るだけで、TXSTATEの値ではない。
注意: `VFY10CNT`のMK10*が`CREATE OR REPLACE`だけだと前回(part10-00-probe)の行が残った
(P0-*/P3-*/P5-*タグの行が混ざる)ため、`ON REPLACE DELETE ROWS`を付けた。ZA0500はTXMIGRのStep 3で
v2のJUCHUMに対して再コンパイルされた後の結果である(v1でコンパイルしたままでは試していない)。
再実行時は`B9-AFTER`行(RUNV2後のZAIKOM合計とJUCHUM行数)も出る。
