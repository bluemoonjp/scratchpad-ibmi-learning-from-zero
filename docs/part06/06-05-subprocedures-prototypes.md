# 06-05 サブプロシージャとプロトタイプ

> 所要時間: 75分(長め)/ 前提レッスン: 06-04 / 目標番号: 5 / 観測方法: `DSPJOBLOG`・`DSPDTAARA(*LDA)` / 道具: 5250、SSH / 同時接続数: 5250×1(SSHでのソース取り込みは都度接続し直します。02-04・05-01と同じやり方です)/ 作る・変えるオブジェクト: `<USER>1/F0605A`・`<USER>1/F0605B` / DBVER: 1 / 依存するプローブ: P38, P42 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 手続き(サブプロシージャー)を`dcl-proc`/`dcl-pi`で定義し、`value`/`const`でパラメーターを安全に受け渡せる。
- `dcl-pr extpgm`で、既存のRPG IIIプログラム(`R0409A`、ZAHIK3)をそのまま呼び出せる。
- `QCMDEXC`を`**FREE`から呼べる。

## ウォームアップ

<details><summary>前回の復習(06-04)</summary>

1. `%found`と`%eof`は、それぞれ何が起きたときにON(真)になりますか。極性(見つかった側/見つからなかった側のどちらでtrueか)に注意して答えてください。
2. 対話プログラム(`F0604A`)が`CLOSE`/`OPEN`で`JUCHUM`を巻き戻す必要があったのはなぜですか。帳票プログラム(`R0408A`)には無かった理由は何でしたか。

答え: 1. `%found`は`CHAIN`等が**見つかった**ときに真になります(RPG IIIの結果標識は逆に「見つからなかった」ときONだったので、極性が反転しています)。`%eof`は`READ`が**終端**に達したときに真になるBIFで、オンにできるのは`READ`系(`READ`/`READC`/`READE`/`READP`/`READPE`)とサブファイルへの`WRITE`だけです。`CHAIN`・`OPEN`・`SETGT`・`SETLL`は成功時に`%eof`をむしろOFFへリセットする側です。 2. `READ`は一度`%eof`に達すると、そのままでは二度と行を返しません。`F0604A`は`EXFMT`ループの中で、得意先コードを入力するたびに同じ`JUCHUM`スキャンを何度も繰り返す必要があるため、毎回`close juchum; open juchum;`で読み込み位置を先頭に巻き戻していました。`R0408A`は1回の`CALL`で1回だけ先頭から終端まで読んで終わるプログラムだったため、この問題自体が起きませんでした。

</details>

## なぜ学ぶか

**04-05で見た`EXSR`/`BEGSR`/`ENDSR`のサブルーチンは、呼び出し元の変数をそのまま共有します。** 04-09で`R0409A`(ZAHIK3)を作ったときも、`PROD`・`QTY`はプログラム内の直接のフィールドで、外から差し替える手段がありませんでした。**サブプロシージャー(`dcl-proc`)は、この「呼び出し元と丸ごと共有」という前提を崩します。** `value`で渡した引数は呼び出し先の**コピー**になり、`const`で渡した引数は呼び出し先から**書き換えられない**ことが保証されます。どちらもRPG IIIの`EXSR`にも、RPG III時代の`CALL`+`PARM`にも無かった安全性です。

このレッスンでは、04-02で書いた`R0402A`の税込み計算(`1580 × 1.10 = 1738.00`)を`dcl-proc`の1手続きに移し替え、さらに04-09の`R0409A`(ZAHIK3)を`dcl-pr extpgm`で直接呼び出します。**RPG III時代に作った資産を、RPG IVの新しい部品(手続き・プロトタイプ)からそのまま再利用できる**ことを、実際に手を動かして確認します。あわせて、05-04で読んだ`QCMDEXC`(RPGからCLコマンドを呼ぶ技法)を、`**FREE`の呼び出し方で扱います。

## 新出

