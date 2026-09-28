# 06-14 埋め込み SQL (2): カーソル・動的 SQL・コミットメント制御

> 所要時間: 75分(長め)/ 前提レッスン: 06-13 / 目標番号: 5 / 観測方法: `WRKSPLF` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(`CRTSQLRPGI`・`CALL`・`WRKSPLF`)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/Q0614A`(SQLRPGLE)/ DBVER: 1 / 依存するプローブ: P12(`TOKUIM`は未journaled、確認済み)・`part06-1314-sql`検証バッチ(`CRTSQLRPGI`のOBJ/SRCFILE/SRCMBR/OBJTYPE/COMMIT構文、Highest Severity 00で確認)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- カーソルを使って、条件に合う複数行を1行ずつ`FETCH`で取り出せる。
- `PREPARE`+`?`(パラメーター・マーカー)で、実行時に決まる検索条件を安全な動的SQLとして書ける。
- 「得意先1件の注文一覧」という同じ業務ロジックを、ネイティブI/O(`CHAIN`/`READ`、04-08・06-04)とSQL(本レッスンの`Q0614A`)のどちらでも書けることを説明できる。
- SQLインデックスとキー付き論理ファイルの違い、`Visual Explain`という道具の存在を知っている(読解用、手を動かす演習はありません)。

## ウォームアップ

<details><summary>前回の復習(06-13)</summary>

1. `CRTSQLRPGI`の`CLOSQLCSR`パラメーターを省略したときの既定値は何ですか?
2. `SQLSTATE`が`'00000'`のとき、何が起きたことを意味しますか?
3. `GET DIAGNOSTICS`は、何を調べるために使いますか?

答え: 1. `*ENDACTGRP`(活性化グループが終わるときに、カーソル・準備済みステートメント・`LOCK TABLE`ロックを閉じる/解放する) 2. 直前のSQL文がエラーなく正常に終わったこと 3. 直前のSQL文が失敗したときの、詳しいメッセージID・メッセージ文を取り出すため

</details>

## なぜ学ぶか

**まず大事な前提を確認しておきます。この`Q0614A`は、`JUCINQ`コマンドを差し替えるものではありません。** 06-12で`JUCINQ`コマンドのCPPは既に`F0612A`に差し替わっており、そのCPPの枠は既に埋まっています。ここで作る`Q0614A`は`JUCINQ`コマンドとは一切つながっていない、独立した比較用のデモ・プログラムです。「得意先照会という同じ業務ロジックを、ネイティブI/Oの代わりにSQLで書くとどうなるか」を確かめるためだけの、単体で`CALL`するプログラムです。

06-13では、1行だけを読む`SELECT INTO`と、1行だけを直す`UPDATE`を扱いました。しかし業務では「ある得意先の注文を全部」のように、**複数行**を扱いたい場面のほうが普通です。SQLで複数行を1行ずつ処理する唯一の方法が**カーソル**です。

また、`JUCINQ3`(04-08の`R0408A`)は検索キーが固定のリテラル(`'C00001'`)でした。実務のSQLでは、検索条件を実行時に受け取りたい場面がよくあります。値をそのままSQL文字列に連結すると、引用符の扱いを間違えて文が壊れたり、意図しない文字列が紛れ込んだりする危険があります。これを避けて**安全に**検索条件を差し込む仕組みが、`PREPARE`+`?`(パラメーター・マーカー)です。

## 新出

- 中核概念:
  1. カーソル+複数行`FETCH`(1行だけの`SELECT INTO`(06-13)と違い、条件に合う行を1行ずつ順番に取り出す)。
  2. `PREPARE`+`?`マーカーによる動的SQL(検索条件をSQL文字列に直接埋め込まず、実行時に安全に束縛する)。
  3. ネイティブI/O(`CHAIN`/`READ`)とSQLの使い分け(同じ業務ロジックを、どちらの技法でも書けること)。
- 構文:
  - カーソル宣言(`DECLARE ... CURSOR FOR`)・`OPEN ... USING`・`FETCH ... INTO`・`CLOSE`
  - `PREPARE`
  - `?`(パラメーター・マーカー)
- 読解用(新出には数えません): SQLインデックスとキー付き論理ファイルの違い、`Visual Explain`(ACSのGUIツール)の存在。

## 説明

### 復習: 静的`SELECT INTO`との対比

`src/qrpglesrc/q0614s.sqlrpgle`(`Q0614A`)の前半は、06-13と同じ**静的**な`SELECT INTO`です(得意先コードは1件だけなので、複数行を扱うカーソルは不要です)。

```rpgle
exec sql
  SELECT TOKNM INTO :wCustName
    FROM TOKUIM
    WHERE TOKCD = :wCustCode;

