# 06-14b DATE/TIMESTAMP/VARCHAR・NULL(`%nullind`・`ALWNULL`・NULL標識)

> 所要時間: 60分 / 前提レッスン: 06-14 / 目標番号: 5 / 観測方法: `WRKSPLF` / 道具: 5250(コンパイル・実行・確認)、SSH(`CPYFRMSTMF` でのソース取り込み)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/Q0614BA`(SQLRPGLE)。実行するたびに `QTEMP/W0614BA` を自分で作り直す(共有スキーマには一切触れない)/ DBVER: なし(下記「片付け」参照)/ 依存するプローブ: P25(`CRTSQLRPGI`)。`ALWNULL`/`%nullind` 専用の確認プローブはまだ用意されていない / PTF 依存: なし / 容量の目安: わずか(`QTEMP` の作業テーブルのみ、ジョブ終了で消える)

## ゴール

- D仕様書で `date`/`timestamp`/`varchar(n)` を宣言できる(RPG III時代の8桁数値日付との違いを説明できる)。
- `ctl-opt alwnull(*usrctl)` + `NULLIND` キーワード + `%nullind` で、RPGネイティブのNULL許容フィールドを扱える。
- SQLのNULL標識ホスト変数(FETCH時にホスト変数の直後へ続ける、2つ目の変数)を使い、フェッチしたNULL値をRPGの `%nullind` へ明示的に橋渡しできる。
- **静的SQLがプリコンパイル時にアクセス・プランを確定しようとするため、その時点でまだ存在しないテーブル(自分のプログラムがその場で作る `QTEMP` のテーブルなど)に対してどんな警告が出るかを説明でき、06-14の `PREPARE`/動的SQLで書き直すとその警告が出る理由そのものが無くなることを説明できる。**

## ウォームアップ

<details><summary>前回の復習(06-14)</summary>

1. 06-14の `Q0614A` は、得意先コードで注文を検索するために `PREPARE`+`?`マーカーの動的SQLを使いました。同じ検索は、`SELECT ... WHERE JUTOK = :wCustCode` のような**静的SQL**(ホスト変数をそのまま使うだけで `PREPARE` は不要)でも書けたはずです。それでも `Q0614A` があえて動的SQLを使ったのはなぜですか?
2. カーソルを `FETCH` していき、「これ以上行が無い」状態になったとき、`SQLSTATE` にはどんな値が入りますか?

答え: 1. 06-14自体の目標が動的SQLという**技法そのもの**を実演することだったためです(静的SQL+ホスト変数でも同じ検索結果は得られますが、`PREPARE`/`DECLARE ... CURSOR FOR` 済みのステートメントへ、`OPEN ... USING` で検索値を後から結び付ける、という動的SQLの形を練習する目的でした)。 2. `'02000'`(`SQLCODE` では `+100`)です。

</details>

## なぜ学ぶか

06-14では、`PREPARE`+`?`マーカーによる動的SQLを学びました。「なぜ静的SQLではなく動的SQLという技法が要るのか」は、06-14の時点では**技法の練習**という位置づけでした(静的SQLでも同じ検索は書けたので)。

このレッスンでは、動的SQLが単なる練習ではなく**実際に効いてくる**具体的な場面に出会います。プログラム自身が実行時に `CREATE TABLE` で作った `QTEMP` の作業テーブルに対して、続けて普通の(静的な)`DECLARE CURSOR FOR SELECT ...` や普通の `INSERT` を書くとどうなるでしょうか。**`CRTSQLRPGI` を実行している時点(プリコンパイル時)では、`QTEMP/W0614BA` はまだこの世に存在しません**(このプログラム自身が、実行されて初めて作るテーブルだからです)。静的SQLは、まさにこのプリコンパイル時点でアクセス・プラン(どの列がどこにあるか、という実行計画)を確定しようとするため、プリコンパイラーは列定義を実物のテーブルから確認できず、`SQL1103`(列定義が見つからない、という警告)を出します。06-14の `PREPARE`/`EXECUTE IMMEDIATE` は、SQL文の中身をプリコンパイラーに直接見せない(ただのRPG文字列として持たせ、実行時にSQLエンジンへ渡す)ことで、この警告そのものが出る余地を無くす技法でした——ここで初めて、動的SQLを**実際に使う**理由に出会います。

あわせて、SQLの `DATE`/`TIMESTAMP`/`VARCHAR` という型と、RPG IIIから馴染みのある「8桁の数値日付」(`TOKUPD` のような数値フィールドに `20260905` を入れる方式)との違い、そして「NULL」という、空白でもゼロでもない第3の状態を扱います。

## 新出

- 中核概念:
  1. SQLの `DATE`/`TIMESTAMP` 型・RPGの `date`/`timestamp` 型は、RPG IIIの「8桁の数値日付」(`TOKUPD` 等)とは別物である(桁数ベースの日付表現との対比)。
  2. NULLは「空白」でも「ゼロ」でもない第3の状態であり、これを扱うにはRPG側の明示的な準備(`ALWNULL(*USRCTL)`)が要る。
  3. **静的SQLはプリコンパイル時にアクセス・プランを確定しようとするため、まだ存在しないテーブル(`QTEMP` 上に自分で作るテーブル等)に対しては列定義を実物から確認できず、`SQL1103` という警告が出る——動的SQL(`PREPARE`/`EXECUTE IMMEDIATE`)は、SQL文の中身をプリコンパイラーに直接見せないことで、この警告が出る余地そのものを無くす。**
- 構文:
  - D仕様書の型としての `date`/`timestamp`/`varchar(n)`
  - `ctl-opt ... alwnull(*usrctl)`
  - `%nullind(フィールド名)`(NULL標識の読み書き。対象のフィールド定義には、パラメーターなしの `NULLIND` キーワードを付けて単項目をNULL許容にしておく)
  - SQLのNULL標識ホスト変数(`FETCH ... INTO` で、対象のホスト変数の直後に続ける整数変数)
  - `EXECUTE IMMEDIATE :ホスト変数`(06-14の `PREPARE`+`?`マーカーの自然な延長。マーカーが要らない固定文用)

## 説明

このレッスンで作るプログラムは `src/qrpglesrc/q0614bs.sqlrpgle` です。学習者オブジェクト名は `Q0614BA`。業務ニックネームはありません(06-04の `JUCINQ4D` のような通し例とは違う、独立した文法デモです)。

### `QTEMP` だけで完結する理由

このプログラムは、`TOKUIM`(得意先マスター)を縮小・改造した独自の作業テーブル `W0614BA` を `QTEMP` 上に作り、そこにサンプル行を自分で `INSERT` し、自分で読み返します。**既存の共有データベース(`TOKUIM` 本体)は一切開かず、一切変更しません。** 既存のサンプルDBを直接NULL許容に変更すると、DBVERの管理対象やほかのレッスンとの整合が崩れてしまうためです。`QTEMP` はジョブ終了とともに消えるライブラリーなので、このレッスンの片付けに `TXRESET` は要りません(下の「片付け」参照)。

### DATE/TIMESTAMP/VARCHARという型

```rpgle
dcl-s wLastOrderSql date;
dcl-s wTokLts        timestamp;
dcl-s wToknm          varchar(30);
```

RPG IIIでは、日付は `TOKUPD` のような8桁の数値フィールド(`20260905` のような整数)で表す以外の方法がありませんでした。RPG IVには、SQLの `DATE`/`TIMESTAMP` 型にそのまま対応する `date`/`timestamp` という型があります。桁数を数える数値フィールドではなく、専用の型として日付・日時を持てるようになります。`varchar(n)` も同様で、Db2の `VARCHAR` 列とRPGのホスト変数が直接対応します(`CHAR`↔`char` の対応と同じ形です)。

`W0614BA` の定義は次のとおりです(`Q0614BA` 自身が実行時に埋め込みSQLで作ります)。

```sql
CREATE TABLE QTEMP/W0614BA (
  TOKCD   CHAR(6)     NOT NULL,
  TOKNM   VARCHAR(30) NOT NULL,
  TOKLORD DATE,
  TOKLTS  TIMESTAMP   NOT NULL
);
```

`TOKLORD`(最終受注日)だけがNULL許容(制約なし、`NOT NULL`が付いていない)で、それ以外の3列は`NOT NULL`です。**NULLをテーマにするレッスンでも、NULL許容にする列は必要な分だけに絞り、それ以外は`NOT NULL`のままにする**のが自然な設計です。

`CREATE TABLE` を実行した直後は、次のように `SQLCODE` だけを確認しています(`SQLSTATE = '00000'` ではありません)。

```rpgle
if SQLCODE < 0;
  prtText = 'CREATE TABLE failed, SQLCODE=' + %char(SQLCODE);
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;
```

`QTEMP` にはジャーナルが無いため、`QTEMP` 上へのテーブル作成では「作成はできたがジャーナルされていない」という**正の`SQLCODE`(クラス`01`の警告)**が返ることがある、というのが一般的なDb2 for iの挙動です(この教材の`Q0614BA`は`SQLCODE < 0`かどうかしか確認しておらず、成功時に実際どんな正の値が返るかは実機で確認していません)。少なくとも、`SQLSTATE = '00000'` ではないからといって失敗として扱ってはいけません。**負の`SQLCODE`だけが本当のエラー**です(一次資料の説明どおりです)。ここで `SQLSTATE` ではなく `SQLCODE` を見ているのは、そのためです。

### NULLは第3の状態: `ALWNULL`・`NULLIND`・`%nullind`

```rpgle
ctl-opt dftactgrp(*no) actgrp(*new) alwnull(*usrctl);
...
dcl-s wLastOrder date NULLIND;
```

RPGのフィールドは、既定では**NULLを持てません**(数値なら0、文字なら空白が「値が無い」の代用になるだけで、NULLそのものとは別概念です)。フィールドをNULL許容にするには、`ALWNULL(*USRCTL)` を**制御仕様書に明示するか、コンパイル・コマンドのパラメーターとして指定するか**、どちらかの方法で指定する必要があります(一次資料・ILE RPG言語リファレンスの `%NULLIND` の説明は「on a control specification or as a command parameter」とこの2通りを両方認めています。`%NULLIND` BIF自体、いずれかの指定が無いと使えません)。このレッスンでは前者、`ctl-opt` の制御仕様書を使います。そのうえで、対象のフィールド定義に `NULLIND` キーワードを**パラメーターなしで**付けると、そのフィールドはNULL許容になり、NULL標識は名前付きBIF `%nullind(フィールド名)` だけを通じて読み書きします(専用の標識変数を別途宣言する必要はありません)。

```rpgle
if wLastOrderInd < 0;
  %nullind(wLastOrder) = *on;
