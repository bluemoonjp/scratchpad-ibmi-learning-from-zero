# 06-15 チェックポイント: 在庫照会をサブファイル+SQLで

> 所要時間: 120分(長め)/ 前提レッスン: 06-14b / 目標番号: 5 / 観測方法: 画面そのもの(`D0615A`/`F0615A`)・`WRKSPLF`(`Q0615A`)・ジョブ・ログ(`TXCHECK`)/ 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行、画面確認・`WRKSPLF`)、SQL(`TXCKM`登録)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/D0615A`(DSPF)・`<USER>1/F0615A`(RPG、サブファイル半分)・`<USER>1/Q0615A`(SQLRPGLE、SQL半分)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

第6部で学んだサブファイル(06-11)・埋め込みSQL(06-13・06-14・06-14b)を組み合わせて、**04-13(`R0413A`、商品別在庫一覧表)と同じ業務要件を、自分ひとりで最初から最後まで作り直せる**ことを確認します。**新しい文法は出てきません。**

- `ZAIKOM`(在庫マスター)と`SHOHIM`(商品マスター)を組み合わせた在庫一覧を、サブファイル(画面)版・SQL(帳票)版の**2通り**で作れる。
- 実装技法(ネイティブ`CHAIN`/配列+`%LOOKUP`/サブファイル/SQL `JOIN`)が違っても、同じ業務判定(在庫数量が発注点を下回っていたらLOWSTOCK)に到達することを確認できる。
- `TXCHECK`を実際の`*CMD`形で実行し、このチェックポイントのオブジェクトが揃っていることを機械的に確認できる。

## ウォームアップ

**まず確認してください(06-11bを実施した場合)**: [06-11b](06-11b-maintenance-screen-locking.md)(`SHOHIM`保守画面)を実施した場合、このチェックポイントに入る前に、06-11bの片付けで指示された`TXRESET`が実際に完了しているかどうかを確認してください。06-11bの演習は共有テーブル`SHOHIM`(商品マスター)の中身を直接書き換えます。**`TXRESET`をまだ実行していないと、下の採点表(`P00002`・`P00005`だけがLOWSTOCK)が実機と一致しません**——このチェックポイントのプログラム自体は何も悪くありません。念のため次の`SELECT`で初期値を確認してから進めてください。

```sql
SELECT SHOCD, SHONM, SHOHAT FROM <自分のユーザー名>1/SHOHIM ORDER BY SHOCD;
SELECT ZASHO, ZASU FROM <自分のユーザー名>1/ZAIKOM ORDER BY ZASHO;
```

商品名・発注点(`SHOHAT`)が`P00001`=DESK LAMP/20、`P00002`=OFFICE CHAIR/5、`P00003`=NOTEBOOK PACK/100、`P00004`=STAPLER/30、`P00005`=USB CABLE/50、`P00006`=MONITOR STAND/15と一致し、在庫数量(`ZASU`)が`45`・`3`・`250`・`60`・`12`・`22`(この順)と一致していれば準備完了です。1件でもずれていたら、`<自分のユーザー名>1/TXRESET`を実行してから進めてください(06-11bの片付け、および02-05で作成したツールです)。

<details><summary>前回の復習(06-14b)</summary>

1. `Q0614BA`のカーソルや`INSERT`が、素直な静的SQL(`PREPARE`を経由しない書き方)ではなく`PREPARE`+`EXECUTE IMMEDIATE`だったのはなぜですか?
2. 埋め込みSQLの`FETCH ... INTO :host :ind`で、列がNULLだったとき、RPGの`%nullind`は自動的に更新されますか?

答え: 1. 対象のテーブル(`QTEMP/W0614BA`)が、プログラム自身の実行中に`CREATE TABLE`で初めて作られるものであり、静的SQLは`CRTSQLRPGI`のプリコンパイル時点でアクセス・プランを確定しようとするため(その時点ではまだテーブルが存在しない)、`SQL1103`(列定義が見つからないという警告)がプリコンパイル時に出るからです(06-14b自身の実機検証では、この警告だけで実行時に必ず壊れるとまでは確認できておらず、確認できている確実な失敗はリテラル書式の誤りによる`SQL0180`/`SQL9001`という別のプリコンパイル時エラーでした)。動的SQLはSQL文の中身をプリコンパイラーに直接見せないため、プリコンパイル時点ではこうした警告・エラーが出る余地自体を無くせます。 2. されません。SQL側のNULL標識ホスト変数(`:ind`)とRPGの`%nullind`は別の仕組みで、橋渡しを自分で書く必要があります。

</details>

## なぜ学ぶか

**このチェックポイントに、新しい文法は一切出てきません。** 04-13で`R0413A`(ネイティブ`CHAIN`+RPGサイクル)を、06-07で`F0607A`(配列+`%LOOKUP`)を使って、同じ業務判定(在庫数量`ZASU`が発注点`SHOHAT`を下回っていたらLOWSTOCK)を2度作ってきました。ここでは同じ判定を、**06-11のサブファイル**(対話画面としての一覧)と、**06-13・06-14の埋め込みSQL**(`JOIN`によるSQL版レポート)という、第6部で学んだ2つの技法で、もう2通り作り直します。

実装技法が4つに増えても、業務側の答え(`P00002`=OFFICE CHAIR・`P00005`=USB CABLEの2件だけがLOWSTOCK)は変わりません。**この「同じ業務結果に、複数の技法で到達できる」こと自体が、第6部の総合演習としてのこのチェックポイントの狙いです。**

## 新出

内容: 新出なし。04-13・05-13と同じ「チェックポイント」の位置づけで、ここまでのレッスンの技法を組み合わせるだけです。

読解に必要な既出の技法だけ挙げておきます。

- サブファイル半分: `dcl-f ... workstn sfile(recfmt:rrnfield)`・load-all(06-11)、`chain`+`%found`(06-04)。
- SQL半分: `CRTSQLRPGI`・`SET OPTION`・`SQLCODE`/`SQLSTATE`(06-13)、カーソル宣言・`FETCH`ループ(06-14)、`JOIN ... ON`(02-06)。

## 説明

### 課題: 04-13を、サブファイル+SQLで作り直す

`ZAIKOM`(在庫マスター)と`SHOHIM`(商品マスター)を組み合わせ、商品ごとの在庫一覧を用意してください。在庫数量(`ZASU`)が発注点(`SHOHAT`)を下回っている商品にはLOWSTOCKの印を付けてください。

- **サブファイル半分**: 06-11のload-all技法(全件`READ`→`WRITE SFL1`)で一覧画面を作る。行選択(`OPT`)や追加・変更・削除は要りません(読み取り専用の一覧です)。
- **SQL半分**: 06-13・06-14のカーソル+`FETCH`ループで、`ZAIKOM`と`SHOHIM`を`JOIN`した結果を印字するバッチ・レポートを作る(`ZAIKOM`のキーは`ZASHO`、`SHOHIM`のキーは`SHOCD`——名前は違いますが同じ商品コードです)。LOWSTOCKの判定そのものは、SQLの`SELECT`の中ではなく、`FETCH`したあとの普通のRPGの`if`で行ってください(`CASE`式はこの教材ではまだ扱っていません)。

自分で書いてみてから、以下で答え合わせをしてください。

### サブファイル半分(`D0615A`/`F0615A`): 06-11のload-allそのまま、`OPT`無し

`solutions/06-15/d0615s.dspf`(抜粋)です。

```text
     A                                      DSPSIZ(24 80 *DS3)
     A          R SFL1                      SFL
     A            ZASHO          6A  O  4  2
     A            SHONM         30A  O  4 10
     A            ZASU           7S 0O  4 42
     A            SHOHAT         5S 0O  4 52
     A            STATUS         8A  O  4 60
     A          R SFL1CTL                   SFLCTL(SFL1)
     A                                      SFLSIZ(9999)
     A                                      SFLPAG(14)
     A                                      SFLDSP
     A                                      SFLDSPCTL
     A                                      ROLLUP(25)
     A                                      ROLLDOWN(26)
     A                                      CF03(03)
     A                                      OVERLAY
     A                                  1  2'D0615A - Stock inquiry'
     A                                  3  2'Code'
     A                                  3 10'Name'
     A                                  3 42'Qty'
     A                                  3 52'Reord'
     A                                  3 60'Status'
     A          R SFL1FTR
     A            MORE          10A  O 20  2
     A                                 23  2'F3=Exit  Roll=Page'