- 中核概念:
  1. `ctl-opt dftactgrp(*no) actgrp(*new);`が必要になること。既定の活動化グループ(`DFTACTGRP(*YES)`)では、呼び出し操作は常に「プロシージャーではなくプログラムを呼ぶもの」として扱われるため、サブプロシージャーを含むプログラムを作れません。(活動化グループはILEの実行境界の話であり、RPGサイクル(`*INLR`による暗黙ループ)とは別概念です。`F0605A`自身も`*inlr = *on; return;`というサイクルを使った書き方のままです。)
  2. `dcl-proc`/`dcl-pi`は**サブプロシージャーの**インターフェース宣言です。06-12で扱う「プログラム本体のdcl-pi(固定形式の`*ENTRY PLIST`に代わるもの)」とは、同じ`DCL-PI`というキーワードを使う**別の使い方**である、とここで先に釘を刺しておきます。本体は06-12で扱います。
  3. `value`/`const`によるパラメーター受け渡しの安全性。RPG IIIの`EXSR`(サブルーチン)も`CALL`+`PARM`(プログラム間呼び出し)も、呼び出し元の実フィールドをそのまま共有するのが前提でした。
- 構文:
  - `dcl-proc`/`dcl-pi`(サブプロシージャー用)
  - `value`/`const`
  - `dftactgrp(*no)`
  - `dcl-pr extpgm`(他プログラム呼び出し用のプロトタイプ)
  - `*nopass`/`%parms`
  - `QCMDEXC`の`**FREE`呼び出し(`dcl-pr ... extpgm('QCMDEXC')`+`packed(15:5)`の長さパラメーター)

## 説明

### `ctl-opt dftactgrp(*no) actgrp(*new);` ── サブプロシージャーを含むための前提

```rpgle
ctl-opt dftactgrp(*no) actgrp(*new);
```

`F0605A`のソースは、この1行が無いとコンパイルできません。一次資料(ILE RPG言語リファレンスの`DFTACTGRP`キーワードの説明)によれば、**既定の活動化グループ(`DFTACTGRP(*YES)`)では、呼び出し操作は「プロシージャーではなくプログラムを呼ぶもの」として扱われます。** `calcTaxTotal`のような同一プログラム内の手続きへの呼び出しは、`R0409A`のような別プログラムへの呼び出しとは違う経路(バウンド呼び出し)を通るため、この明示が必要になります。 `dcl-proc`でサブプロシージャー(`calcTaxTotal`・`sendMsg`)を定義する`F0605A`は、`dftactgrp(*no)`を明示する必要があります。`F0605B`自身は`dcl-proc`を持たないため、この理由での必須ではありませんが、同じ行をそのまま書いています。

### `dcl-proc`/`dcl-pi` ── サブプロシージャーのインターフェース

`R0402A`(04-02、`1580 × 1.10 = 1738.00`、実機確認済み)の税込み計算を、`calcTaxTotal`という1つの手続きに移します(`src/qrpglesrc/f0605s.rpgle`と同じ内容です)。

```rpgle
dcl-proc calcTaxTotal;
  dcl-pi *n packed(9:2);
    amount packed(7:2) value;
    rate   packed(3:2) const options(*nopass);
  end-pi;

  dcl-s appliedRate packed(3:2) inz(1.10);  // R0402A の RATE(Z-ADD1.10)

  if %parms >= 2;
    appliedRate = rate;
  endif;

  return amount * appliedRate;
end-proc;
```

呼び出し側はこうなります。

```rpgle
taxTotal1 = calcTaxTotal(1580);
taxTotal2 = calcTaxTotal(1580 : 1.08);
```

