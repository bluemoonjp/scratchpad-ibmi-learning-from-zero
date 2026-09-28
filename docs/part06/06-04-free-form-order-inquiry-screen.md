# 06-04 `**FREE` に書き直す: 受注照会の画面版

> 所要時間: 90分(長め)/ 前提レッスン: 06-03 / 目標番号: 5 / 観測方法: 画面そのもの / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行、画面確認)/ 同時接続数: 5250×1(SSHでのソース取り込みは都度接続し直します。02-04・05-01と同じやり方です)/ 作る・変えるオブジェクト: `<USER>1/D0604A`(DSPF)、`<USER>1/F0604A`(RPG)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 04-11(`R0411A`)のDDS技法(`DSPSIZ`・ファンクション・キー・行/桁指定・同名フィールドでの自動表示)をそのまま流用し、注文一覧の行を追加した照会画面を書ける。
- `R0408A`(JUCINQ3、04-08)の`CHAIN`+`READ`ロジックを、`GOTO`/`TAG`を使わず`dow`/`if`+`%found`/`%eof`で`**FREE`に移植できる。愛称は`JUCINQ4D`(通し例7)です。
- 対話プログラムでは、帳票プログラムと違って同じファイルを何度も読み直す必要がある理由(`CLOSE`/`OPEN`での巻き戻し)を説明できる。

## ウォームアップ

<details><summary>前回の復習(06-03)</summary>

1. `**FREE`で`dcl-s`を書くタイミングは、RPG IIIのC仕様書の書き方と比べて、いつに変わりましたか?
2. `select`/`when`で`other`を省略できる場面でも、この教材ではどうする約束でしたか?

答え: 1. 変数を**使う前に**、あらかじめ宣言しておく(RPG IIIは結果フィールドの初出行で型・長さが決まりましたが、`**FREE`では逆に事前宣言が必須です)。 2. 省略せず、必ず`other`を書きます。

</details>

## なぜ学ぶか

**この画面は、ゼロから発明したものではありません。** 04-11で、得意先照会の画面(`R0411A`)を手書きしました。あのときのDDSの型(`DSPSIZ(24 80 *DS3)`・レコード様式単位の`CF03(03)`・38桁目の使用法・39〜44桁目の行/桁・同じ名前のフィールドで`CHAIN`結果が自動表示される、という技法)は、今回もそのまま使えます。今回**新しく設計する**のは、「得意先1件につき最大4件の注文を並べて表示する」という一覧部分だけです。つまりこの画面は、04-11の技法を土台にした**拡張**であり、`R0408A`(04-08、JUCINQ3の帳票版)の`CHAIN`+`READ`ロジックを、その拡張先に移植したものです(なお、`JUCINQ3`自体には元々RPG III時代の画面版が存在したわけではありません——今回が受注照会業務の**最初の画面**です)。

`R0408A`は「1回`CALL`すれば1回印刷して終わり」の帳票プログラムでした。今回は対話画面なので、`Enter`を押すたびに別の得意先コードを何度でも試せます。ここで初めて、「同じファイルをもう一度、最初から読み直す」という、帳票プログラムには無かった要求が出てきます。

## 新出

- 中核概念:
  1. RPG III時代の結果標識(`CHAIN`の54〜55桁目・`READ`の直後の標識)が、名前付きBIF `%found`/`%eof` に置き換わること。
  2. `GOTO`/`TAG`を一切使わず、`dow`/`if`だけで同じ制御フロー(「見つかるまで/終端まで繰り返す」)を書けること。
  3. 対話プログラムは、帳票プログラムと違って`EXFMT`ループの中で同じファイルを何度も読み直す必要があり、`READ`が一度`%eof`に達すると`CLOSE`/`OPEN`で読み込み位置を先頭に巻き戻す必要があること。
- 構文:
  - `dcl-f ... workstn`(WORKSTNファイルの自由形式宣言。`usage`省略時の既定値)
  - `%found`
  - `%eof`
  - `exfmt`(自由形式での書き方)
  - `close`/`open`(上の中核概念(3)を実現する実装手段。新しいBIFではなく既存のRPG IVオペコードです)

## 説明

### `R0408A`のロジックを`F0604A`へ移植する

