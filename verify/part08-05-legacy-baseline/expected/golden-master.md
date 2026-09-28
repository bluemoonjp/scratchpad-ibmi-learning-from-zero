# part08-05-legacy-baseline の実機出力(ゴールデン・マスター、確認日2026-09-28)

これは予測ではない。`part08-05-legacy-baseline`接続の`run`セクション(接続
自体の生ログ、`work/verify/results/`は`.gitignore`済みのためここに手で
書き写した)から、実際に印字された行をそのまま転記したもの。08-05
(`F0805A`、`JU0300`の制御レベル処理の書き直し)・08-05b(`F0805B`/
`Q0805B`、`ZA0500`のM1/MR処理のSQL書き換え)は、それぞれの新しい版の
出力をこのファイルと突き合わせて「差分0」を示す。

前提: 実行前に`&LIB/TXRESET`済み(`db/data/load_v1.sql`のとおりの
初期状態)。`JU0300`はパラメーター無し、実行前に`*LDA`バイト11-16
(FTOKフィルター)を空白にクリア済みなので全件が印字されている。
`ZA0500`は`JU0900C`経由、`RUNMODE='*TEST'`(`ZAIKOM`は一切書き換えない
——実行前後の`SELECT`で6件とも完全に同一であることを確認済み)。

## JU0300 の印字内容

制御レベルL1=JUDATE(日付、内側)・L2=JUTOK(得意先、外側)。
列位置は`src/legacy/qrpgsrc/ju0300.rpg`のO仕様のとおり(`JUNO`10桁目・
`JUTOK`20桁目・`JUDATEZ`32桁目・`JUTAN`42桁目、L1BRKは`JUTOK`10桁目+
`JUDATEZ`22桁目+`DATE TOTAL`45桁目+`L1CNT`55桁目、L2BRKは`JUTOK`10桁目+
`CUST TOTAL`45桁目+`L2CNT`55桁目、GTOTは`GRAND TOTAL`20桁目+`GCNT`30桁目+
`XFOOT=`40桁目+`XTOT`50桁目+OK/MISMATCH)。

```text
     J00001    C00001    20260901    T00001
     C00001    20260901             DATE TOTAL         1
     J00003    C00001    20260905    T00001
     C00001    20260905             DATE TOTAL         1
     C00001                         CUST TOTAL         2
     J00002    C00002    20260902    T00001
     C00002    20260902             DATE TOTAL         1
     C00002                         CUST TOTAL         1
     J00004    C00003    20260906    T00002
     C00003    20260906             DATE TOTAL         1
     J00008    C00003    20260912    T00002
     C00003    20260912             DATE TOTAL         1
     C00003                         CUST TOTAL         2
     J00005    C00004    20260908    T00002
     C00004    20260908             DATE TOTAL         1
     C00004                         CUST TOTAL         1
     J00006    C00005    20260910    T00003
     C00005    20260910             DATE TOTAL         1
     C00005                         CUST TOTAL         1
     J00007    C00006    20260911    T00003
     C00006    20260911             DATE TOTAL         1
     C00006                         CUST TOTAL         1
          GRAND TOTAL         8    XFOOT=         8        OK
```

8件の注文(JUCHUM)、6名の得意先(C00001〜C00006)、XFOOT(クロス・フッティング
検算、`CT`配列の合計と`GCNT`の独立集計が一致)は`OK`。`db/data/load_v1.sql`の
`JUCHUM`(`J00001`〜`J00008`)と一致。

## ZA0500(JU0900C経由)の印字内容

列位置は`za0500-ticket3.rpg`(`solutions/05-13/za0500-ticket3.rpg`、
チケット1はJU0900C側の`&MINQTY`修正、チケット3は`*PSSR`追加——今回の
クリーンなデータでは`*PSSR`は発火していない)のO仕様のとおり
(`JUNO`6桁目・`JUSHO`14桁目・`JUSU`21桁目・NOTFOUND/SHORT/OK30桁目)。

```text
 J00001  P00001  00002       OK
 J00001  P00003  00005       OK
 J00002  P00002  00001    SHORT
 J00003  P00004  00010       OK
 J00003  P00005  00003       OK
 J00004  P00001  00001       OK
 J00005  P00006  00002       OK
 J00005  P00003  00010       OK
 J00006  P00002  00002    SHORT
 J00007  P00005  00005       OK
 J00008  P00001  00003       OK
 J00008  P00004  00002       OK
```

12行(OK10・SHORT2・NOTFOUND0)——`verify/part05-13-tickets/expected/notes.md`
が手計算で予測していた行数・内訳とも完全に一致した(あちらは予測、
これは初めての実機確認)。

## 比較方法についての注記

`JU0300`・`ZA0500`はどちらもQSYSPRTへの印字のみで、SQLで`EXCEPT`できる
表を持たない。`TXSNAP`(`CPYSPLF`ラッパー)はこのハーネスの非対話SSH
ジョブでは実スプール・ファイルが作られないためV3専用(`docs/probes.md`の
`part05-ju0900c-baseline`節で確認済み)。08-05/08-05bの「差分0」確認は、
新しい版(`F0805A`/`F0805B`・`Q0805B`)を同じ接続内で実行し、その`run`
セクションの生テキストをこのファイルの内容と**このハーネスの外で
(ローカルで文字列として)**突き合わせる方法を取る。