- `amount`は`value`です。**手続きは呼び出し元の変数のコピーを受け取ります。** RPG IIIの`EXSR`(サブルーチン)は、こういう区別自体がありませんでした——呼び出し元の実フィールドをそのまま操作するのが前提だったので、うっかり書き換えてしまう事故が起こり得ました。
- `rate`は`const`+`options(*nopass)`です。`const`は「読み取り専用」、`*nopass`は「渡さなくてもよい」という意味で、この2つは別の性質です。1つ目の呼び出し(`calcTaxTotal(1580)`)は`rate`を渡していないので、手続き側は既定値`1.10`(`R0402A`の`RATE`と同じ)を使います。2つ目の呼び出しは`1.08`を明示的に渡しています。
- `%parms`は「この呼び出しで実際に渡された引数の数」を返します。RPG IIIの`EXSR`(サブルーチン)には、そもそもパラメーターという概念自体が無いため、相当する仕組みがありません。プログラム呼び出し(`CALL`+`PARM`)については、RPG III自身もプログラム状態データ構造(PSDS)の`*PARMS`サブフィールドで「呼び出し元から渡されたパラメーターの数」を実行時に取得できました(一次資料: RPG/400リファレンスのPSDSサブフィールド一覧)。ただし`%parms`のようにその場でBIFを呼ぶだけでは済まず、PSDS自体を明示的に宣言しておく必要がある点は、`%parms`より一手間かかります。

`dcl-pi *n`の`*n`は、**サブプロシージャー自身の名前(`calcTaxTotal`)を書く代わりに使う無名の書き方**です。この`dcl-pi`はあくまで`calcTaxTotal`という1つの手続きのインターフェースであり、06-12で扱う「プログラム本体のdcl-pi(固定形式の`*ENTRY PLIST`に代わるもの)」とは別物です。

### `dcl-pr extpgm` ── 既存のRPG IIIプログラムをそのまま呼ぶ

`R0409A`(04-09、ZAHIK3=在庫引当)を、プロトタイプ経由で呼び出します。

```rpgle
dcl-pr r0409a extpgm('R0409A') end-pr;
```

```rpgle
callp r0409a();
```

**`R0409A`自身のソース(04-09)には、`*ENTRY PLIST`が一切ありません。** `PROD`(`'P00001'`)も`QTY`(`Z-ADD2`)も、プログラムの中に埋め込まれた固定のリテラルです。つまり、このプロトタイプが引数を1つも取らないのは省略ではなく、**`R0409A`側に合わせるパラメーターがそもそも存在しない**ためです。`callp`は`**FREE`では省略でき(`r0409a();`と直接式文にしても同じ意味です)、ここでは呼び出しであることを分かりやすくするために明示的に書いています。

`dcl-pr extpgm`が呼べるのはRPGプログラムに限りません。呼び出し先が`*PGM`オブジェクトでありさえすれば、言語を問わず(CLプログラムを含めて)同じ形で書けます。このレッスンでは呼び出し対象をRPG III(`R0409A`)とシステム提供プログラム`QCMDEXC`に絞っており、学習者自身が書いたCLプログラムを`dcl-pr extpgm`で呼ぶ実演は扱いません。

**注意(片付けに関わります)**: `callp r0409a();`を実行すると、`ZAIKOM`の`P00001`が本当に45→43に減ります。04-09・06-08の演習と同じ理由で、このレッスンの実演のあとは必ず`<自分のユーザー名>1/TXRESET`を実行してください。

### ジョブ・ログへの観察: `sendMsg`(前方参照)

`F0605A`は、計算結果を画面にもプリンターにも出さず、`sendMsg`という手続きでジョブ・ログへ書き込みます。

```rpgle
sendMsg('F0605A: 1580 at default rate = ' + %trim(%char(taxTotal1)));
```

`sendMsg`の内部は`QMHSNDPM`(メッセージ送信API)を直接呼んでいますが、その`qualified`なデータ構造・`likeds`の意味は06-07で、`QMHSNDPM`自体の詳しい扱いは06-09で説明します。ここでは「`sendMsg`に文字列を渡すと、ジョブ・ログに残る」とだけ知っておいてください。

