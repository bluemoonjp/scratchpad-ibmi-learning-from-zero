# 06-12 印刷装置ファイルで帳票を出す、コマンドの CPP を初めて差し替える

> 所要時間: 75分(長め)/ 前提レッスン: 06-11 / 目標番号: 5 / 観測方法: `WRKSPLF`・画面そのもの / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・`CHGCMD`・`F4`)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/P0612A`(PRTF)・`<USER>1/F0612A`・`<USER>1/F0612B`・`<USER>1/F0612C`(いずれもRPG)、`<USER>1/JUCINQ`(既存コマンド、CPPを`F0612A`へ変更)/ DBVER: 1 / 依存するプローブ: P17(未実施)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- 印刷装置ファイル(PRTF)を DDS で書き、`SPACEB`/`SKIPB`/`EDTCDE` で帳票のレイアウトを組み立てられる。
- `dcl-pi` の**もう1つの使い方**(プログラム本体の`*ENTRY PLIST`を置き換える形)を、06-05のサブプロシージャー用`dcl-pi`と区別して説明できる。
- `CHGCMD` でコマンドの CPP(コマンド処理プログラム)を差し替えても、コマンド自身のインターフェース(パラメーターの型)は変わらないことを、実際に確認する。
- `OFLIND` でページ・オーバーフローを検知し、改ページ時に帳票の見出しを再印字できる。
- 06-11 で積み残した「オプション5で得意先コードが渡らない」を、`OPTIONS(*NOPASS)`/`%PARMS` を使う新しいプログラムで解消する。

## ウォームアップ

<details><summary>前回の復習(06-11)</summary>

1. `readc sfl1;` のあと `dow not %eof(...)` と書くとき、`%eof` に渡すのはサブファイルのレコード様式名(`SFL1`)と表示装置ファイル名(`D0611A`)のどちらですか?
2. `F0611A` のオプション `5` で `F0604A` を呼び出したとき、選ばれた行の得意先コード(`JUTOK`)は自動的に `F0604A` へ渡りますか?

答え: 1. 表示装置ファイル名(`D0611A`)です。`%EOF`/`%FOUND` はどちらもファイル名を引数に取ります(レコード様式名を渡すと `RNF0391`/`RNF0394` になります)。 2. **渡りません。** `F0604A`(06-04)は `dcl-f d0604a workstn;` のみでパラメーターを一切持たないため、`F0611A` からの呼び出しは `dcl-pr f0604a extpgm('F0604A') end-pr;` のとおりパラメーターなしの形になっており、呼ばれた `F0604A` 側の画面で得意先コードを入力し直す必要がありました。

</details>

## なぜ学ぶか

04-08 で作った `R0408A`(JUCINQ3)は、得意先コードを `MOVEL'C00001' CUST 6` という**固定のリテラル**で持っていました。03-11 で `JUCINQ` コマンドを作ったとき、「今後この CPP を差し替えていく」と予告しましたが、`R0408A` 自身には C 仕様書の `*ENTRY PLIST` すら無く、呼び出し元から値を受け取る手段がありません。**固定のリテラルしか持たないプログラムは、そもそもコマンドの CPP にはなれません。** コマンドの CPP になるには、呼び出し元(コマンド)が渡す値を実際に受け取る入口が要ります。

**それが、このレッスンで初めて教える、プログラム本体の `dcl-pi` です。** 06-05 で見た `dcl-pi` は、`dcl-proc` の中に書く、**1つの手続き**のためのインターフェースでした。今回の `dcl-pi` は `dcl-proc` の外、ソースの一番先頭に書く、**プログラム自身**の入口です。固定形式 RPG の `C *ENTRY PLIST`/`C PARM` に相当します。この入口さえあれば、`R0408A` と同じロジックを持つプログラムでも、コマンドから実際に値を受け取れます。

今回作る `F0612A`(業務ニックネーム: `JUCINQ4`、通し例10)は、`R0408A` の CHAIN+READ ロジックを `**FREE` に移植し、固定リテラルの代わりにプログラム本体の `dcl-pi` で得意先コードを受け取ります。そのうえで `CHGCMD CMD(<自分のユーザー名>1/JUCINQ) PGM(<自分のユーザー名>1/F0612A)` を実際に実行し、**03-11 以来ずっと予告されてきた CPP の差し替えを、このリポジトリーで初めて実機で検証します。**

あわせて、06-11 で積み残した「`F0611A` のオプション5から `F0604A` を呼んでも得意先コードが渡らない」という制約も、ここで解消します。ただし **`F0604A`・`F0611A` 自身は書き換えません**——それぞれのレッスンの実演がすでに「パラメーターなしの `F0604A`」を前提に書かれているためです。代わりに、このレッスン自身が所有する新しいオブジェクト(`F0612B`・`F0612C`)を追加し、そちらで `dcl-pi` の `OPTIONS(*NOPASS)` を使います。

## 新出

- 中核概念:
  1. `dcl-pi` には**2つの使い方**があります。06-05 で見た**サブプロシージャー用**(`dcl-proc` の中)と、**プログラム本体の `*ENTRY PLIST` を置き換えるもの**(`dcl-proc` の外、ソースの先頭)です。今回は後者を初めて扱います。
  2. O仕様書の桁位置は、PRTF(印刷装置ファイル)の DDS では `SPACEB`/`SKIPB`/`EDTCDE` というキーワードに置き換わります。
  3. コマンドの CPP は `CHGCMD`/`CRTCMD` で差し替えられ、**呼び出し側(コマンド自身のインターフェース)は一切変えなくてよい**——03-11 で予告された「コマンドは型付きのインターフェースである」という言葉を、ここで初めて実機で検証します。
- 構文:
  - `SPACEB`/`SKIPB`(このレコードを印字する前に、指定した行数だけ空ける/指定した行まで飛ぶ。どちらも「このレコードを印字する前の縦位置」を指定する同じ系統のキーワードです)
  - `EDTCDE`(DDS の O仕様書側の編集コード指定。外部記述の印刷ファイルでは RPG 側から上書きできません)
  - `CRTPRTF`(PRTF をコンパイルするコマンド)
  - `oflind`(オーバーフロー標識を RPG 側に結び付けるファイル・キーワード)
  - `dcl-pi`(プログラム本体用の書き方)
  - `CHGCMD`(既存コマンドの CPP などを変更する)

読解できれば十分な(新出扱いしない)コマンド: `OVRPRTF`(`PAGESIZE`/`OVRFLW` でページ長・オーバーフロー行を一時的に上書きするコマンド。改ページの演習でのみ使います)。

## 説明

### `dcl-pi` のもう1つの使い方: プログラム本体の `*ENTRY PLIST`

06-05 の `F0605A` では、`dcl-proc calcTaxTotal;` の中に `dcl-pi *n packed(9:2); ... end-pi;` を書きました。これは `calcTaxTotal` という**1つの手続き**のインターフェースです。

今回の `F0612A` はこう書きます。

```rpgle
dcl-pi *n;
  cust char(6);