```

06-11の`D0611A`と同じ形です。`SFL1`(サブファイル本体、`ZASHO`・`SHONM`・`ZASU`・`SHOHAT`・`STATUS`の5フィールド)と`SFL1CTL`(制御レコード)の組で、`SFLSIZ(9999)`/`SFLPAG(14)`は06-11のload-all版と同じ値です。`SELECT`欄(`OPT`)は無く、**選ぶ・変える機能を持たない、純粋な一覧**です。条件付け標識(7〜16桁目)は一切使っておらず、`SFLDSP`/`SFLDSPCTL`は常時オンです(06-11・06-11bと同じ方針)。`ZAIKOM`は6件を切ることが無いサンプル・データなので、「0件のときにプレースホルダーを出す」という06-11の分岐は、このプログラムには要りません。フッター(`MORE`・`F3=Exit`)は、06-11・06-11bと同じ理由(`CPD7812`、`SFLCTL`は自分のサブファイルの上または下どちらか片方にしか位置指定付きの出力を持てない)で`SFL1FTR`という別レコード様式に分けています。

`solutions/06-15/f0615s.rpgle`のロジック部分です。

```rpgle
dcl-f d0615a workstn sfile(sfl1:rrn1);
dcl-f zaikom disk keyed usage(*input);
dcl-f shohim disk keyed usage(*input);