else;
  %nullind(wLastOrder) = *off;
  wLastOrder = wLastOrderSql;
endif;
...
if %nullind(wLastOrder);
  prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
          + ': last order date is NULL (unknown), last touched '
          + %char(wTokLts);
else;
  prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
          + ': last order ' + %char(wLastOrder) + ', last touched '
          + %char(wTokLts);
endif;
```

`%nullind` に `*on`/`*off` を直接代入して書き込めますし、`if` 条件の中で直接読み出すこともできます(一次資料・ILE RPG言語リファレンスの `%NULLIND` の使用例のとおりです)。

### SQL側のNULL標識とRPGの`%nullind`は別物: 橋渡しが要る

```rpgle
dcl-s wLastOrderInd int(5);
dcl-s wLastOrderSql date;
```

ここが、このレッスンでいちばん見落としやすい点です。**埋め込みSQLの `FETCH`/`SELECT INTO` がNULL値を教えてくれる仕組み(SQL側のNULL標識ホスト変数)と、RPGネイティブの `%nullind` は、別々の仕組みです。** 埋め込みSQL側では、フェッチ対象のホスト変数の直後に、NULLかどうかを受け取る**もう1つの整数変数**を続けます。

```rpgle
exec sql
  FETCH C2 INTO :wTokcd, :wToknm, :wLastOrderSql :wLastOrderInd,
                :wTokLts;