if SQLSTATE = '00000';
  prtText = 'Customer ' + %trim(wCustCode) + ': ' + %trim(wCustName);
else;
  wCustName = 'NOTFOUND';
  prtText = 'Customer ' + %trim(wCustCode) + ': ' + wCustName;
endif;
write qsysprt prtLine;
```

この部分は`06-13`で学んだ技法とまったく同じです。あえて静的なままにしてあるのは、このあとの**動的**SQL(注文一覧のほう)と見比べてもらうためです。

### カーソル+複数行`FETCH`

得意先の注文は0件・1件・複数件のどれもあり得ます。SQLで複数行を1行ずつ処理するには、**カーソル**を使います。

```rpgle
exec sql PREPARE S1 FROM :wStmt;
exec sql DECLARE C1 CURSOR FOR S1;
exec sql OPEN C1 USING :wCustCode;

exec sql FETCH C1 INTO :wOrderNo, :wOrderDt;
dow SQLSTATE = '00000';
  prtText = '  Order ' + wOrderNo + ' dated ' + %char(wOrderDt);
  write qsysprt prtLine;
  exec sql FETCH C1 INTO :wOrderNo, :wOrderDt;
enddo;

exec sql CLOSE C1;
```

一次資料によれば、カーソルは次の4段階で使います。

| 段階 | 文 | 役割 |
|---|---|---|
| 宣言 | `DECLARE C1 CURSOR FOR S1` | 「`S1`という準備済みステートメントの結果を、`C1`という名前のカーソルで読む」と決める(まだ何も実行しない) |
| 開く | `OPEN C1 USING :wCustCode` | 実際にSQL文を実行し、結果セットを用意する。パラメーター・マーカーがあれば、この時点でホスト変数を束縛する |
| 取り出す | `FETCH C1 INTO :wOrderNo, :wOrderDt` | 結果セットから1行だけ取り出し、ホスト変数に代入する。呼ぶたびに次の行へ進む |
| 閉じる | `CLOSE C1` | カーソルを閉じ、それ以上`FETCH`できないようにする |

一次資料によれば、これ以上取り出せる行が無くなった状態は`SQLSTATE`の`'02000'`(`SQLCODE +100`)で表されます。`Q0614A`はこれを`WHENEVER`文(専用の分岐構文)ではなく、`FETCH`のたびに`SQLSTATE = '00000'`かどうかを`dow`で直接確かめる、という06-13から続く素朴な形で書いています。ループを抜けた時点の`SQLSTATE`が`'02000'`以外なら本当のエラーですが、`Q0614A`はそこまでは判定していません(06-13で`SQLSTATE`・`GET DIAGNOSTICS`によるエラー処理は既に扱ったため、ここでは繰り返しません)。

### `PREPARE`+`?`マーカー: 動的SQL

`Q0614A`は、検索するSQL文そのものを、実行時に**文字列**として組み立てています。

```rpgle
wStmt = 'SELECT JUNO, JUDATE FROM JUCHUM'
      + ' WHERE JUTOK = ? ORDER BY JUNO';