dcl-s rrn1 packed(4:0) inz(0);

read zaikom;
dow not %eof(zaikom);
  rrn1 += 1;

  chain zasho shohim;
  if not %found(shohim);
    shonm = 'UNKNOWN PRODUCT';
    shohat = 0;
  endif;

  if zasu < shohat;
    status = 'LOWSTOCK';
  else;
    status = *blanks;
  endif;

  write sfl1;
  read zaikom;
enddo;

more = 'BOTTOM';

dow not *in03;
  write sfl1ftr;
  exfmt sfl1ctl;
enddo;
```

`ZAIKOM`を先頭から終端まで`READ`し、1件ごとに商品コード(`ZASHO`)で`SHOHIM`を`chain`します。**`ZASHO`と`SHOCD`はフィールド名が違うので、`TOKCD`/`TOKNM`のような同名の自動代入は効きません。** その代わり、`SHOHIM`側の`SHONM`/`SHOHAT`は`SFL1`の同名フィールドへ`write`時に自動代入され(`R0413A`の`ZASHO CHAINSHOHIM`と同じ、キー名は違うが結果は自動転記、という組み合わせです)、`ZASHO`/`ZASU`は`ZAIKOM`から同様に自動代入されます。`STATUS`だけは画面専用のフィールド(`ZAIKOM`にも`SHOHIM`にも無い)なので、`R0413A`のO仕様書条件付き出力(`60 70'LOWSTOCK'`)に相当する判定を、普通の`if`で明示的に代入しています。`chain`が失敗した場合(`SHOHIM`に無い商品コード)への備え(`UNKNOWN PRODUCT`)は、現在のサンプル・データでは発火しません(`ZAIKOM`の6件全てが`SHOHIM`と一致するため、04-13・06-07で確認済みのとおりです)が、念のため用意されています。load-allなので、読み込みは`EXFMT`より前に全件終わっており、`MORE`は常に`'BOTTOM'`です。

### SQL半分(`Q0615A`): 04-13の`CHAIN`を`JOIN`に置き換える

`solutions/06-15/q0615s.sqlrpgle`の中心部分です。

```rpgle
exec sql SET OPTION commit = *none, naming = *sys;