`R0408A`(04-08)は、得意先コードを固定のリテラルで用意し、`TOKUIM`から`CHAIN`で名前を引き、`JUCHUM`を先頭から`READ`で舐めて一致する注文だけを印刷していました。対応をまとめると次のとおりです。

| `R0408A`(RPG III、04-08) | `F0604A`(`**FREE`、本レッスン) |
|---|---|
| `MOVEL'C00001' CUST 6`(検索キーは固定リテラル) | 画面の`TOKCD`入力欄が検索キー(毎回入力し直せる) |
| `CUST CHAINTOKUIM 99` / `99 MOVEL'NOTFOUND'TOKNM` | `chain tokcd tokuim;` / `if not %found(tokuim); toknm = 'NOTFOUND'; endif;` |
| `LOOP TAG` / `READ JUCHUM 98` / `98 GOTO ENDLP` | `dow not %eof(juchum)` という条件そのもの(`GOTO`/`TAG`が丸ごと不要になる) |
| `JUTOK IFEQ CUST` / `EXCPT`(帳票へ1行印字) / `ENDIF` | `if jutok = tokcd;`(画面の`ORDNOn`/`ORDDTn`欄へ格納)`endif;` |
| `GOTO LOOP` / `ENDLP TAG` | `read juchum;` を`dow`の末尾に置く / `enddo;` |

**大事な忠実さのポイント:** `R0408A`の`JUCHUM`走査は、`TOKUIM`の`CHAIN`が失敗しても**無条件に実行されます**(`JUTOK IFEQ CUST`の前に「`TOKUIM`が見つかったら」という条件は挟まっていません)。`F0604A`もこれをそのまま踏襲し、`JUCHUM`のスキャンを`if %found(tokuim)`で囲みません。存在しない得意先コードを入れても、スキャン自体は実行され、単に一致する注文が0件見つかる、という形で正しく`NOTFOUND`相当になります(演習で実際に確認します)。

**サブファイルは使いません。** 一覧といっても、`EXFMT`ループの中で`JUCHUM`を1件ずつ`READ`しながら得意先コードを突き合わせ、一致するたびに`ORDNO1`〜`ORDNO4`のどれかへ直接代入する、という素朴な方式です。件数を数える画面部品(サブファイル)は06-11で初めて扱います。

### DDS(`D0604A`)は`R0411A`の拡張

`src/qddssrc/d0604s.dspf` の全体です。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     A                                      DSPSIZ(24 80 *DS3)
     A          R JUCFMT
     A                                      CF03(03)
     A                                  1  2'Customer code:'
     A            TOKCD          6A  I  1 17
     A                                  3  2'Name:'
     A            TOKNM         30A  O  3  8
     A                                  5  2'Orders:'
     A                                  6  2'Order no'
     A                                  6 13'Order date'
     A            ORDNO1         6A  O  7  2
     A            ORDDT1         8S 0O  7 13
     A            ORDNO2         6A  O  8  2
     A            ORDDT2         8S 0O  8 13
     A            ORDNO3         6A  O  9  2
     A            ORDDT3         8S 0O  9 13
     A            ORDNO4         6A  O 10  2
     A            ORDDT4         8S 0O 10 13
     A                                 12  2'F3=Exit'