**なぜ`DSPLY`ではないのか**: 一次資料(ILE RPG言語リファレンス)によれば、`DSPLY`にメッセージ・キューを指定しない場合、**バッチ・ジョブでは**既定の送り先が`QSYSOPR`になります。02-04以降のSSH経由の非対話実行(この教材の検証ハーネスが使う経路)はバッチ扱いになるため、`DSPLY`をそのまま使うと`QSYSOPR`に無言でメッセージが届いてしまい、style-guide.mdの「PUB400での作法」(`QSYSOPR`や他ユーザーへの`SNDMSG`を避ける)に反しかねません。`sendMsg`(ジョブ・ログへの書き込み)は、対話的な5250の`CALL`でも、非対話のSSH実行でも同じように動作するため、`F0605A`はこちらだけを観察経路として使っています。

### `QCMDEXC`を`**FREE`から呼ぶ(`F0605B`)

05-04で`ZA0510`(RPG III)が`QCMDEXC`経由で`CHGDTAARA`を呼ぶ技法を読みました。同じ考え方を、`**FREE`の呼び出し方に移したのが`F0605B`(`src/qrpglesrc/f0605bs.rpgle`)です。`F0605A`とは別の、この課専用の小さなオブジェクトです。

```rpgle
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd char(200) const;
  cmdLen packed(15:5) const;
end-pr;

dcl-s cmd char(200);
dcl-s cmdLen packed(15:5);

cmd = 'CHGDTAARA DTAARA(*LDA (21 20)) VALUE(''F0605B OK'')';
cmdLen = %len(%trimr(cmd));

qcmdexc(cmd : cmdLen);
```

`QCMDEXC`は05-04のRPG III版と同じ、ふつうのシステム・プログラムです。プロトタイプ(`dcl-pr ... extpgm('QCMDEXC')`)で宣言し、(1)実行したいコマンド文字列、(2)そのうち意味のある長さを表す**15桁5小数のパック10進数**、という同じ2つのパラメーターを渡します。05-04のRPG III版が`MOVEL`でコマンド文字列を1断片ずつ組み立てていたのに対し、`**FREE`では単に文字列リテラルを代入するだけで済みます。

**なぜ`SNDPGMMSG`ではなく`CHGDTAARA`なのか**: `SNDPGMMSG`は、`QCMDEXC`経由では実行できません(`CPD0031`「Command SNDPGMMSG not allowed in this setting」)。IBMの`SNDPGMMSG`自身の解説ページは、実行可能な環境を「Compiled CL program or interpreted REXX」だけに限っており、`QCMDEXC`自体の解説ページも「CLプログラム・プロシージャーの中でしか使えないコマンドは、QCMDEXCプログラムからは実行できない」と明記しています。この2箇所のIBM公式ドキュメントの記述によれば、この制約は呼び出し元の言語や呼び出しの深さに関わらず起きるはずですが、実機で実際に確認できているのは、RPGの主モジュールからバウンド呼び出しで呼ばれた`sendMsg`手続き(NOMAINモジュール側で定義)が、内部で`QCMDEXC`経由の`SNDPGMMSG`を実行しようとした、という1パターンだけです(`part07-01-modules`、詳細は下の「実機メモ」参照)。CLからの呼び出しや、より深い呼び出し階層は、まだ実機で試していません。**05-04の`ZA0510`が`CHGDTAARA`を使うのも同じ理由です**(経緯の詳細は下の「実機メモ」参照)。`CHGDTAARA`はIBMの解説ページの「Where allowed to run」欄が`*ALL`(すべての環境)なので、`QCMDEXC`から安全に呼べます。

`F0605B`が使う`*LDA`のバイト範囲(21〜40バイト目)は、05-04の`ZA0510`が使う範囲(1〜20バイト目)とはあえてずらしてあります。同じジョブの中で両方のレッスンの実演を続けて試しても、互いの`*LDA`の値を上書きし合いません。実行後は`DSPDTAARA DTAARA(*LDA)`で、21バイト目から`F0605B OK`という文字列が実際に書き込まれていることを確認できます——`QCMDEXC`が本当にコマンドを実行し終えた、目に見える証拠です。

## 実演

**`F0605B`は実機でコンパイル・実行を確認済みです(`part06-b8-compile`、2026-09-28、下の「実機メモ」参照)。**