exec sql DECLARE C1 CURSOR FOR
  SELECT Z.ZASHO, S.SHONM, Z.ZASU, S.SHOHAT
    FROM ZAIKOM Z
    JOIN SHOHIM S ON Z.ZASHO = S.SHOCD
    ORDER BY Z.ZASHO;

exec sql OPEN C1;

if SQLCODE < 0;
  prtText = 'OPEN C1 failed, SQLCODE=' + %char(SQLCODE);
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;

exec sql
  FETCH C1 INTO :wZasho, :wShonm, :wZasu, :wShohat;

dow SQLSTATE = '00000';
  if wZasu < wShohat;
    wStatus = 'LOWSTOCK';
  else;
    wStatus = *blanks;
  endif;

  // (印字組み立ては下記の「ゼロ埋め」コードのとおり。ここでは省略)

  exec sql
    FETCH C1 INTO :wZasho, :wShonm, :wZasu, :wShohat;
enddo;

exec sql CLOSE C1;
```

**`JOIN ... ON`は02-06で既出です。** `R0413A`の`ZASHO CHAINSHOHIM`(フィールド名が違うキー同士のCHAIN)を、SQL側では`JOIN SHOHIM S ON Z.ZASHO = S.SHOCD`という結合条件で表しています。テーブル別名(`Z`・`S`)も02-06で既に使った書き方です。**このJOINは(既定どおり)内部結合(INNER JOIN)です**——`ZAIKOM`に`SHOHIM`側で一致する行が無い場合、その行は結果に現れません。今のサンプル・データでは`ZAIKOM`の6件全てが`SHOHIM`と一致するため、この違いは実際には発火しませんが、サブファイル半分(`chain`が失敗しても`UNKNOWN PRODUCT`として一覧に残す)とは意図的に異なる挙動です。

**LOWSTOCKの判定は、`SELECT`文の中(`CASE WHEN`など)ではなく、`FETCH`したあとの普通のRPGの`if`(`if wZasu < wShohat;`)で行っています。** `CASE`式はこの教材ではまだ扱っていないため、意図的に使っていません。`SQLSTATE`/`SQLCODE`の使い分けも06-13・06-14bと同じ約束です——カーソルの`FETCH`ループは`SQLSTATE = '00000'`(成功)を継続条件にし、`OPEN`直後は`SQLSTATE = '00000'`ではなく`SQLCODE < 0`(本当のエラーだけ)を見ています。

印字の組み立ては、`EDTCDE`ではなく、06-06以来のBIF(`%SUBST`・`%CHAR`)によるゼロ埋めです。

```rpgle
numTxt = %char(wZasu);
if %len(numTxt) < 7;
  padded = %subst('0000000' : 1 : 7 - %len(numTxt)) + numTxt;
else;
  padded = numTxt;