```

1〜7行目(`DSPSIZ`・レコード様式・`CF03`・`Customer code:`欄・`TOKCD`・`Name:`欄・`TOKNM`)は、`R0411A`の`INQFMT`とほぼ同じ内容です。変えたのはレコード様式名(`INQFMT`→`JUCFMT`)だけです。`R0411A`で5行目にあった`F3=Exit`は、この画面では**12行目に移動**しました(5〜10行目に注文一覧を新規追加したため、詰まらないよう下にずらしています)。新規に追加したのは5〜10行目(`Orders:`見出し・`Order no`/`Order date`の列見出し・`ORDNO1`〜`4`/`ORDDT1`〜`4`の4行)だけです。

`ORDNO1`〜`4`/`ORDDT1`〜`4`は、`JUCHUM`の`JUNO`/`JUDATE`という名前を**そのまま使っていません**。`TOKCD`/`TOKNM`のような「同じ名前を使うと`CHAIN`結果が自動表示される」技法は、1つの変数につき1回分しか効かないためです(`JUNO`という名前は1つしか無く、4行分の値を同時に持たせられません)。そのため画面専用の別名フィールドを4組用意し、RPG側で明示的に代入しています。`ORDDT1`〜`4`は`JUCHUM.JUDATE`と同じ型・長さ(`8S 0`)にしてあり、編集コードは付けていないので、日付は`20260901`のように8桁の数字がそのまま並びます。**編集コードを付けていないため、値が`0`のときも空白にはならず、`00000000`という8桁のゼロがそのまま表示されるはずです**(`ORDNO1`〜`4`は`6A`のフィールドで、RPG側で`*blanks`を代入しているため、こちらは正しく空欄になります)。

**画面は最大4件までしか表示できません。** `db/data/load_v1.sql`のサンプルでは、どの得意先も注文は最大2件(`C00001`→`J00001`/`J00003`、`C00003`→`J00004`/`J00008`)なので、4行という余裕は現状のデータでは問題になりません。ただし5件目以降の注文がある得意先を扱うと、そのぶんは**黙って表示されません**(後述のRPG側`select`の`other`が空のままなのはこのためです)。この制約は覚えておいてください。

### `dcl-f d0604a workstn;` ── WORKSTNファイルの既定の使用法

04-11では、固定形式のF仕様書で15桁目`C`(組み合わせ)・16桁目`F`(完全手続き型)を明示する必要がありました(空欄だと`QRG2096`)。`**FREE`では、`workstn`キーワード自体に「入力も出力もする完全手続き型」という意味が既定で含まれています。一次資料(ILE RPG言語リファレンス)のDCL-Fの説明によれば、`usage`キーワードを省略した`WORKSTN`ファイルは`USAGE(*INPUT:*OUTPUT)`が既定値になります。桁位置で書き分けていたものが、キーワード1個(あるいは省略)に集約された形です。

### `%found`/`%eof` ── 結果標識の名前付きBIF化

04-08の`R0408A`では、`CHAIN`の結果標識(見つからないとき54〜55桁目の標識がON)と、`READ`の結果標識(終端でONになる標識)を、それぞれ番号で扱っていました。`**FREE`ではこれが名前付きのBIFになります。

```rpgle
chain tokcd tokuim;
if not %found(tokuim);
  toknm = 'NOTFOUND';
endif;
```

```rpgle
read juchum;
dow not %eof(juchum);
  ...
  read juchum;
enddo;
```

**極性に注意してください。** `%found`は「見つかった」ときに真になります(RPG IIIの標識は逆で、「見つからなかった」ときにONでした)。`%eof`を**オン**にできるのは`READ`系(`READ`/`READC`/`READE`/`READP`/`READPE`、およびサブファイルへの`WRITE`)だけです。`CHAIN`・`OPEN`・`SETGT`・`SETLL`は、成功した場合に`%eof`を**オフ**にリセットします(一次資料・ILE RPG言語リファレンスの`%EOF`の説明による)。つまり`CHAIN`も`%eof`に触れないわけではなく、成功時にオフへ戻す側の操作です。`CHAIN`の「見つかった/見つからない」は`%found`が担当し、`%eof`とは役割が別なので、この2つを混同しないようにしてください。

### なぜ`CLOSE`/`OPEN`で巻き戻す必要があるのか

`R0408A`は1回の`CALL`で`JUCHUM`を1回だけ、先頭から終端まで読みます。`F0604A`は`EXFMT`ループの中で、得意先コードを入力するたびに同じ`JUCHUM`スキャンを何度も繰り返します。**しかし`READ`は一度終端(`%eof`)まで達すると、そのままでは二度と行を返しません。** そこで、毎回のスキャンの直前に`close juchum; open juchum;`を書き、読み込み位置を先頭に巻き戻しています。

```rpgle
close juchum;
open juchum;

ordCount = 0;
read juchum;
dow not %eof(juchum);
  ...