1. SSHで接続し、`~/ibmi-kyozai`が最新であることを確認します(`git pull`)。`exit`で5250に戻ります。
2. 5250のコマンド行で、`<自分のユーザー名>1/QRPGLESRC`にメンバーを2つ用意します(`QRPGLESRC`自体は06-01b以降で作成済みのはずです。まだ無ければ`CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')`を先に実行してください)。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0605A) SRCTYPE(RPGLE) TEXT('Subprocedures and prototypes')
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0605B) SRCTYPE(RPGLE) TEXT('QCMDEXC from **FREE')
   ```

3. SSHでもう一度接続し、2本のソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0605s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0605A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0605bs.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0605B.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

4. 5250に戻り、両方をコンパイルします。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0605A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0605A)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0605B) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0605B)
   ```

   どちらも Highest Severity 00 になることを確認してください。

5. `F0605A`を実行し、ジョブ・ログを確認します。

   ```text
   CALL PGM(<自分のユーザー名>1/F0605A)
   DSPJOBLOG
   ```

   次の3行(メッセージID`CPF9898`)が記録されているはずです。

   ```text
   F0605A: 1580 at default rate = 1738.00.
   F0605A: 1580 at rate 1.08 = 1706.40.
   F0605A: R0409A (ZAHIK3) called via CALLP..
   ```

   (3行目の末尾がピリオド2つなのは誤植ではありません。ソース内の文字列自体が`'...CALLP.'`とピリオドで終わっており、そこに`CPF9898`メッセージ自身の定型の終端ピリオドがもう1つ付くためです。1・2行目は数値で終わるため、ピリオドは1つだけになります。)

   (`DSPJOBLOG`の最初の画面にこの3行がそのまま見えない場合は、`F10`で詳細メッセージ表示に切り替えてください。)

   `WRKSPLF`でスプール・ファイルも確認してください。`R0409A`自身が印字した`P00001  0000043  OK`(45−2=43)が1件出ているはずです。

6. `F0605B`を実行し、`*LDA`を確認します。

   ```text
   CALL PGM(<自分のユーザー名>1/F0605B)
   DSPDTAARA DTAARA(*LDA)
   ```

   21バイト目から`F0605B OK`という文字列が書き込まれていることを確認してください。

7. **後片付け**: 手順5で`ZAIKOM`の`P00001`が45→43に変わっています。`<自分のユーザー名>1/TXRESET`を実行し、在庫を元に戻してください。

## 演習

`calcTaxTotal`の`rate`パラメーターから`options(*nopass)`を外し、全パラメーター必須の形にしてみてください。

```rpgle
rate packed(3:2) const;
```

この状態で再コンパイルし、1つの引数だけで呼び出している行(`calcTaxTotal(1580)`)がどうなるか確認してください。**このレッスンでは、この変更が実際に何というメッセージID・診断を出すかを確認済みの実機データとしては持っていません。** 一次資料(ILE RPG言語リファレンス)の`OPTIONS(*NOPASS)`の説明によれば、`*NOPASS`を指定した引数は「渡さなくてもよい」引数として扱われ、それより後ろの引数もすべて`*NOPASS`である必要があります。裏を返せば、`*NOPASS`を外した引数は常に渡す必要がある、ということです。実際にどんな診断が出るかは、**自分で再コンパイルして、コンパイル・リストに現れる実際のメッセージを読んで確認してください。**(見つけたメッセージIDは、ぜひ[Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues)で教えてください。)

## セルフチェック