```

`:wLastOrderSql :wLastOrderInd` の並びに注目してください。**フェッチ対象のホスト変数(`wLastOrderSql`)の直後に、間にコンマを挟まず空白だけを挟んで、インジケーター変数(`wLastOrderInd`)を続けます**(このプログラム自身の実機確認済みソースがこの書き方です)。列が実際にNULLだったとき、SQLはこの整数変数に**負の値**を書き込みます(一次資料・埋め込みSQLのインジケーター変数の説明による一般的な約束で、`< 0` かどうかで判定します)。

この整数変数(`wLastOrderInd`)は、RPGの`%nullind`が自動で読んでくれるわけではありません。**上の橋渡しのコード(`if wLastOrderInd < 0; %nullind(wLastOrder) = *on; ...`)を自分で書いて、初めて両者がつながります。** 「SQLがNULLを教えてくれたのに、RPG側の`%nullind`は勝手に更新されない」という点を混同しないでください——このプログラムがわざわざ`wLastOrder`(RPGネイティブのNULL許容フィールド)と`wLastOrderSql`(ただのSQLホスト変数)を2つ持っているのは、この橋渡しを明示するためです。

### 静的SQLは「今作ったばかりのテーブル」に対してプリコンパイル時に警告を出す(このレッスンの核心)

`Q0614BA` のカーソルは、次のように**動的SQL**で書かれています。

```rpgle
cursorSql = 'SELECT TOKCD, TOKNM, TOKLORD, TOKLTS'
          + ' FROM QTEMP/W0614BA ORDER BY TOKCD';