end-pi;
```

**この `dcl-pi` は `dcl-proc` の外、ソースの一番先頭にあります。** これは `calcTaxTotal` のような個々の手続きではなく、**プログラムそのもの(サイクル・メイン手続き)**の入口です。固定形式 RPG の `C *ENTRY PLIST`/`C PARM` にあたる、`**FREE` 側の書き方です。プロトタイプを持たないプログラム本体の `dcl-pi` では、名前の代わりに `*N` を使います(一次資料・ILE RPG言語リファレンスの規定によります)。

`cust` という名前にも理由があります。呼び出し元(`JUCINQC`)側の CL 変数名は `&TOKCD` ですが、ここで `tokcd` という名前を使うと、後で `dcl-f tokuim keyed` を書いたときに TOKUIM の外部記述フィールド `TOKCD` と名前が衝突してしまいます。プログラム呼び出しのパラメーターの対応は**位置だけ**で決まり、受け取る側のローカルな名前は呼び出し元との互換性に影響しません。そこで `R0408A` 自身のローカル変数名(`MOVEL'C00001' CUST 6`)にならい、`cust` としています。

### `JUCINQ`/`JUCINQC` のインターフェースと `F0612A` のパラメーターが一致していなければならない理由

`CHGCMD` は「コマンド定義オブジェクトのパラメーター記述や妥当性検査の情報を変えない」(一次資料・CLコマンドの解説による)——つまり CPP を差し替えても、**呼び出し元から見えるコマンドの姿は一切変わりません。** 裏を返せば、新しい CPP のパラメーター・リストが、コマンドが実際に渡す値と食い違っていれば、既存の呼び出し元を静かに壊します。`JUCINQC`(03-09)の `&TOKCD`、`JUCINQ` コマンド(03-11)自身の `PARM KWD(TOKCD) TYPE(*CHAR) LEN(6) MIN(1)`、どちらも「6桁、固定長、省略不可の文字列を1つ」で一致しています。`F0612A` の `dcl-pi` もこれと同じ形(`char(6)` を1つ)で受けなければなりません。

### `P0612A`: PRTF の DDS(抜粋)

`src/qddssrc/p0612s.prtf` の主要部分です。

```text
     A          R RPTHDR
     A                                      SKIPB(1)
     A                                     2'JUCINQ4 - ORDER INQUIRY REPORT'
     A                                    40'CUSTOMER:'
     A            RPTCUST        6A  O    50
     A          R RPTDTL
     A                                      SPACEB(1)
     A            RPTNM         30A  O     2
     A            RPTJUNO        6A  O    34
     A            RPTJUDT        8S 0O    42EDTCDE(3)
     A          R RPTTOT
     A                                      SPACEB(2)
     A            RPTCNT         5S 0O     2EDTCDE(3)
     A                                    10'ORDER(S) FOR THIS CUSTOMER'