```

一次資料(ILE RPG言語リファレンス)のCLOSE/OPENの説明によれば、こうして手動で`CLOSE`したファイルは`USROPN`キーワードなしでそのまま`OPEN`し直せます。これは新しいBIFではなく、既存のRPG IVオペコードの組み合わせですが、**「対話プログラムは同じファイルを繰り返し読む」という、帳票プログラムには無かった要求から初めて必要になる**ものなので、このレッスンで明示的に扱います。

## 実演

**この実演で作る2つのオブジェクト(`D0604A`・`F0604A`)は、著者による実機コンパイル(V1、下の「実機メモ」参照)まで確認済みです。対話的な実行(`EXFMT`で実際に画面が出て、キー入力を受け付けるところ)は、この教材の検証ハーネス(非対話SSH)では確認できません。学習者自身の5250セッションで確認してください。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込む(1回の接続でまとめて行います)。`QDDSSRC`は02-05の`TXSETUP`で、`QRPGLESRC`は06-01b/06-03までのどこかで、すでに作成済みのはずです。まだ無ければ`CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')`でファイル自体を作成してから進めてください(すでにある場合は`CPF5813`が出るだけなので気にせず進めてください。メンバーを追加するコマンドは`ADDPFM`ですが、`RCDLEN`はファイルを作成する`CRTSRCPF`/`CRTPF`側のパラメーターで、`ADDPFM`自体には`RCDLEN`はありません)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qddssrc/d0604s.dspf') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QDDSSRC.FILE/D0604A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0604s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0604A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、コンパイルする。

   ```text
   CRTDSPF FILE(<自分のユーザー名>1/D0604A) SRCFILE(<自分のユーザー名>1/QDDSSRC) SRCMBR(D0604A)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0604A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0604A)
   ```

   どちらも Highest Severity 00 になることを確認してください(著者の環境ではどちらも一度目のコンパイルで通っています)。実際にRPG本体で自由形式のロジックを書く部分は次のとおりです(`src/qrpglesrc/f0604s.rpgle`と同じ内容です。ヘッダーの説明コメントは省略しています)。

   ```rpgle
   dcl-f d0604a workstn;
   dcl-f tokuim keyed;
   dcl-f juchum;

   dcl-s ordCount packed(3:0);

   dow not *in03;
     exfmt jucfmt;

     if not *in03;
       ordno1 = *blanks;
       orddt1 = 0;
       ordno2 = *blanks;
       orddt2 = 0;
       ordno3 = *blanks;
       orddt3 = 0;
       ordno4 = *blanks;
       orddt4 = 0;

       chain tokcd tokuim;
       if not %found(tokuim);
         toknm = 'NOTFOUND';
       endif;

       close juchum;
       open juchum;

       ordCount = 0;
       read juchum;
       dow not %eof(juchum);
         if jutok = tokcd;
           ordCount = ordCount + 1;
           select;
             when ordCount = 1;
               ordno1 = juno;
               orddt1 = judate;
             when ordCount = 2;
               ordno2 = juno;
               orddt2 = judate;
             when ordCount = 3;
               ordno3 = juno;
               orddt3 = judate;
             when ordCount = 4;
               ordno4 = juno;
               orddt4 = judate;
             other;
               // 5件目以降は画面に表示しない(上の「説明」参照)。
           endsl;
         endif;
         read juchum;
       enddo;
     endif;
   enddo;

   *inlr = *on;
   return;
   ```

4. `CALL PGM(<自分のユーザー名>1/F0604A)`を実行する。画面が出たら、`C00001`を入力して`Enter`を押し、`TOKNM`に`ACME TRADING CO`、注文一覧に`J00001`/`20260901`と`J00003`/`20260905`の2行が表示されることを確認してください(`R0408A`が04-08で印刷したのと同じ2件です)。`F3`で終了できることも確認してください。

## 演習

1. `C99999`(存在しない得意先コード)を入力してください。`TOKNM`が`NOTFOUND`になり、注文一覧の`ORDNO`列(得意先番号)は4行とも空欄になることを確認してください。ただし`ORDDT`列(注文日)は編集コードを付けていないため、空欄ではなく`00000000`という8桁のゼロがそのまま表示される**はずです**(上の「説明」参照)。`JUCHUM`のスキャンは`TOKUIM`の`CHAIN`が失敗しても無条件に実行されるため、`NOTFOUND`と「一致する注文0件」が両方同時に起きます。
2. 同じ`CALL`の中で、`C00001`を試した(`Enter`を押して結果を確認した)あと、`F3`を押さずに続けて`C00003`を入力して`Enter`を押してください。`TOKNM`が`BLUE OCEAN INC`に変わり、注文一覧が`J00004`/`J00008`に**入れ替わる**(前の`C00001`の行が残らない)ことを確認してください。もし`close juchum; open juchum;`の2行を取り除いたらどうなるか、実行する前に予想してから試してください(2件目以降の得意先は、`JUCHUM`が既に終端に達しているため、注文が1件も見つからなくなるはずです)。
3. (発展)06-01の3世代対応表(`R0408A`・変換直後の`V0601A`・自由形式版)の「自由形式」欄がまだ空欄なら、`F0604A`のロジック部分(画面まわりを除いた`CHAIN`+`READ`部分)を書き込んで埋めてください。