endif;
%subst(prtText:49:7) = padded;
```

`R0413A`のO仕様書(`ZASHO`は8桁目で終わる、`SHONM`は42桁目で終わる、`ZASU`は55桁目で終わる無編集7桁、`LOWSTOCK`は70桁目で終わる8桁)と桁位置を揃えてあります(`%subst(prtText:3:6)`=`ZASHO`、`:13:30`=`SHONM`、`:49:7`=ゼロ埋め済みの`ZASU`、`:63:8`=`STATUS`)。

## 実演

**`D0615A`・`F0615A`は著者による実機コンパイル(V1)まで、`Q0615A`は著者による実機コンパイル・実行(V2、下の「実機メモ」参照)まで確認済みです。`F0615A`は`D0615A`に対して`EXFMT`を行う対話プログラムのため、この教材の検証ハーネス(非対話SSH)ではコンパイルより先(対話的な実行、`EXFMT`で実際に画面が出るところ)は確認できません(V3)。学習者自身の5250セッションで確認してください。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. メンバーがまだ無ければ、5250で用意します(`QDDSSRC`・`QRPGLESRC`自体は02-05・06-01bまでに作成済みのはずです)。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QDDSSRC) MBR(D0615A) SRCTYPE(DSPF) TEXT('06-15 checkpoint: stock inquiry subfile')
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0615A) SRCTYPE(RPGLE) TEXT('06-15 checkpoint: stock inquiry subfile')
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(Q0615A) SRCTYPE(SQLRPGLE) TEXT('06-15 checkpoint: stock inquiry SQL')
   ```

3. SSHでソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/06-15/d0615s.dspf') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QDDSSRC.FILE/D0615A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/06-15/f0615s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0615A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/solutions/06-15/q0615s.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/Q0615A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

4. 5250に戻り、コンパイルする。

   ```text
   CRTDSPF FILE(<自分のユーザー名>1/D0615A) SRCFILE(<自分のユーザー名>1/QDDSSRC) SRCMBR(D0615A)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0615A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0615A)
   CRTSQLRPGI OBJ(<自分のユーザー名>1/Q0615A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(Q0615A) OBJTYPE(*PGM) COMMIT(*NONE)
   ```

   3つともHighest Severity 00になることを確認してください。

5. `CALL PGM(<自分のユーザー名>1/Q0615A)`を実行し、`WRKSPLF`で次の6行が印字されることを確認してください(下の「実機メモ」に、著者の環境で確認できた内容をそのまま載せています)。

   ```text
   P00001    DESK LAMP                           0000045
   P00002    OFFICE CHAIR                        0000003       LOWSTOCK
   P00003    NOTEBOOK PACK                       0000250
   P00004    STAPLER                             0000060
   P00005    USB CABLE                           0000012       LOWSTOCK
   P00006    MONITOR STAND                       0000022
   ```

6. `CALL PGM(<自分のユーザー名>1/F0615A)`を実行し、一覧に6商品全てが表示され、`P00002`・`P00005`の`STATUS`欄にだけ`LOWSTOCK`が出ることを確認してください。`F3`で終了できることも確認してください。

7. `TXCKM`(05-13で作成済みのはずです)に、このレッスンの3行を登録します。二重登録を避けるため、まず同じ`LESSON`の行を消してから入れ直します。

   ```sql
   DELETE FROM <自分のユーザー名>1/TXCKM WHERE LESSON = '06-15';

   INSERT INTO <自分のユーザー名>1/TXCKM
     (LESSON, SEQNBR, OBJNAME, OBJTYPE, OBJATTR, CKDESC)
   VALUES
     ('06-15', 1, 'D0615A', '*FILE', ' ', 'D0615A display file exists'),
     ('06-15', 2, 'F0615A', '*PGM',  ' ', 'F0615A subfile checkpoint exists'),
     ('06-15', 3, 'Q0615A', '*PGM',  ' ', 'Q0615A SQL checkpoint exists');
   ```

8. `TXCHECK`を、05-13で導入された`*CMD`形(`CALL PGM(...) PARM(...)`ではない書き方)で実行します。

   ```text
   TXCHECK LESSON('06-15') LIB(<自分のユーザー名>1)
   ```

   ジョブ・ログに`TXCHECK PASS: ...`が3件と、`TXCHECK: lesson 06-15 - ... passed, ... failed.`という要約(下の「実機メモ」参照)が出れば、3つのオブジェクトが揃っていることが機械的に確認できたことになります。

## 演習