```

`R0408A`(04-08)の O仕様書は、行の**終了桁**で位置を指定していました(`O TOKNM 30` など)。PRTF の DDS では、フィールドの**開始桁**(42〜44桁目)で指定します。`SPACEB(n)` は「このレコードを印字する前に n 行空ける」、`SKIPB(n)` は「このレコードを印字する前に n 行目まで飛ぶ」という指定です(いずれも一般的な DDS の知識に基づくもので、`SPACEB`/`SKIPB` というキーワード自体を明記した一次資料はこの教材のリポジトリー内にはまだ取り込めていません——`EDTCDE` は一次資料で確認済みです)。

フィールド名(`RPTNM`/`RPTJUNO`/`RPTJUDT`/`RPTCUST`/`RPTCNT`)は、`TOKUIM`/`JUCHUM` 自身のフィールド名(`TOKNM`/`JUNO`/`JUDATE`/`TOKCD`/`JUTOK`)とわざと違えてあります。同名フィールドの自動共有(06-04 で見た仕組み)が、この帳票専用のフィールドとデータベース側のフィールドを誤って混ぜてしまわないようにするためです。

### 編集コードのゼロ残高表示: 奇数(1・3)が表示、偶数(2・4)が空白

`RPTCNT`(件数)は `EDTCDE(3)` です。**04-08 で訂正したとおり(`docs/part04/04-08-jucinq3-report.md` を参照)、ゼロ残高を表示するのは奇数の編集コード(1・3)側で、偶数(2・4)側が空白にします。** `RPTCNT` は「該当する注文が0件でも `0` と表示したい」件数フィールドなので、`EDTCDE(3)`(表示する側)を使っています。小数点以下の桁数がないフィールドでは、ゼロ残高を表示する側は一の位に `0` が1桁だけ印字されます。

### `F0612A`: `R0408A` のロジックを移植し、サイクルを使わない小計を加える

`src/qrpglesrc/f0612s.rpgle` の主要部分です(ヘッダーの説明コメントは省略しています)。

```rpgle
dcl-pi *n;
  cust char(6);
end-pi;

dcl-f tokuim keyed usage(*input);
dcl-f juchum usage(*input);

dcl-f p0612a printer usage(*output) oflind(*in01);

dcl-s orderCnt zoned(5:0) inz(0);

chain (cust) tokuim;
if %found(tokuim);
  rptnm = toknm;
else;
  rptnm = 'NOTFOUND';
endif;
rptcust = cust;

write rpthdr;

read juchum;
dow not %eof(juchum);
  if jutok = cust;
    orderCnt += 1;
    rptjuno = juno;
    rptjudt = judate;
    write rptdtl;
  endif;
  read juchum;
enddo;

rptcnt = orderCnt;
write rpttot;