## セルフチェック

- [ ] `D0604A`が`R0411A`の拡張であり、ゼロから設計したものではないことを説明できる(共通する行・新規に追加した行を挙げられる)。
- [ ] `R0408A`の`CHAIN`+`READ`+`GOTO`/`TAG`ロジックと、`F0604A`の`chain`+`%found`+`dow`+`%eof`の対応を、自分の言葉で説明できる。
- [ ] `%found`(見つかったとき真)と`%eof`(終端に達したとき真、`READ`系がセット)の違いと極性を説明できる。
- [ ] なぜこの画面だけ`CLOSE`/`OPEN`で`JUCHUM`を巻き戻す必要があるのか(`R0408A`には無かった理由)を説明できる。
- [ ] `C00001`で2件、`C99999`で`NOTFOUND`+0件、をそれぞれ確認できた。

## 片付け

`D0604A`・`F0604A`はそのまま残してください。06-10(同じ画面を`INDDS`で書き直す比較対象)・06-11(一覧画面のオプション5から`F0604A`を呼び出す)が、このオブジェクトをそのまま使います。`TOKUIM`・`JUCHUM`は読み取り専用のアクセスしかしていないので、データが書き換わることはなく、`TXRESET`も不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Return Found Condition (`%FOUND`) | 見つかったかどうかを返す組み込み関数 |
| Return End of File Condition (`%EOF`) | ファイル終端かどうかを返す組み込み関数(`READ`系がセットする) |
| Reposition / rewind | ファイルの読み込み位置を先頭に戻す(`CLOSE`+`OPEN`) |
| Row cap | 画面の表示行数の上限(この画面では4件) |

次のレッスン(06-05)では、サブプロシージャとプロトタイプを扱い、`R0402A`の税込み計算を`dcl-proc`で書き直し、`R0409A`(ZAHIK3)を呼び出します。

## 実機メモ

- 確認日: 2026-09-26。`part06-screens-compile`という接続(第6部の画面/サブファイル系レッスン4本分をまとめて検証する接続)の中で、`D0604A`(`CRTDSPF`)・`F0604A`(`CRTBNDRPG`)は、**2回の接続とも1回目からHighest Severity 00でコンパイルに成功したことを、接続の生ログ(run section)で確認しました**(ジョブ・ログに`CRTDSPF`・`CRTBNDRPG`とも「00 highest severity」という完了メッセージが出ていたことを確認しています。具体的なメッセージIDまではログから追跡できていません)。同じ接続の中で他の2画面(`F0611A`・`F0611BA`、06-11・06-11b用)は1回目の接続では無関係な別の実バグで失敗し2回目で解決していますが、これは`D0604A`/`F0604A`自体には影響していません。これは**V1(コンパイル確認)**です。
- **`EXFMT`/`WORKSTN`を含む対話実行そのものは、このハーネス(非対話SSH)では確認できません**(04-11で確立済みの既知の制約と同じで、`CALL`すると実デバイスを待ってハングします)。したがって、`C00001`で`ACME TRADING CO`+`J00001`/`J00003`の2行が表示されること、`C99999`で`NOTFOUND`+0件になること、`CLOSE`/`OPEN`による巻き戻しが2件目以降の得意先でも正しく効くこと——これらはすべて**V3**(学習者自身の5250セッションでの確認が必要)であり、実機では未確認のままです。次の実機接続の機会に、実際の5250クライアントから試すことを推奨します。
- `F0604A`はパラメーターを一切取らない形(`dcl-f d0604a workstn;`のみで`*ENTRY PLIST`相当の宣言なし)のままです。一覧画面(06-11の`JUCLST4`)のオプション5からこの画面を呼ぶ際に得意先コードを渡す改善は、`F0604A`自身を書き換えるのではなく新しい別オブジェクト(`F0612B`・`F0612C`、06-12で扱います)として追加されており、`CRTBNDRPG`とも`Highest Severity 00`でCONFIRMED SUCCESSです。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