- [ ] `ctl-opt dftactgrp(*no) actgrp(*new);`がサブプロシージャーを含むプログラムに必要な理由を説明できる。
- [ ] `dcl-proc`/`dcl-pi`でサブプロシージャーを定義し、`value`/`const`/`*nopass`/`%parms`を使い分けられた。
- [ ] サブプロシージャーの`dcl-pi`と、06-12で扱う「プログラム本体のdcl-pi」が別の使い方であることを知っている。
- [ ] `dcl-pr extpgm`で、パラメーターを持たない既存のRPG IIIプログラム(`R0409A`)を正しく呼び出せた。
- [ ] `QCMDEXC`を`**FREE`のプロトタイプ呼び出しで実行できた(`F0605B`)。
- [ ] `SNDPGMMSG`が`QCMDEXC`経由では実行できない理由(`CPD0031`)を説明できる。
- [ ] 実演(手順5で`F0605A`を実行した後)、`TXRESET`で在庫を元に戻した。

## 片付け

`F0605A`・`F0605B`はそのまま残してください。**手順5で`ZAIKOM`の`P00001`を実際に45→43へ変えているので、`<自分のユーザー名>1/TXRESET`を必ず実行してください。** `*LDA`(手順6で書き込んだ値)はジョブ終了時にクリアされるので、明示的に戻す必要はありません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Activation group | 活動化グループ |
| Subprocedure | サブプロシージャー |
| Prototype | プロトタイプ |
| Bound call (vs. program call) | バウンド呼び出し(プログラム呼び出しとの対比) |
| Pass by value | 値渡し |
| Pass by const reference | 定数(書き換え不可)参照渡し |
| Optional parameter (`*NOPASS`) | 省略可能パラメーター |

次のレッスン(06-06)では、文字列と日付を扱う組み込み関数(BIF)を、実際に手を動かして確認します。

## 実機メモ