exec sql PREPARE S1 FROM :wStmt;
exec sql DECLARE C1 CURSOR FOR S1;
exec sql OPEN C1 USING :wCustCode;
```

`WHERE JUTOK = ?`の`?`が**パラメーター・マーカー**です。検索する得意先コードの実際の値(`wCustCode`)は、SQL文字列の中には一切現れません。`OPEN C1 USING :wCustCode`の時点で、マーカーに値が束縛されます。

**この検索なら、マーカーを使わない静的なカーソル(`DECLARE C1 CURSOR FOR SELECT JUNO, JUDATE FROM JUCHUM WHERE JUTOK = :wCustCode ORDER BY JUNO`、`PREPARE`なし)でも同じ結果になります。** `Q0614A`があえて`PREPARE`+`?`マーカーを使っているのは、動的SQLという技法そのものを練習するためです。両者の違いは、SQL文自体をプログラム内の**固定の文字列**として書くか(静的)、実行時に組み立てる**変数**として扱うか(動的)にあります。検索条件そのものを画面などから受け取り、SQL文の**構造**(たとえば`WHERE`句に条件を足すかどうか)まで実行時に変えたい場合は、動的SQLでなければ書けません。

### ネイティブI/Oとの対応

`Q0614A`がやっていることは、`R0408A`(`JUCINQ3`、04-08)・`F0604A`(06-04)と業務ロジックとしては同じです。対応をまとめると次のとおりです。

| ネイティブI/O(`R0408A`・`F0604A`) | SQL(`Q0614A`、本レッスン) |
|---|---|
| `CUST CHAINTOKUIM 99` / `%found(tokuim)` | `SELECT TOKNM INTO :wCustName FROM TOKUIM WHERE TOKCD = :wCustCode`(静的`SELECT INTO`) |
| `READ JUCHUM`を繰り返す(`dow not %eof(juchum)`) | `FETCH C1 INTO ...`を繰り返す(`dow SQLSTATE = '00000'`) |
| `JUTOK IFEQ CUST`(絞り込みをRPG側で行う) | `WHERE JUTOK = ?`(絞り込みをSQL側で行う、パラメーター・マーカーで束縛) |
| ファイル全体を`READ`で舐めてから絞り込む | `ORDER BY JUNO`付きの`SELECT`一発で、絞り込み済みの行だけを結果セットにする |

**一番大きな違いは「絞り込みをどちら側が行うか」です。** ネイティブI/Oでは、`JUCHUM`を先頭から`READ`し、一致する行かどうかをRPG側の`IFEQ`/`if`で判定していました。SQLでは、絞り込み自体を`WHERE`句としてデータベース側に渡し、結果セットには最初から一致した行しか入ってきません。

### 囲み: SQLインデックスと論理ファイル、`Visual Explain`(読解用)

キー付き論理ファイル(第2部で扱った`TOKUIL1`のキー(`K TOKNM`)等)も、SQLの**インデックス**も、どちらも「行を高速に検索・並べ替えるための、データそのものとは別の道しるべ」という点では同じ**アクセス・パス**です。違うのは選び方です。ネイティブI/Oでは、プログラム自身が`CHAIN`/F仕様書で「どの論理ファイル(キー)を使うか」を明示します。SQLでは、プログラムは`WHERE`句・`ORDER BY`句で「何を求めるか」を書くだけで、実際にどのインデックス(またはキー付き論理ファイル)を使うかは、データベースの**オプティマイザー**が統計情報などから選びます。

**`Visual Explain`は、IBM iのGUIツール(ACS、Access Client Solutions)に含まれる機能で、オプティマイザーが実際にどのアクセス・パスを選んだかを図で確認できます。** この教材ではACSのGUI操作自体をまだ扱っておらず(第9部で扱う予定の道具です)、ここでは存在を知っておくだけにとどめます。実際に操作する演習はありません。

### コミットメント制御: 06-13からの続き

`Q0614A`も、06-13の`Q0613A`と同じく`SET OPTION commit = *none, naming = *sys;`を指定しています。理由も同じです——`TOKUIM`はjournaledされていない(P12で確認済み。詳しくは06-13・`docs/probes.md`参照)ため、既定の`COMMIT(*CHG)`のままだと`SQL7008`(ジャーナルが要る操作を、journaledでない表に対して行おうとした)に当たる可能性があります。`Q0614A`自体は読み取り(`SELECT`・カーソル)しか行わないので実害はありませんが、06-13から続く同じ設定として明記しています。

**もう1点、06-13から持ち越した宿題があります。** 06-13では`CLOSQLCSR`(既定`*ENDACTGRP`、明示的に指定できる`*ENDMOD`)について、「`Q0613A`自身はカーソルも準備済みステートメントも持たないため、この違いが動作として観察できる場面はレッスンには無く、カーソルを扱う06-14で初めて意味を持ってくる」と述べていました。ところが`Q0614A`の`SET OPTION`は、`closqlcsr`句自体を含んでいません(`commit = *none, naming = *sys;`のみ)。句を省略した場合の既定値は`CRTSQLRPGI`自身の既定値と同じ`*ENDACTGRP`(一次資料・`CRTSQLRPGI`コマンド解説ページによる)なので、`Q0614A`は`*ENDACTGRP`の下で動作しています。ただし`Q0614A`はカーソル`C1`を、`FETCH`ループを抜けた直後に`exec sql CLOSE C1;`で自分自身から明示的に閉じています(上の「カーソル+複数行`FETCH`」参照)。そのため`C1`は活性化グループの終了(`*ENDACTGRP`が閉じるタイミング)を待たずに閉じられており、ここでも`*ENDACTGRP`と`*ENDMOD`の違いが動作として観察できる場面はありません。**06-13で持ち越した`CLOSQLCSR`の観察可能な違いは、結局このレッスンでも確認できないまま残ります**(自分でカーソルを閉じずに活性化グループを終える、という状況を作らない限り、違いは表面化しないと考えられます)。

**コミットメント制御が本当に意味を持つのは、複数のSQL文を「全部成功するか、全部無かったことにするか」の1つの単位にまとめたい場面です。** たとえば複数件の`UPDATE`/`INSERT`をひとまとまりの取引として扱い、途中で失敗したら`ROLLBACK`で全部取り消す、成功したら`COMMIT`で確定する、という使い方です。これには対象の表がjournaledされている必要があります。**このレッスンでは、自分でジャーナルを作って`COMMIT`/`ROLLBACK`を実際に試すところまでは扱いません**(`Q0614A`自体もそれを行っていません)。ジャーナルの作成自体は05-11で`DSPJRN`の存在紹介として触れたとおり、この教材の範囲外に近い、もう一段深い話です。気になる場合は、自分でjournaledな表を作って`INSERT`→`ROLLBACK`→`SELECT`で行が残っていないことを確かめてみてください(未検証・任意の発展課題です)。

## 実演

**この実演で作るオブジェクト(`Q0614A`)は、著者による実機コンパイル・実行(V2、下の「実機メモ」参照)まで確認済みです。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込む(1回の接続でまとめて行います)。`QRPGLESRC`は06-01b以降のどこかで、すでに作成済みのはずです。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/q0614s.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/Q0614A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`CRTSQLRPGI`でコンパイルする(埋め込みSQLは`CRTBNDRPG`ではなく`CRTSQLRPGI`でコンパイルします。06-13と同じです)。

   ```text
   CRTSQLRPGI OBJ(<自分のユーザー名>1/Q0614A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(Q0614A) OBJTYPE(*PGM) COMMIT(*NONE)
   ```

   Highest Severity 00になることを確認してください。

4. `CALL PGM(<自分のユーザー名>1/Q0614A)`を実行し、`WRKSPLF`で次のように印刷されることを確認してください(`R0408A`(04-08)・`V0601A`(06-01)がそれぞれ確認済みの`C00001`→`J00001`/`J00003`という値と同じです)。

   ```text
   Customer C00001: ACME TRADING CO
     Order J00001 dated 20260901
     Order J00003 dated 20260905
   ```

## 演習

1. `wCustCode`の`inz`値を`'C00001'`から`'C00003'`に変えて再コンパイル・実行し、`J00004`・`J00008`の2件が印字されることを確認してください(`JUCHUM`のこの得意先の注文自体は`db/data/load_v1.sql`で定義されている値です。04-08・06-04にも同じ値を使った演習がありますが、いずれも読者向けの演習として提示されているだけで、著者による実機確認済みではありません)。

2. 動的SQLの`WHERE`句に、2つ目のパラメーター・マーカーを追加してみてください。たとえば「指定した受注番号以上の注文だけ」に絞り込むなら、次のようになります。

   ```rpgle
   dcl-s wMinOrder char(6) inz('J00003');

   wStmt = 'SELECT JUNO, JUDATE FROM JUCHUM'
         + ' WHERE JUTOK = ? AND JUNO >= ? ORDER BY JUNO';
   ...
   exec sql OPEN C1 USING :wCustCode, :wMinOrder;
   ```

   `wCustCode`が`'C00001'`のままなら、`J00001`は絞り込まれて消え、`J00003`の1行だけが印字されるはずです。実際に試して確認してください。

3. (発展)`?`マーカーを使わない、静的なカーソルに書き換えてみてください。

   ```rpgle
   exec sql DECLARE C1 CURSOR FOR
     SELECT JUNO, JUDATE FROM JUCHUM
       WHERE JUTOK = :wCustCode ORDER BY JUNO;
   exec sql OPEN C1;
   ```

   `PREPARE`の行はまるごと不要になります。同じ結果になることを確認したうえで、動的SQL(`PREPARE`+`?`マーカー)版と何が違うか(SQL文が固定の文字列か、実行時に組み立てる変数か)を自分の言葉で説明してください。

## セルフチェック

- [ ] カーソルの`DECLARE`/`OPEN`/`FETCH`/`CLOSE`それぞれの役割を説明できる。
- [ ] `PREPARE`+`?`マーカーで、検索条件を実行時に安全に差し込めることを説明できる。
- [ ] `Q0614A`をコンパイル・実行し、`C00001`について`ACME TRADING CO`・`J00001`・`J00003`が印字されることを確認できた。
- [ ] `R0408A`(04-08)・`F0604A`(06-04)のネイティブI/Oロジックと、`Q0614A`のSQLロジックの対応(絞り込みをどちら側が行うか)を自分の言葉で説明できる。
- [ ] `Q0614A`が`JUCINQ`コマンドにはつながっていない、独立した比較デモであることを説明できる。
- [ ] SQLインデックスとキー付き論理ファイルが、どちらも「アクセス・パス」であり、選び方が違うだけであることを説明できる(`Visual Explain`は存在を知っていればよい)。

## 片付け

`Q0614A`はそのまま残してください。`TOKUIM`・`JUCHUM`は読み取り専用のアクセスしかしていないので、データは書き換わらず、`TXRESET`も不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Cursor | カーソル |
| Prepared statement | 準備済みステートメント |
| Parameter marker | パラメーター・マーカー |
| Dynamic SQL | 動的SQL |
| Static SQL | 静的SQL |
| Access path | アクセス・パス |
| Commitment control | コミットメント制御 |

次のレッスン(06-14b)では、`DATE`/`TIMESTAMP`/`VARCHAR`型と、SQLのNULL・RPGの`%nullind`/`ALWNULL`を扱います。

## 実機メモ

- 確認日: 2026-09-27。`part06-1314-sql`という接続(06-13の`Q0613A`・`Q0613V`と、本レッスンの`Q0614A`をまとめて検証する接続)の1回目で、`Q0613A`・`Q0613V`は`GET DIAGNOSTICS`の項目名`DB2_MESSAGE_TEXT`が無効という06-13側のコンパイル・エラー(`SQL0104`)を出しましたが、これは06-13自身の問題で`Q0614A`には影響していません。**`Q0614A`は1回目の接続から`CRTSQLRPGI`Highest Severity 00でコンパイルに成功し(V1)、続けて実行した`CALL`の出力も、接続の生ログ(runセクション)にコンパイル・リストの直後、次のとおり印字されていました(V2)。**

  ```text
  Customer C00001: ACME TRADING CO
    Order J00001 dated 20260901
    Order J00003 dated 20260905
  ```

  この値は`R0408A`(04-08)・`V0601A`(06-01)がそれぞれ確認済みの`C00001`→`J00001`/`J00003`という値と一致しています。
- **2回目の接続で、同じコンパイル・実行を独立にやり直し、同じ結果を再確認しました(CONFIRMED SUCCESS)。** `CRTSQLRPGI OBJ(<USER>2/Q0614A) SRCFILE(<USER>2/QRPGLESRC) SRCMBR(Q0614A) OBJTYPE(*PGM) COMMIT(*NONE)`がHighest Severity 00、`CALL PGM(<USER>2/Q0614A)`の実行結果が、1回目と1文字も違わず一致していることを、接続の生ログ(runセクション)で確認しました。
- **この検証ハーネスの非対話SSHジョブでは、印刷出力は実スプール・ファイルになりません。** 同じ接続の中で`CPYSPLF FILE(QSYSPRT) TOFILE(<USER>2/VFYSPL) ...`を試したところ、`Q0613A`・`Q0613V`・`Q0614A`のいずれも`CPF3303: File QSYSPRT not found in job .../QP0ZSPWT.`で失敗しており、上記の印字内容は`WRKSPLF`ではなく、**接続の生ログ(runセクション)を直接読んで確認したもの**です。学習者自身の5250セッションでは、`WRKSPLF`で普通にスプール・ファイルとして確認できます。
- 演習1(`C00003`に変えたときの`J00004`/`J00008`)・演習2(2つ目のパラメーター・マーカー)・演習3(静的カーソルへの書き換え)は、`Q0614A`自体としてはまだ実機で試しておらず、未検証(2026-09-28時点)のままです。`JUCHUM`の`C00003`→`J00004`/`J00008`という対応自体は`db/data/load_v1.sql`で定義されている値です(04-08・06-04にも同じ値を使った演習がありますが、いずれも著者による実機確認済みではありません)。`Q0614A`でも同じ結果になる**はずです**が、次回接続で実際に確認したい点として残します。
- SQLインデックスと論理ファイルのどちらをオプティマイザーが実際に選ぶかを`STRSQL`だけで見られるかどうかは未確認のままです。`Visual Explain`自体もこのレッスンでは操作しておらず、存在の紹介にとどめています。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