1. `db/data/load_v1.sql`(またはウォームアップの`SELECT`)で、`SHOHIM`の商品コード列が`SHOCD`という名前であることを確認し、`Q0615A`の結合条件(`Z.ZASHO = S.SHOCD`)が、フィールド名の違うキー同士を結び付けるものであることを、`R0413A`の`ZASHO CHAINSHOHIM`と対応づけて説明してください。
2. `Q0615A`の`ORDER BY Z.ZASHO`を`ORDER BY S.SHONM`に変えて再コンパイル・実行し、印字順が商品コード順から商品名順に変わることを確認してください(確認後は元に戻してください)。
3. (発展)`Q0615A`のJOINは内部結合(INNER JOIN)です。もし`ZAIKOM`に、`SHOHIM`に存在しない商品コードの行が混ざっていたら、`Q0615A`の印字はどうなるか(その行だけ現れない)、`F0615A`の`UNKNOWN PRODUCT`の扱いとどう違うか、自分の言葉で説明してください(これは未検証の思考実験です。現在のサンプル・データでは発火しません)。

### 採点表

自分で採点してください。「✓」の数ではなく、理由を説明できるかを重視してください。

| 観点 | 基準 |
|---|---|
| サブファイル半分のコンパイル | `D0615A`・`F0615A`が実際にHighest Severity 00でコンパイルできた(V1) |
| SQL半分の実行結果 | `Q0615A`を実行し、6商品全てが印字され、`P00002`・`P00005`だけに`LOWSTOCK`が付くことを確認した(V2) |
| 業務判定の一致 | 04-13(`R0413A`)・06-07(`F0607A`)と同じ2商品が同じ理由(在庫数量が発注点を下回る)でLOWSTOCKになることを、自分の言葉で説明できる |
| サブファイル半分の対話確認 | `F0615A`を実際に5250で`CALL`し、6件の一覧と2件の`LOWSTOCK`を確認した(V3) |
| `TXCHECK` | `TXCHECK LESSON('06-15') LIB(...)`を実行し、3件ともPASSすることを確認した(V2) |

## セルフチェック

- [ ] 06-11bを実施していた場合、そのTXRESETが完了していることをウォームアップで確認してから始めた。
- [ ] `D0615A`/`F0615A`(サブファイル半分)を実際にコンパイルし、6商品の一覧を確認した。
- [ ] `Q0615A`(SQL半分)を実際にコンパイル・実行し、採点表(`P00002`・`P00005`だけLOWSTOCK)と一致することを確認した。
- [ ] `Q0615A`のJOIN条件が、`R0413A`のフィールド名の違うキー同士のCHAIN(`ZASHO`↔`SHOCD`)と対応することを説明できる。
- [ ] LOWSTOCKの判定が、SQLの`SELECT`ではなく`FETCH`後の`if`で行われている理由を説明できる。
- [ ] `TXCHECK`で3件ともPASSすることを確認した。

## 片付け

`D0615A`・`F0615A`・`Q0615A`はそのまま残してください。このチェックポイント自身は`ZAIKOM`・`SHOHIM`をどちらも読み取り専用でアクセスしているので、この実演・演習によってデータが書き換わることはなく、`TXRESET`は不要です(ウォームアップで触れた06-11bのTXRESETは、06-11b自身の片付けとして別途済ませておくべきものです)。

## まとめ

これで第6部は完了です。`**FREE`への書き換え、サブプロシージャー、データ構造と配列、サブファイル、印刷装置ファイルとコマンドのCPP差し替え、埋め込みSQL、DATE/TIMESTAMP/NULLまでを扱いました。次は第7部([07-01](../part07/07-01-ile-overview-modules.md)、ILEの全体像とモジュール)で、`*MODULE`/`*PGM`/`*SRVPGM`の違いと活動化グループを扱います。