- **`F0605A`はV2まで確認済みです**(確認日 2026-09-27、`part06-0509-procs-files`、CONFIRMED SUCCESS、1回の接続)。著者の検証ライブラリーで`CRTBNDRPG`によりHighest Severity 00でコンパイルし、`CALL`で実行した結果、ジョブ・ログに次の3行が`CPF9898`として記録されることを確認しました:「`F0605A: 1580 at default rate = 1738.00.`」「`F0605A: 1580 at rate 1.08 = 1706.40.`」「`F0605A: R0409A (ZAHIK3) called via CALLP..`」(3行目末尾のピリオド2つは、ソース文字列自身の終端ピリオドに`CPF9898`の定型終端ピリオドが重なったもので、誤植ではありません)。同じ実行で`R0409A`自身の印字(`P00001  0000043  OK`)も確認されています。**この検証ハーネス(非対話SSH)は印刷装置ファイルの実スプール・ファイルを作らないため、`CPYSPLF`は`CPF3303`で失敗します(`WRKSPLF`はこのハーネスでは一度も実行していません)。上記はいずれもスプール・ファイルではなく、接続の生ログ(runセクション)を直接読んで確認したものです。** 実際の5250セッションで`WRKSPLF`を使って`R0409A`の印字を確認する部分(上の「実演」手順5)は、この教材の検証ハーネスとは別の、対話操作(V3)です。
- **`F0605B`は実機コンパイル・実行を確認済みです(`part06-b8-compile`、確認日2026-09-28、CONFIRMED SUCCESS)。** `CRTBNDRPG`はHighest Severity 00、`CALL`も成功し、直後の`DSPDTAARA DTAARA(*LDA)`出力(接続のrunセクションのテキストで確認——このハーネスの非対話SSHジョブでは印字出力が実際のスプール・ファイルにならないため、`WRKSPLF`ではなくこの方法で確認しています)で、21バイト目から`F0605B OK`という文字列が設計どおり正確に書き込まれていることを確認しました。使っている技法(`QCMDEXC`+`CHGDTAARA(*LDA)`、`ALLOW(*ALL)`)自体は、RPG III版として`part05-qcmdexc-runtime`(確認日2026-09-27、CONFIRMED SUCCESS、`src/legacy/qrpgsrc/za0510.rpg`、`*LDA`の1〜20バイト目)でも別途実機確認済みです。
- **`ctl-opt dftactgrp(*no) actgrp(*new);`が無いとコンパイルできない、という中核概念は、実機のエラー・メッセージそのもので裏付けられています**: `part06-gen-probe`(確認日2026-09-26、5回の接続の1回目)で、`dcl-proc`を含む13本のファイル全てにこの行が欠落しており、`RNF1520`「The procedure cannot be defined with DFTACTGRP(*YES).」が実際に出ました。この発見は`F0605A`とは別の検証セット(機能梯子`T0LAD01`〜`T0LAD12`)によるものですが、同じサブプロシージャーの仕組みに関する一般規則であり、`F0605A`・`F0605B`のどちらも最初からこの行を含む形で書かれています。(これは実機で確認したコンパイル時エラーそのものであり、スタイル・ガイドの`V1`——コンパイルが通り重大度が許容範囲であることの確認——とは性質が異なるため、ここでは`V1`表記を使いません。)
- **`SNDPGMMSG`が`QCMDEXC`経由では実行できないという事実(`CPD0031`)は、`part07-01-modules`の接続で実際に観測されました**(2回目の接続、確認日2026-09-26。このときの`sendMsg`はまだ`QCMDEXC`+`SNDPGMMSG`版で、`RUNF0701A FAILED`という結果に終わっています)。実機で確認できたパターンは、RPGの主モジュール(`M0701A`)からバウンド呼び出しで呼ばれた`sendMsg`手続き(NOMAINモジュール`M0701B`で定義)が、内部で`QCMDEXC`経由の`SNDPGMMSG`を実行しようとした、という1つだけです。IBM公式のドキュメント2箇所(`QCMDEXC`自体の解説・`SNDPGMMSG`自体の解説)を突き合わせると、この制約は呼び出し元の言語(RPG/CL)や呼び出しの深さに関わらず起きるはずですが、CLからの呼び出しやより深い呼び出し階層は、まだどの接続でも実機確認していません**(未検証、2026-09-28時点)**。(この`CPD0031`自体は実機で確認したコンパイル後の実行時エラーであり、上の`RNF1520`の注記と同じ理由で`V`表記は使いません。)`sendMsg`をその後`QMHSNDPM`直接呼び出しに書き換えたところ、続く3回目の接続で`part07-01-modules`全体がCONFIRMED SUCCESSまで到達しています。このレッスンの`F0605A`が`sendMsg`(`QMHSNDPM`直接呼び出し)を使い、`QCMDEXC`のデモを`F0605B`という別オブジェクトに分けて`CHGDTAARA`を選んでいるのは、この実機の発見が理由です。**05-04の`ZA0510`が`CHGDTAARA`に差し替えられているのも、この`part07-01-modules`の発見を受けたもので、`ZA0510`自身がSNDPGMMSG版で実際にこの壁に当たったわけではありません**(`ZA0510`のSNDPGMMSG版はコンパイル(V1、`part05-legacy-probe`)のみ確認済みで、実機で実行した記録はありません)。
- **依存するプローブ(`P38`・`P42`)は、`docs/probes.md`の「未実施のプローブ」一覧のとおり、どちらも正式にはまだ未実施です。** `P38`(メッセージIDの系統的な一括採取)は、[付録B](../appendix/b-message-ids.md)自身が明記するとおりこの教材全体でまだ一度も実施されていません(`CPF9898`という個別のメッセージID自体は付録Bに実例として既に記録されていますが、それはP38という網羅的な採取プローブとは別物です)。`P42`(`QCMDEXC`の3つの呼び出し経路)は、RPG IIIの`CALL`+`PARM`(長さ15,5)経由の経路が`part05-qcmdexc-runtime`で、このレッスンの`F0605B`が使う`**FREE`のプロトタイプ経由の経路が`part06-b8-compile`で、それぞれ実機確認済みです。SQLの`CALL QSYS2.QCMDEXC`経由の経路だけは、まだどの接続でも確認されていません。
- 演習の`*nopass`除去が実際に何という診断を出すかは、まだどの接続でも確認していません(未検証、2026-09-28時点。上の「演習」参照)。一次資料の一般的な記述にとどめ、具体的なメッセージIDは推測で書いていません。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