exec sql PREPARE S1 FROM :cursorSql;
...
exec sql DECLARE C2 CURSOR FOR S1;
exec sql OPEN C2;
```

2件の `INSERT` も同様です。

```rpgle
insertSql = 'INSERT INTO QTEMP/W0614BA (TOKCD, TOKNM, TOKLORD, TOKLTS)'
  + ' VALUES (''C00001'', ''ACME TRADING CO'', DATE ''2026-09-05'','
  + ' TIMESTAMP ''2026-09-05 08:30:00'')';
exec sql EXECUTE IMMEDIATE :insertSql;
```

なぜ、素直に `EXEC SQL DECLARE C2 CURSOR FOR SELECT ... FROM QTEMP/W0614BA ...;` や、素直な `EXEC SQL INSERT INTO QTEMP/W0614BA VALUES (...);` と書かなかったのでしょうか。**静的SQL(`PREPARE` を経由しない、埋め込みSQL文をそのまま書く形)は、`CRTSQLRPGI` によるプリコンパイル時点でアクセス・プラン(どの列がどこにあるか、という実行計画)を確定しようとします。** そのときの `QTEMP/W0614BA` は、まだ**存在しません**——このプログラムが実行されて初めて、直前の `CREATE TABLE` で作られるテーブルだからです。この状態で静的SQLとして`SELECT`/`INSERT`を書くと、プリコンパイル時にコンパイル・リストへ`SQL1103`(severity 10、「列定義が見つからない」という警告)が複数箇所に出ます——プリコンパイラーは、この警告を出しつつ「文中の記述から列定義を推測」した仮のプランを作ります。

**ここは正直に書きます。** この教材の実機検証では、`SQL1103`の警告が出た版でも、コンパイル自体は通り、`CALL`も正しく実行できたケースが実際にありました(下の「実機メモ」参照)。つまり、「`SQL1103`が出たら必ず実行時に壊れる」とまでは、この教材の手元の記録だけでは言い切れません。**一方で、確実に壊れたケースも実機で踏んでいます。** カーソルだけを動的SQLに直し、`INSERT`をまだ静的SQLのまま(しかもTIMESTAMPリテラルがまだRPGネイティブの`Z`形式だった)残していた版は、コンパイル・リストに`SQL0180`(severity 30、「日付・時刻・タイムスタンプ値の構文が正しくない」)が`INSERT`のリテラル位置にそのまま出て、コンパイル自体が丸ごと失敗(`SQL9001`、`SQL precompile failed`)しました。**この失敗の直接の原因はリテラルの書式そのもの(下の「TIMESTAMPリテラルの書式に注意」参照)であり、`SQL1103`が示す「テーブルがまだ無い」という問題そのものとは別物です。**

つまり、この教材が実機で直接確認できているのは次の2点です。**(1)** 静的SQLをテーブルがまだ無い状態でコンパイルすると`SQL1103`という警告が出る(これは確実)。**(2)** 埋め込みSQL文のリテラル書式を間違えると、静的SQLでは`SQL0180`でコンパイル自体が止まる(これも確実)。**「`SQL1103`だけの状態が実行時に必ず壊れるかどうか」は、この教材ではまだ確実な答えを持っていません。**動的SQLを使う実務上の利点は、この不確かさに賭けずに済むことです——`PREPARE`/`EXECUTE IMMEDIATE`に渡すSQL文はただのRPG文字列であり、プリコンパイラーはその中身を静的な`SELECT`/`INSERT`のようには検査しません。列がまだ無いことについての`SQL1103`は、この検査自体がプリコンパイル時に行われなくなるため、出る理由そのものが無くなります。**一方、リテラル書式についての`SQL0180`は話が別です。** `EXECUTE IMMEDIATE`は書式の誤りそのものを無くすわけではなく、その誤りが**いつ・どんな形で**発覚するかを変えるだけです——プリコンパイル時点の構文エラーとしては出る余地が無くなりますが、同じ誤りが実行時に`SQLCODE`/`SQLSTATE`として現れないと決まったわけではありません(この点は下の演習3で実際に確かめます)。

一方、`CREATE TABLE`・`DROP TABLE` はそのまま静的SQLとして直接書けます(`Q0614BA` 自身も、この2文だけは `PREPARE` を使っていません)。IBMの`CRTSQLRPGI`コマンド解説(`COMMIT`パラメーターの説明)には、`CREATE`/`DROP` 系の文がプログラム中に直接コーディングできる、という記述がある一方、これらに`PREPARE`/`EXECUTE IMMEDIATE`が必要だという記述はありません。**`CREATE`/`DROP` はオブジェクトの器そのものを作る・消すだけの文で、`SQL1103`が問題にする「列定義」を持たないためだと考えられます。**

動的SQL(`PREPARE`+`EXECUTE IMMEDIATE`)は、SQL文の解析を**実行時**(`PREPARE`/`EXECUTE IMMEDIATE` が実際に実行される瞬間)まで遅らせます。同じジョブの中で、直前に `CREATE TABLE` がすでに実行されていれば、その時点では `QTEMP/W0614BA` は確実に存在します。**06-14で導入した `PREPARE`+`?`マーカーの技法は「検索条件を後から差し込む」ためのものでしたが、ここでは同じ`PREPARE`の仕組みを「静的SQLだと出てしまう警告・エラーの入り口そのものをプリコンパイラーから隠す」ために使っています**——マーカー(`?`)自体は今回のカーソルにも`INSERT`にも登場しません(検索条件を後から変えるわけではなく、文自体は固定なので不要です)。この最終版は、実機で`CALL`が期待どおりの2行を正しく印字することまで確認済みです(下の「実機メモ」参照)。

### TIMESTAMPリテラルの書式に注意

```rpgle
insertSql = 'INSERT INTO QTEMP/W0614BA (TOKCD, TOKNM, TOKLORD, TOKLTS)'
  + ' VALUES (''C00001'', ''ACME TRADING CO'', DATE ''2026-09-05'','
  + ' TIMESTAMP ''2026-09-05 08:30:00'')';