*inlr = *on;
return;
```

`CHAIN`+`READ`+`%found`/`%eof` の形は 06-04 の `F0604A` と同じです。**ただし `USAGE` を明示している点は 06-04 と同じ流儀ではありません**——`F0604A` 自身は `dcl-f tokuim keyed;`/`dcl-f juchum;` と `USAGE` を書かず既定値(`*INPUT`)に任せています。`F0612A` はここで `usage(*input)` をあえて明記する書き方を新しく採っています(後述の `F0612B` は `dcl-f tokuim keyed;`/`dcl-f juchum;` と `USAGE` を書かない点で、むしろ `F0604A` と同じ流儀です)。**新しいのは `orderCnt` という小計です。** `JUCHUM` には数量・金額のようなフィールドが無いため(`db/v1/juchum.pf` には `JUNO`/`JUTOK`/`JUDATE`/`JUTAN` しかありません)、単一得意先の帳票として自然な小計は「一致した注文の件数」です。**RPGサイクルの L1/LR 自動集計は一切使っていません**——`orderCnt` という素朴な変数を自分で加算し、ループの後で明示的に `WRITE RPTTOT` しています。

**もう1つの注意点: `cust` が存在しない得意先コードのとき、`RPTNM`(`'NOTFOUND'`)は帳票に一度も印字されません。** `RPTNM` は `RPTDTL`(明細行)のフィールドであり、`RPTDTL` は `JUTOK = cust` に一致する注文があったときしか `WRITE` されないためです。一致する注文が0件の場合、印字されるのは `RPTHDR`(得意先コードのエコー)と `RPTTOT`(`0   ORDER(S) FOR THIS CUSTOMER`)だけで、`NOTFOUND` という文字列自体は帳票のどこにも現れません。演習でこの点を実際に確認します。

### `OFLIND`: 外部記述PRTFで通る形・通らない形

外部記述の PRTF(`P0612A`)に対して `oflind` を指定するとき、書き方によってコンパイルが通るかどうかが分かれます。実際に試すと、次の4つの形になります。

1. `dcl-ind ovf;`(実在しないキーワード)→ `RNF5347`/`RNF7030`(未定義の名前として連鎖的に失敗)。
2. `dcl-s ovf ind;`+`oflind(ovf)` → `RNF2037`(「Overflow Indicator is already defined」、severity 20)。
3. `oflind(*inoa)`(名前付きの特殊値、`dcl-s` 無し)→ `RNF2014`(「The parameter for keyword OFLIND is not valid」、severity 20)。**この外部記述 PRTF に対しては、`*INOA` は拒否されます**(同じ `*inoa` が、内部記述の PRTF、たとえば `QSYSPRT` に対しては問題なくコンパイル・実行できることも、`part06-decisions-2`(2026-09-27)の接続で確認できています——V2、100行分の印字を接続の生ログの`run`セクションで確認)。
4. `oflind(*in01)`(番号標識版)→ **コンパイル成功(Highest Severity 00)。**

一次資料(ILE RPG言語リファレンス、`ilerpgref75.txt`)は `*INOA`〜`*INOG`/`*INOV`(名前付き)と `*IN01`〜`*IN99`(番号)の両方を `OFLIND` の有効なパラメーターとして挙げていますが、同じ箇所に「`Indicators *INOA through *INOG, and *INOV are not valid for externally described files.`」(外部記述ファイルには無効)という注記があります。**外部記述 PRTF に対して番号標識版だけが使えるのは、このPUB400固有の挙動ではなく、ILE RPGの一般仕様です。** 実機での失敗(`RNF2014`)は、この一次資料の記述と一致することを確認したにすぎません。`f0612s.rpgle` は最終形として `oflind(*in01)` を採用しています。

### 改ページ: `*IN01` は実際に発火し、見出しを再印字できる

`OVRPRTF FILE(P0612A) PAGESIZE(12 132) OVRFLW(10)` でページ長・オーバーフロー行を強制的に小さくし、`RPTDTL` を何行も書くループを実行すると、`*IN01` が実際にオーバーフローで ON になることが確認できます。次のような形で見出しを再印字できます。

```rpgle
write rptdtl;
if *in01;
  write rpthdr;      // 見出しを書き直す
  *in01 = *off;      // 標識をOFFに戻す(自動では戻らない)
endif;
```

**この確認は、`F0612A` 自身ではなく、`P0612A` のレコード様式を再利用した小さな使い捨てプログラムで行っています。** サンプル・データ(1得意先あたり最大2件)だけでは、実際にページがあふれることが無いためです。下の演習で同じ形を自分の手でたどります。

### `F0612B`・`F0612C`: 06-11 の積み残しを、新しいオブジェクトで解消する

06-11 の `F0611A` のオプション5は、`F0604A` にパラメーターが無いため、得意先コードを渡せていませんでした。**`F0604A`・`F0611A` 自身は書き換えません**(どちらのレッスンの実演も、すでにその姿を前提に書かれているためです)。代わりに、このレッスンが所有する2つの新しいオブジェクトで解消します。

`src/qrpglesrc/f0612bs.rpgle`(`F0612B`。DDS は `D0604A` をそのまま再利用します)。

```rpgle
dcl-pi *n;
  custCode char(6) const options(*nopass);