| 英語 | 日本語 |
|---|---|
| Checkpoint | チェックポイント(新しい文法を教えず、既存の技法の組み合わせだけで確認する回) |
| Grading table | 採点表 |
| Inner join | 内部結合(既定のJOINの動作。両方のテーブルで一致する行だけを返す) |
| Cross-field-name join | フィールド名が異なるキー同士を結び付けるJOIN(`ZASHO`↔`SHOCD`) |
| Business parity | 業務判定の一致(実装技法が違っても同じ業務結果に到達すること) |

## 実機メモ

- 確認日: 2026-09-27(接続`part06-15-checkpoint`、2回接続)。**`D0615A`(`CRTDSPF`)・`F0615A`(`CRTBNDRPG`)・`Q0615A`(`CRTSQLRPGI`、`COMMIT(*NONE)`明示)は全てHighest Severity 00でコンパイルに成功した(V1)。**
- **`Q0615A`を`CALL`した実際の印字は、接続結果の`run`セクションの生テキストで確認した(V2)。** この検証ハーネスの非対話SSHジョブでは`QSYSPRT`が実スプール・ファイルを作らないため(06-13・06-14bと同じ既知の制約)、`CPYSPLF`/`WRKSPLF`ではなくこの方法で確認した。

  ```text
  P00001    DESK LAMP                           0000045
  P00002    OFFICE CHAIR                        0000003       LOWSTOCK
  P00003    NOTEBOOK PACK                       0000250
  P00004    STAPLER                             0000060
  P00005    USB CABLE                           0000012       LOWSTOCK
  P00006    MONITOR STAND                       0000022
  ```

  採点表(`P00002`・`P00005`だけがLOWSTOCK)と完全一致した。同じ接続内の`SELECT`で、この時点の`ZAIKOM`が初期値(`45`・`3`・`250`・`60`・`12`・`22`)のままだったことも確認している。
- **`TXCKM`への3行登録・`tools/qcmdsrc/txcheck.cmd`の`*CMD`ラッパー・`TXCHECK LESSON('06-15') LIB(...)`という実際の`*CMD`呼び出し形は、同じ接続で次のとおり確認できた(V2、ジョブ・ログに実際に現れた文言)。** このハーネスでは、コマンド文字列を実行時に組み立てて`QCMDEXC`へ渡す専用のCLヘルパー経由で`*CMD`を呼び出しており、学習者が5250のコマンド行に直接`TXCHECK LESSON(...) LIB(...)`と打ち込む経路そのものをたどったわけではありません(結果として現れるジョブ・ログの文言は同一です)。

  ```text
  TXCHECK PASS: D0615A display file exists
  TXCHECK PASS: F0615A subfile checkpoint exists
  TXCHECK PASS: Q0615A SQL checkpoint exists
  TXCHECK: lesson 06-15 - 0000000003 passed, 
  0000000000 failed.
  ```

  件数が10桁ゼロ埋め(`0000000003`)で表示されているのは、`TXCHECK`自身のCLソースが10進数の件数を10桁の文字型変数へ`CHGVAR`で変換しているためです。この挙動自体は正しく再現されています(ゼロ埋めのまま出すことが`TXCHECK`自身の意図だったのかどうかは、ソース中の`%TRIM`の扱いだけからは断定できません)。
- **`D0615A`/`F0615A`の対話実行(`EXFMT`で実際に画面が出て、6件の一覧・2件のLOWSTOCKが表示されるところ)は、このハーネス(非対話SSH)では確認できません**(04-11以来の既知の制約と同じです)。V3のまま、学習者自身の5250セッションでの確認が必要です。
- このハーネスの検証は、`solutions/06-15/`のソースを検証ライブラリーへ直接取り込む経路によるものであり、上の「実演」節が示す学習者自身の`ADDPFM`→`STMFCCSID(1208)`付き`CPYFRMSTMF`の手順そのものをたどったわけではありません(ソースの内容自体は同一です。06-07の実機メモが説明しているのと同じ事情です)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