```

SQL文字列リテラルとしてTIMESTAMPを書くときは、**ANSI/ISO形式(`'yyyy-mm-dd hh:mm:ss'`、スペース+コロン区切り)** を使ってください(一次資料の日付・時刻・タイムスタンプ定数の説明に基づく形式です)。上の節で触れたとおり、この`Q0614BA`自身が、RPGネイティブの`Z`リテラル形式(ダッシュ+ピリオド区切り、`Z'yyyy-mm-dd-hh.mm.ss.nnnnnn'`)と同じ書式でTIMESTAMPを静的`INSERT`文に書いていた時期に、実際に`SQL0180`(`Syntax of date, time, or timestamp value not valid`、severity 30)でコンパイルごと拒否されています(下の「実機メモ」参照。コンパイル時に実機で確認した失敗です)。**RPGが表示・変換で使う形式(`%char` で `TIMESTAMP` を文字列化すると、ダッシュ+ピリオドの形式で出ます)と、SQL文字列リテラルとして書くときの形式は別物**だと覚えておいてください——ANSI/ISO形式に直した現在の`Q0614BA`は、実際に`CALL`が正しい`last touched`の値を印字することまで確認済みです(`EXECUTE IMMEDIATE`経由、下の「実機メモ」参照)。

## 実演

**この実演で作る `Q0614BA` は、著者による実機コンパイル・実行(V2、下の「実機メモ」参照)まで確認済みです。**

1. SSHで接続し、`~/ibmi-kyozai` を最新にする(`git pull`)。

2. ソースを取り込む。`QRPGLESRC` は06-01b以降で作成済みのはずです(まだ無ければ `CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')` を先に実行してください)。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(Q0614BA) SRCTYPE(SQLRPGLE) TEXT('DATE/TIMESTAMP/VARCHAR, NULL via %nullind')
   ```

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/q0614bs.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/Q0614BA.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`CRTBNDRPG` ではなく `CRTSQLRPGI` でコンパイルします(埋め込みSQLを含むソースは、SQLプリコンパイラーを経由する必要があります。06-13・06-14と同じコマンドです)。

   ```text
   CRTSQLRPGI OBJ(<自分のユーザー名>1/Q0614BA) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(Q0614BA) OBJTYPE(*PGM) COMMIT(*NONE)
   ```

   Highest Severity 00 になることを確認してください(著者の環境では一度目のコンパイルで通っています)。

4. `CALL PGM(<自分のユーザー名>1/Q0614BA)` を実行し、`WRKSPLF` で次の2行が印刷されることを確認してください。

   ```text
   C00001 ACME TRADING CO: last order 2026-09-05, last touched 2026-09-05-08.30.00.000000
   C00099 NEW PROSPECT CO: last order date is NULL (unknown), last touched 2026-09-20-14.15.00.000000
   ```

   1行目(`C00001`)は最終受注日(`TOKLORD`)が実在する行、2行目(`C00099`)は`TOKLORD`がNULLの行です。`last touched`(`TOKLTS`、`NOT NULL`のTIMESTAMP列)はどちらの行にも表示され、`%nullind`による橋渡しは不要です(`TOKLORD`だけがNULL許容だからです)。**このジョブのメッセージには `SQL0204`(1文目の `DROP TABLE`。まだ一度も作っていないテーブルを消そうとする、想定済みの動作)が1件混じりますが、上記の2行が正しく印刷されていれば無視してかまいません。**

## 演習

1. `CALL` をもう一度実行してください(同じジョブ内で2回目の `CALL` になります)。`DROP TABLE`→`CREATE TABLE` が毎回冒頭で行われるため、行が重複して積み上がることなく、1回目と全く同じ2行が再度印刷されるはずです。さらに、一度サインオフしてサインオンし直してから(新しいジョブで)`CALL`してみてください。`QTEMP` はジョブごとに新しく用意されるので、`W0614BA` はどのジョブでも「まだ無い」状態から始まり、それでも同じ2行が正しく印刷されるはずです。
2. `q0614bs.sqlrpgle` の2件目の `INSERT`(`C00099`)の `VALUES` 節にある `NULL` を、`DATE ''2026-09-25''` のような実際の日付に書き換えて再コンパイル・再実行し、2行目の出力が「last order date is NULL (unknown)」から「last order 2026-09-25」に変わることを確認してください。
3. (発展)`insertSql` の `TIMESTAMP ''2026-09-05 08:30:00''` の部分を、RPGネイティブの `Z` リテラルと同じ書式(`TIMESTAMP ''2026-09-05-08.30.00.000000''`)に書き換えたら、再コンパイル・再実行した結果はどうなると思いますか。**まず予想を書いてから**、実際に自分の接続で試してください。上の「説明」で述べたとおり、この書式が`SQL0180`になること自体は、**静的**SQL(`INSERT`文をそのまま埋め込む形)でコンパイル時に実機確認済みです。しかし今の`insertSql`は`EXECUTE IMMEDIATE`で実行する**動的**SQLの文字列であり、その中身はプリコンパイラーではなくSQLエンジンが実行時に読みます。同じ`SQL0180`が今度は**コンパイル時ではなく実行時**(`SQLCODE`/`SQLSTATE`として)に現れるのか、それとも何か別の結果になるのかは、この教材ではまだ誰も試したことがありません——あなたの結果が、その最初の確認になります。試したら元の形式に戻してください。

## セルフチェック

- [ ] `date`/`timestamp`/`varchar(n)` を、RPG IIIの8桁数値日付との違いとともに説明できる。
- [ ] `ALWNULL(*USRCTL)`・`NULLIND`キーワード・`%nullind`の役割をそれぞれ説明できる。
- [ ] SQL側のNULL標識ホスト変数(`FETCH ... INTO :host :ind`)と、RPGの`%nullind`が別の仕組みであり、明示的な橋渡しが必要なことを説明できる。
- [ ] 静的SQLがプリコンパイル時にアクセス・プランを確定しようとするため、まだ存在しないテーブルに対して`SQL1103`という警告が出ること、動的SQL(`PREPARE`/`EXECUTE IMMEDIATE`)がこの警告そのものをどう避けるかを、自分の言葉で説明できる。
- [ ] `Q0614BA`を実際にコンパイル・実行し、`C00001`(実日付)・`C00099`(NULL)の2行が正しく印字されることを確認できた。

## 片付け

`Q0614BA`はそのまま残してかまいません。このレッスンが触れるテーブル(`W0614BA`)は`QTEMP`上にしか存在せず、ジョブが終わると自動的に消えます。**既存の共有データベース(`TOKUIM`など)は一切変更していないため、このレッスンには`TXRESET`は不要です。**

## まとめ

| 英語 | 日本語 |
|---|---|
| Null | NULL(値が無いことを表す第3の状態。空白ともゼロとも違う) |
| Null indicator | NULL標識 |
| Null-capable | NULL許容(そのフィールド/列がNULLを持てること) |
| Static SQL | 静的SQL(埋め込みSQL文をそのまま書く形。プリコンパイル時にアクセス・プランを確定しようとする) |
| Dynamic SQL | 動的SQL(`PREPARE`/`EXECUTE IMMEDIATE`。SQL文の解析を実行時まで遅らせる) |
| Access plan | アクセス・プラン(SQL文の実行計画。どの列がどこにあるか等) |
| Precompile | プリコンパイル(`CRTSQLRPGI`が埋め込みSQLを事前に処理する段階) |

次のレッスン(06-15)では、これまでの第6部の技法を総動員したチェックポイントとして、在庫照会をサブファイル+SQLで作り直します。

## 実機メモ

- **確認日: 2026-09-27。接続`part06-decisions-3`で最終的にCONFIRMED SUCCESS(V2)。** `CRTSQLRPGI`はコンパイル完了通知(`RNS9304`)が"00 highest severity"を報告して成功し(V1)、`CALL`は期待どおりの次の2行を印字した——**この2行、および`SQL0204`(下記参照)は、いずれも検証ハーネスの接続結果(`run`セクション)のテキストをそのまま読んで確認したものであり、`WRKSPLF`ではありません**(この検証ハーネスの非対話SSHジョブでは、`QSYSPRT`のような印刷装置ファイルへの出力が実スプール・ファイルにならず、接続結果の`run`セクションへ直接流れ込むためです。学習者自身が対話的な5250から`CALL`する場合は、`WRKSPLF`で見るのが自然な確認方法です)。同じ接続結果の中に、想定どおり`SQL0204`(`W0614BA in QTEMP type *FILE not found`、1文目の`DROP TABLE`によるもの)も1件含まれていた——ソースがこの文の直後に`SQLCODE`を確認していないとおり、後続の2行の印字を妨げていない。

  ```text
  C00001 ACME TRADING CO: last order 2026-09-05, last touched 2026-09-05-08.30.00.000000
  C00099 NEW PROSPECT CO: last order date is NULL (unknown), last touched 2026-09-20-14.15.00.000000
  ```

- **この最終形にたどり着くまでに、実機で複数の版を試している。次の2点は、実機の接続結果(コンパイル・リストおよび`run`セクションのテキスト)を読んで確認した確実な事実である。**
  - **(1) `SQL1103`は出るが、それだけでは必ずしも壊れない場合がある。** カーソルの`SELECT`と2件の`INSERT`をすべて静的SQL(`DECLARE CURSOR FOR SELECT ...`・普通の`INSERT`、`TOKLTS`(TIMESTAMP列)を持たない、もっと単純な初期の版)で書いた版を、`QTEMP/W0614BA`を事前に用意せず(priming、つまりあらかじめ同じ構造のテーブルを別途作っておく回避策を使わず)に接続したところ(確認日2026-09-27、接続`part06-14b-null`の1回目)、SQLプリコンパイル段階で`SQL1103`(列定義が見つからない、severity 10の警告)を複数箇所出しました——このプリコンパイル段階自体は「10 level severity errors found in source」で完了しており、既定の`GENLVL`(10)を超えていないためコンパイラー本体がそのまま呼び出されています(一次資料・`CRTSQLRPGI`の`GENLVL`(`Severity level`)の説明どおりです)。続くRPGコンパイル完了通知(`RNS9304`)は"00 highest severity"を報告し(V1。この"00"はRPGコンパイル本体自身の集計で、手前のSQLプリコンパイル段階が出した`SQL1103`のseverity 10とは別集計です——両者を混同しないでください)、`CALL`も`C00001`/`C00099`の2行を正しく印字しました(V2。この2行は接続結果の`run`セクションのテキストから読み取ったもので、コンパイル・リストの文面ではありません。TIMESTAMP列を持たない古い書式の2行で、`last touched`は無い)。接続結果に含まれていた`SQL0204`は1件だけで、想定どおり1文目の`DROP TABLE`(まだ一度もテーブルを作っていない状態でのDROP)によるものでした。**つまり、「`SQL1103`が出ただけでは、必ず実行時に壊れるとは言い切れない」ことが、この接続からわかる。**
  - **(2) 埋め込みSQLのリテラル書式を間違えると、静的SQLは確実にコンパイルごと壊れる。** カーソルだけを動的SQL(`PREPARE`+`DECLARE ... CURSOR FOR`)に直し、2件の`INSERT`をまだ静的SQLのまま(しかもTIMESTAMPリテラルがまだRPGネイティブの`Z`形式だった)残していた版は、接続`part06-decisions-1`・`part06-decisions-2`のどちらでも`SQL9001`(`SQL precompile failed`)でコンパイル自体が失敗した(コンパイル時に実機で確認した失敗)。コンパイル・リストを直接読むと、原因は`SQL0180`(severity 30、「日付・時刻・タイムスタンプ値の構文が正しくない」)が`INSERT`のTIMESTAMPリテラルの位置に2件(2つの`INSERT`それぞれ1件ずつ)出ていたことで、`SQL1103`が示す「テーブルがまだ無い」という問題とは別の、リテラル書式そのものの構文エラーだった。
  - **両方の`INSERT`も`EXECUTE IMMEDIATE`による動的SQLに直し、あわせてTIMESTAMPリテラルをANSI/ISO形式(スペース+コロン区切り)へ修正した最終版を、`part06-decisions-3`で単独確認したところ、priming無しで一発でCONFIRMED SUCCESSした(上記の2行、V2)。この接続でも、コンパイル完了通知(`RNS9304`)は上記(1)と同じ"00 highest severity"を報告していますが、(1)ではこの"00"の横で`SQL1103`が3件出ていたとおり、この値自体は手前のSQLプリコンパイル段階の警告・エラーの有無を示す間接的な証拠にはなりません。この接続では、動的SQL部分のコンパイル・リスト(`DIAGNOSTIC MESSAGES`)自体が接続結果に含まれておらず、`SQL1103`・`SQL0180`が出なかったことをコンパイル・リストの文面で直接確認したわけではない——`PREPARE`/`EXECUTE IMMEDIATE`に渡す文はただのRPG文字列変数であり、プリコンパイラーがその中身を静的`SELECT`/`INSERT`と同じようには検査しないという、動的SQLの一般的な性質から論理的に導かれる結論である。**
- `TIMESTAMP`リテラルをRPGネイティブの`Z`形式(ダッシュ+ピリオド区切り)のままSQL文字列リテラルに使うと`SQL0180`になる、という点自体は、上記の`Q0614BA`自身の静的`INSERT`(`part06-decisions-1`・`part06-decisions-2`の両方の接続結果で同一の失敗を確認、コンパイル時に実機で確認した失敗)、および上記とは別の設計案(このプログラムと同じ構造のテーブルを`QTEMP`ではなく永続ライブラリーへ作る案。採用されず、検証専用のまま残っている)の準備データを`RUNSQL`で投入しようとした際の失敗の、2つの独立した経路で確認済み。確定しているのは、ANSI/ISO形式(スペース+コロン区切り)の方は`Q0614BA`自身の埋め込みSQL(`EXECUTE IMMEDIATE`)で実際に動作したという事実である。
- 演習3(TIMESTAMPを`Z`形式で書き換えて`EXECUTE IMMEDIATE`経由で試す)は、この教材ではまだ誰も試したことがなく、著者自身も未検証のままである(**未検証(2026-09-28時点)**。`Z`形式が`SQL0180`になること自体は、上記のとおり**静的**SQL経由でコンパイル時に実機確認済みだが、**動的**SQL(`EXECUTE IMMEDIATE`)経由で実行時にどうなるかは、対話5250操作を要する`V3`ではなく、単に「まだ試していない」に分類される)。
- `ALWNULL(*USRCTL)`・`NULLIND`キーワード・`%nullind`によるNULL判別のロジック自体は、上記の最終CONFIRMED SUCCESSの接続で、`C00099`行が実際に「last order date is NULL (unknown)」と正しく印字されたことをもって実機確認済み(V2)。ただし、`ALWNULL`/`%nullind`だけを対象にした専用の実機プローブはまだ存在しない。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