end-pi;

dcl-f d0604a workstn;
dcl-f tokuim keyed;
dcl-f juchum;

dcl-s ordCount packed(3:0);

if %parms >= 1 and custCode <> *blanks;
  tokcd = custCode;
endif;

dow not *in03;
  exfmt jucfmt;
  ...
```

`custCode` には `options(*nopass)` が付いています。**これがあるおかげで、`CALL PGM(F0612B)` のようにパラメーターを渡さない呼び出しも、`F0604A` と同じようにそのまま成立します。** `%parms`(渡された実引数の個数)を見て、実際に渡された(かつ空白でない)ときだけ、`EXFMT` より前に `TOKCD` へ代入します。呼び出し元がある場合は最初から得意先コードが埋まった状態で画面が出ますが、`EXFMT`(=`Enter` を押す)自体は省略できません。

`src/qrpglesrc/f0612cs.rpgle`(`F0612C`。DDS は `D0611A` をそのまま再利用します)。

```rpgle
dcl-pr f0612b extpgm('F0612B');
  custCode char(6) const options(*nopass);
end-pr;
```

```rpgle
select;
  when opt = '5';
    callp f0612b(jutok);
```

`F0611A` との違いはこの1行だけです。`READC` で選択された行の `JUTOK`(同名フィールドの自動一致で画面欄に入っています)を、そのまま `F0612B` へ渡しています。**`F0612C` には `ctl-opt dftactgrp(*no) actgrp(*new);` が付いています**(06-05 で見たとおり、`sendInvalidOpt` という独自のサブプロシージャーを持つためです)。`F0612A`・`F0612B` にはサブプロシージャーが無いため、この `ctl-opt` は付いていません。

## 実演

**この実演で作る4つのオブジェクト(`P0612A`・`F0612A`・`F0612B`・`F0612C`)は、著者による実機コンパイル(V1、下の「実機メモ」参照)まで確認済みです。`F0612A` の直接 `CALL` と `CHGCMD` によるコマンド切り替えは、この教材の検証ハーネス(非対話SSH)でも実際に確認できています(V2)。ただし `F0612B`・`F0612C` はどちらも `WORKSTN`/`EXFMT` を含む対話プログラムのため、実際の画面操作(`F0612B`・`F0612C` の画面遷移、手順6の `F4` プロンプトを含む)は学習者自身の5250セッションで確認してください(V3。04-11以来のこの教材の既知の制約です)。**

1. SSHで接続し、`~/ibmi-kyozai` を最新にする(`git pull`)。

2. ソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qddssrc/p0612s.prtf') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QDDSSRC.FILE/P0612A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0612s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0612A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0612bs.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0612B.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0612cs.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0612C.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、コンパイルする(`D0604A`・`D0611A` は06-04・06-11ですでに作成済みのはずです。無ければ先にそれぞれのレッスンの手順でコンパイルしてください)。

   ```text
   CRTPRTF FILE(<自分のユーザー名>1/P0612A) SRCFILE(<自分のユーザー名>1/QDDSSRC) SRCMBR(P0612A)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0612A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0612A)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0612B) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0612B)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0612C) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0612C)
   ```

   4つとも `Highest Severity 00` になることを確認してください。

4. `CALL PGM(<自分のユーザー名>1/F0612A) PARM('C00001')` を実行し、`WRKSPLF` で次の内容が印字されることを確認してください(スプール・ファイル名は `P0612A` です)。

   ```text
   JUCINQ4 - ORDER INQUIRY REPORT        CUSTOMER: C00001
   ACME TRADING CO                 J00001  20260901
   ACME TRADING CO                 J00003  20260905
       2   ORDER(S) FOR THIS CUSTOMER
   ```

   `R0408A`(04-08)が印刷したのと同じ2件(`J00001`/`J00003`)に、見出しと件数の小計が加わった内容です。**この4行のテキスト自体と出現順序は実機で確認済みですが、`SPACEB`/`SKIPB` が実際に何行分の空白行を生んでいるかや、各フィールドが何桁目から始まっているかまでは、このハーネスの接続結果の`run`セクションのテキストからは確認できていません(下の「実機メモ」参照)。空白行の行数・桁位置を含めた正確なレイアウトは、学習者自身の `WRKSPLF` での確認を基準にしてください。**

5. **CPP を実際に差し替えます。**

   ```text
   CHGCMD CMD(<自分のユーザー名>1/JUCINQ) PGM(<自分のユーザー名>1/F0612A)
   ```

   `JUCINQ` コマンド(03-11)の CPP は、これまで `JUCINQC`(03-09、CL)でした。この1行で、**コマンド自身の定義(`PARM KWD(TOKCD) TYPE(*CHAR) LEN(6) MIN(1)`)を一切変えずに**、実体を `F0612A` へ差し替えます。

6. `JUCINQ TOKCD('C00001')` を実行してください(`JUCINQ` とだけ打って `F4` を押し、`Customer code` 欄に入力する形でも構いません——`F4` プロンプト自体は対話操作なので、学習者自身の5250セッションで確認してください)。手順4と**まったく同じ内容**が、今度は `JUCINQ` コマンド経由で印字されることを `WRKSPLF` で確認してください。**コマンドのインターフェースは何も変わっていないのに、実体だけが差し替わったことが、これで確認できます。**

## 演習

1. **(ゼロ件のケース)** `CALL PGM(<自分のユーザー名>1/F0612A) PARM('C99999')`(存在しない得意先コード)を実行してください。`WRKSPLF` で、見出し行に `CUSTOMER: C99999` は出るものの、`NOTFOUND` という文字列はどこにも印字されず、`0   ORDER(S) FOR THIS CUSTOMER`(`RPTCNT` の `EDTCDE(3)` が0を表示している)とだけ印字されることを確認してください。`RPTNM`(`NOTFOUND` が入っているフィールド)は `RPTDTL` にしか無く、`RPTDTL` は一致する注文がある行しか `WRITE` されないため、という理由を自分の言葉で説明してください。
2. **(改ページ)** `P0612A` のレコード様式(`RPTHDR`/`RPTDTL`)を再利用する、次のような小さな使い捨てプログラムを自分で入力・コンパイルしてください(データベース・ファイルは一切使いません)。

   ```rpgle
   **FREE
   dcl-f p0612a printer usage(*output) oflind(*in01);

   dcl-s i packed(3:0) inz(0);
   dcl-s hdrCount packed(3:0) inz(1);

   rptcust = 'HDR001';
   write rpthdr;

   dow i < 20;
     i += 1;
     rptnm = 'OFLIND HDR PROBE LINE';
     rptjuno = %char(i);
     rptjudt = 0;
     write rptdtl;
     if *in01;
       hdrCount += 1;
       rptcust = 'HDR00' + %char(hdrCount);
       write rpthdr;
       *in01 = *off;
     endif;
   enddo;

   *inlr = *on;
   return;
   ```

   実行前に、次のコマンドでページ長・オーバーフロー行を小さく上書きしてください。

   ```text
   OVRPRTF FILE(P0612A) PAGESIZE(12 132) OVRFLW(10)
   ```

   `CALL` して `WRKSPLF` を確認すると、見出し(`JUCINQ4 - ORDER INQUIRY REPORT ... CUSTOMER: HDR001`)を書いてから9行分の `RPTDTL` を書いたところで一度 `*IN01` が ON になって見出しが `HDR002` として再印字され、続けてもう9行分(合計18行分)書いたところでもう一度発火して `HDR003` になる、という形になるはずです(実際にこの教材が確認したのと同じ形です。下の「実機メモ」参照)。終わったら `DLTOVR FILE(P0612A)` で上書きを解除し、使い捨てプログラムは削除してください。
3. **(F0612B/F0612C)** `CALL PGM(<自分のユーザー名>1/F0612C)` を実行し、一覧(06-11の `F0611A` と同じレイアウト)のオプション欄に `5` を入力してください。呼ばれた `F0612B` の画面で、`Customer code` 欄に選んだ行の得意先コードがすでに入っていることを確認してください(`F0611A` から素の `F0604A` を呼んだときは、この欄は空のままで自分で入力し直す必要がありました)。

## セルフチェック

- [ ] プログラム本体の `dcl-pi` と、06-05のサブプロシージャー用 `dcl-pi` の違いを説明できる。
- [ ] `SPACEB`/`SKIPB`/`EDTCDE` の役割を、O仕様書の桁位置との対比で説明できる。
- [ ] `EDTCDE(3)` がゼロ残高を表示し、`EDTCDE(4)` が空白にする、という向きを説明できる。
- [ ] `CHGCMD CMD(...) PGM(...)` でコマンドの CPP を差し替え、コマンド自身のインターフェースが変わらないことを確認できた。
- [ ] `oflind(*in01)` でオーバーフローを検知し、見出しの再印字を実際に確認できた(またはどこで詰まったかを説明できる)。
- [ ] `F0611A` のオプション5が得意先コードを渡さない制約を、`F0612B`・`F0612C`(`OPTIONS(*NOPASS)`/`%PARMS`)でどう解消したかを説明できる。

## 片付け

`P0612A`・`F0612A`・`F0612B`・`F0612C` はそのまま残してください。**`JUCINQ` コマンドの CPP は `F0612A` に差し替えたままで構いません**(戻す必要はありません)——03-11以来の「コマンドの CPP を差し替えていく」という流れの到達点です。`D0604A`・`F0604A`・`D0611A`・`F0611A`(06-04・06-11のオブジェクト)は変更していないので、そのまま使えます。演習2で作った使い捨てプログラムと `OVRPRTF` の上書きは、演習の指示どおり片付けてください。`TOKUIM`・`JUCHUM` は読み取り専用のアクセスしかしていないので、`TXRESET` は不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Command Processing Program (CPP) | コマンド処理プログラム(`CHGCMD`で差し替え可能) |
| Program-entry Procedure Interface | プログラム本体の手続きインターフェース(固定形式`*ENTRY PLIST`の自由形式版) |
| Overflow Indicator (`OFLIND`) | オーバーフロー標識(改ページの検知) |
| Space Before (`SPACEB`) / Skip Before (`SKIPB`) | 印字前に空白行を入れる/指定行まで飛ぶ |
| `OPTIONS(*NOPASS)` | 省略可能なパラメーター |

次のレッスン(06-13)では、埋め込みSQL(1)を扱います。

## 実機メモ

- 確認日: 2026-09-27。`part06-12-prtf-cpp-swap` の接続(`<USER>2`、3回のうち成功した3回目)で、`P0612A`(`CRTPRTF`、ジョブ・ログに`File P0612A created`)・`F0612A`(`CRTBNDRPG`、ジョブ・ログに`RNS9304: ... 00 highest severity`)とも正しく作成されたことを、接続の生ログ(`run`セクション)で確認しました。同じ接続の中で、`JUCINQC`(03-09)・`JUCINQ` コマンド(03-11、CPP=`JUCINQC`)を先に作り直し、`JUCINQ TOKCD('C00001')` を QCMDEXC 経由で実行したところ、`J00001 20260901`/`J00003 20260905` という2行が(`JUCINQC` 自身の出力として)正しく印字されました。続けて `F0612A` を直接 `CALL` したところ、

  ```text
  JUCINQ4 - ORDER INQUIRY REPORT        CUSTOMER: C00001
  ACME TRADING CO                 J00001  20260901
  ACME TRADING CO                 J00003  20260905
      2   ORDER(S) FOR THIS CUSTOMER
  ```

  という帳票が正しく印字され(04-08の `R0408A` と同じ2件)、さらに同じ接続内で `CHGCMD CMD(<USER>2/JUCINQ) PGM(<USER>2/F0612A)` を実行し、もう一度 `JUCINQ TOKCD('C00001')` を QCMDEXC 経由で呼んだところ、**まったく同一の帳票がもう一度正しく印字されました。** これは**V2**(実行し、接続の生ログの`run`セクションのテキストで直接確認)です。**コマンド自身(`JUCINQ`)のインターフェースは、03-11で作られたまま一度も変更していません**——`CHGCMD` は `PGM()` だけを差し替え、パラメーター定義は変わらないという一次資料の記述どおりの結果になりました。対話的な `F4` プロンプト自体は、このハーネス(非対話SSH)では確認できないため、引き続き**V3**です。
- **`JUCINQ`/`JUCINQC` 自体の実行(CPP=`JUCINQC`のベースライン)は、`part06-12-prtf-cpp-swap` の3回の接続すべてで(`F0612A`のコンパイルが失敗した1・2回目でも)成功しています。** つまり `F0612A` 経由の帳票は「このコマンドで初めて印字された出力」ではなく、同じ3回目の接続の中でも `JUCINQC` 経由の出力の方が先に印字されています。**この接続が実機で確かめたのは、「同じコマンド・同じパラメーターが、CPPを差し替えた前後でどちらも正しく動く」という03-11の予告そのものです。**
- `*IN01` は実際にオーバーフローで発火します(`RPTTOT` の `RPTCNT` が発火した行数を示すことで確認できます。下の項目を参照)。
- `CPYSPLF FILE(P0612A)` は、このハーネスの非対話ジョブでは `CPF3303`(ファイルが見つからない)で失敗します——これはこの教材の非対話ジョブに共通の既知の制約で(`QSYSPRT` でも同様に確認済み)、印字内容はすべて接続結果の`run`セクションのテキストから直接読んで確認しています。学習者自身が対話的に `WRKSPLF` を使う分には、この制約は当てはまりません。**見出し・明細の空白行(`SPACEB`)や改ページ(`SKIPB`)が実際に何行分の空白として現れるか、フィールドが実際に何桁目から始まっているかまでは、この`run`セクションのテキストからは確認できていません**(内容の行そのものと `EDTCDE` による表示形式は確認できています)。
- **`EDTCDE(3)` のゼロ残高表示は、`F0612A` 自身の実行で確認済みです(`part06-b7-bundle`、2026-09-28、`<USER>2`、**V2**)。** 存在しない得意先コード(`'C99999'`)で `CALL` したところ、`0   ORDER(S) FOR THIS CUSTOMER` と印字され(`RPTCNT` が0件でも空白にならず `0` を表示)、`NOTFOUND` という文字列は(上の「説明」で述べた理由どおり)どこにも印字されませんでした。
- `oflind` の宣言の形は、複数の接続にまたがって1つずつ絞り込まれています。まず `part06-12-prtf-cpp-swap`(2026-09-27)の接続で `dcl-ind ovf;`(存在しないキーワード、`RNF5347`/`RNF7030`)→`dcl-s ovf ind;`+`oflind(ovf)`(`RNF2037`、「Overflow Indicator is already defined」)という2つの失敗を実機の診断メッセージで確認し、続けて `part06-decisions-1`(2026-09-27)の接続で `oflind(*inoa)`(`RNF2014`、外部記述PRTF限定の失敗)→`oflind(*in01)`(コンパイル成功)という順にたどり着きました。この段階ではコンパイル成功のみの確認(**V1**)で、実際の印字・オーバーフロー発火の確認は次の項目のとおり別の接続で行っています。
- **`OFLIND(*IN01)` によるオーバーフロー検知と、見出しの再印字は、いずれも実機で確認済みです(`part06-b7-bundle`、2026-09-28、**V2**)。** `P0612A` のレコード様式を再利用した使い捨てのRPGプログラム(演習2と同じ形)を、`OVRPRTF FILE(P0612A) PAGESIZE(12 132) OVRFLW(10)` のもとで実行し、20行分の `RPTDTL` を `WRITE` したところ、見出しが3回印字されました(1回目はループ開始前の `WRITE`、2回目・3回目が実際のオーバーフローによる再印字で、9行目・18行目のあたりで `*IN01` が実際に ON になったことがわかります)。これより前の接続(`part06-b6-batch`、2026-09-27)でも、30行のループと `RPTCNT` だけを使う簡易な形で、9行目でオーバーフローが発火したこと自体はすでに確認できていました(`RPTTOT` が `9   ORDER(S) FOR THIS CUSTOMER` を印字)。
- **`F0612B`・`F0612C` は、`part06-b7-bundle`(2026-09-28)で**V1**(コンパイルのみ)確認済みです。** `CRTBNDRPG` はどちらも Highest Severity 00 で、`D0604A`・`D0611A`(06-04・06-11の既存DDS、変更なし)も同じ接続で存在を確認しています。`WORKSTN`/`EXFMT` を含む対話実行そのものは、04-11以来のこの教材の既知の制約により、このハーネス(非対話SSH)では確認できません。したがって、`F0612B` が `custCode` を受け取って `TOKCD` へ事前に埋め込むこと、`F0612C` のオプション5が実際に `F0612B` を正しい得意先コードで呼び出すことは、いずれも**V3**(学習者自身の5250セッションでの確認が必要)であり、実機では未確認のままです。
- 依存するプローブ `P17`(印刷系・`OVRPRTF SPLFNAME`・`CPYSPLF`・`CMPPFM` 関連)は、`docs/probes.md` の「未実施のプローブ」節が示すとおり、2026-09-28時点でまだ実施していません。このレッスンが実際に使う `OVRPRTF`(`PAGESIZE`/`OVRFLW` パラメーター)自体は、上記の使い捨てプローブで実際に使用・確認済みですが、P17 が主眼とする `SPLFNAME`・`CPYSPLF`・`CMPPFM`(スプール・ファイルの実際の捕捉・比較)は、このハーネスでは `CPF3303` で常に失敗するため、引き続き未検証のままです。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
