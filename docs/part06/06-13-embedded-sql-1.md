# 06-13 埋め込み SQL (1)

> 所要時間: 60分 / 前提レッスン: 06-12 / 目標番号: 5 / 観測方法: `WRKSPLF` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行、`WRKSPLF`)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/Q0613A`(SQLRPGLE)。演習で複写する`<USER>1/Q0613B`は`SQL7008`再現用としてそのまま残します / DBVER: 1 / 依存するプローブ: P12(`TOKUIM`は未journaled、確認済み)・P25(メンバーからの`CRTSQLRPGI`本体構文と`SET OPTION`除去→`SQL7008`再現のみ確認。IFS直接コンパイル・`/COPY`・`RPGPPOPT(*LVL2)`は未検証)(下の「実機メモ」参照)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- `SET OPTION`で`COMMIT`/`NAMING`/`CLOSQLCSR`を明示的に指定できる。
- `SELECT INTO`で1行を取得し、`SQLSTATE`で成否を判定できる。
- `UPDATE`のあと`SQLSTATE`で失敗を検知し、`GET DIAGNOSTICS`で詳細なエラー文言を取り出せる。
- `SQL7008`(ジャーナルされていない表への更新)を実際に再現し、なぜ`SELECT INTO`ではなく`UPDATE`側でだけこの問題が起きるのかを説明できる。

## ウォームアップ

<details><summary>前回の復習(06-12)</summary>

1. 06-12で`dcl-pi`に初めて出てきた「プログラム本体用」の使い方は、06-05で使ったサブプロシージャー用の`dcl-pi`と何が違いましたか?
2. `JUCINQ`コマンドのCPPを`JUCINQC`から`F0612A`へ`CHGCMD`で差し替えたとき、コマンド自身のインターフェース(パラメーターの型・個数)も合わせて変える必要がありましたか?

答え: 1. サブプロシージャー用の`dcl-pi`は手続き自身の引数を宣言するものでしたが、プログラム本体用の`dcl-pi`は固定形式の`*ENTRY PLIST`をそのまま置き換えるものでした。 2. いいえ。`CHGCMD`でCPP(呼ばれるプログラム)だけを差し替えれば済み、呼び出し側のインターフェースは一切変えなくてよいのが、型付きコマンドの利点でした。

</details>

## なぜ学ぶか

**ここまでの第6部は、すべてネイティブI/O(`CHAIN`・`READ`・`UPDATE`・`WRITE`といったRPGオペコードによるファイル・アクセス)でした。** `%found`・`%eof`のように名前が付いたとはいえ、根はRPG III時代の結果標識と同じ仕組みです。このレッスンからは、SQL文をRPGソースに直接書く**埋め込みSQL**を扱います。SQLは自分自身の戻りコードの体系(`SQLSTATE`)を持っており、ネイティブI/Oの結果標識とは別物として理解する必要があります。

埋め込みSQLの魅力は「1行取得」「1行更新」のような単純な処理を短く書けることですが、その裏では**コミットメント制御**という、ネイティブI/Oでは意識しなくてよかった仕組みが既定で有効になっています。`TOKUIM`(得意先マスター)はこれまでのレッスンでずっと`CHAIN`/`UPDATE`で読み書きしてきましたが、**ジャーナルされていない表**です。このレッスンでは、その事実が埋め込みSQLの既定値とぶつかると何が起きるか(`SQL7008`)を、実際に自分の手で起こしてみます。

## 新出

- 中核概念:
  1. `CLOSQLCSR`(SQLカーソルを閉じるタイミング)の既定値`*ENDACTGRP`(活性化グループの終了時)と、明示的に指定できる`*ENDMOD`(モジュールの終了時)という、区切りの単位そのものの違い。**この違いは、結果セットを返すSQL外部ルーチン(第9部09-04)で`DB2SQL`/`SQL`スタイル・`ACTGRP(*CALLER)`を明記する理由の土台になります**——呼び出し元がカーソルを読み終えるまでルーチン側の活性化グループ・カーソルが生きている必要があるため、`ACTGRP(*CALLER)`(呼び出し元と同じ活性化グループ)を明示することが重要になります。詳しい構文は09-04で扱います。
  2. `SQLSTATE`は、CLの`MONMSG`やRPG IIIの結果標識と役割(「何が起きたかを判定する」)は同じですが、SQL独自の値の体系(5文字、先頭2文字で成功/警告/エラーの大分類が決まる)を持っています。埋め込みSQLにはより古い数値の戻りコード`SQLCODE`もありますが、この教材では`SQLSTATE`に統一します。
- 構文:
  - `CRTSQLRPGI`(埋め込みSQLのプリコンパイル+コンパイルを1つのコマンドで行う)
  - `EXEC SQL SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;`
  - `SELECT ... INTO :ホスト変数, ... FROM ... WHERE ...;`
  - `SQLSTATE`(埋め込みSQLが自動的に用意する、5文字の戻りコード)
  - `GET DIAGNOSTICS CONDITION 1 :ホスト変数 = 項目名, ...;`

## 説明

### `.sqlrpgle`と`CRTSQLRPGI`

これまでの第6部のソースはすべて`.rpgle`で、`CRTBNDRPG`で直接コンパイルしてきました。埋め込みSQLを含むソースは`.sqlrpgle`という別の拡張子で保存し、`CRTBNDRPG`ではなく**`CRTSQLRPGI`**でコンパイルします。一次資料(IBMの`CRTSQLRPGI`コマンド解説ページ)によれば、`CRTSQLRPGI`は、ソース中の`EXEC SQL ...;`をSQLランタイムへの実際の呼び出しに変換する「プリコンパイル」をまず行い、既定の`OBJTYPE(*PGM)`ではそのまま`CRTBNDRPG`相当のコンパイルまで一括して実行します。ソース・メンバー自体は、これまでと同じ`QRPGLESRC`にそのまま置けます(ソース・タイプが`SQLRPGLE`になるだけです)。

### `SET OPTION` ── `commit`・`naming`・`closqlcsr`

`src/qrpglesrc/q0613s.sqlrpgle`(`Q0613A`)の該当行です。

```rpgle
exec sql SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;
```

`SET OPTION`は、`CRTSQLRPGI`のコマンド・パラメーターと同じ内容を、ソースの中に直接書けるようにするものです。一次資料(埋め込みSQLプログラミングの手引き)によれば、両方が指定された場合はソース中の`SET OPTION`が優先されます。

- **`naming = *sys`**: `library/table`という、この教材がこれまで使ってきた修飾方法に揃えます。
- **`commit = *none`**: `CRTSQLRPGI`自体の既定値`*CHG`(コミットメント制御あり)を上書きし、コミットメント制御を使わない設定にします。この1行が無いとどうなるかは、下の「演習」で実際に確かめます。
- **`closqlcsr = *endmod`**: SQLカーソル・準備済みステートメント・`LOCK TABLE`によるロックを、いつ閉じる/解放するかを指定します。一次資料(IBMの`CRTSQLRPGI`コマンド解説ページ)によれば、既定値`*ENDACTGRP`はこれらを**活性化グループの終了時**に閉じます。`*ENDMOD`はこの区切りを、それより狭い**モジュールの終了時**に変えるもので、カーソルはそこで「論理的に」閉じられます(実際に資源が解放される「物理的な」クローズは、SQLを含む呼び出しスタック上の最初のプログラムがそこを離れる時、という別のタイミングです)。**`*ENDACTGRP`が広い区切り・`*ENDMOD`が狭い区切りという事実の違いであり、「`*ENDMOD`の方が優れている」という話ではありません。** `Q0613A`自身はカーソルも準備済みステートメントも持たないため、この2つの値の違いが実際の動作として観察できる場面は、このレッスンにはありません(カーソルを扱う06-14で初めて意味を持ってきます)。

### `SELECT INTO` ── 1行を取得し`SQLSTATE`で判定する

```rpgle
exec sql
  SELECT TOKNM, TOKZIP, TOKTAN, TOKUPD
    INTO :wToknm, :wTokzip, :wToktan, :wTokupd
    FROM TOKUIM
    WHERE TOKCD = :wTokcd;

if SQLSTATE = '00000';
  prtText = 'Found ' + %trim(wTokcd) + ': ' + %trim(wToknm);
  write qsysprt prtLine;
  ...
else;
  prtText = 'SELECT INTO: no row, SQLSTATE=' + SQLSTATE;
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;
```

`:wToknm`のようにコロンを付けた変数名が**ホスト変数**(SQL文の中からRPGの変数を参照する書き方)です。`SELECT ... INTO`は、結果がちょうど1行になることが分かっている場合の読み方で、`TOKCD`(`TOKUIM`のキー)で絞り込んでいるのでここに当てはまります。`SQLSTATE`は、SQL文を実行するたびに自動的にセットされる5文字のホスト変数です(自分で`dcl-s`する必要はありません)。一次資料(埋め込みSQLプログラミングの手引き)によれば、先頭2文字が`00`なら成功(`SQLSTATE = '00000'`)、`01`または`02`なら警告や「例外だが正常」な状態(該当行が無かった場合の`02000`など)、それ以外なら実行エラーです。`TOKCD = 'C00001'`は04-08以来ずっと実在する行なので、実際には常に成功側を通ります。

### `UPDATE`・失敗判定・`GET DIAGNOSTICS`

```rpgle
exec sql
  UPDATE TOKUIM
    SET TOKNM = CONCAT(TOKNM, '')
    WHERE TOKCD = :wTokcd;

if SQLSTATE = '00000';
  prtText = 'UPDATE OK';
  write qsysprt prtLine;
else;
  prtText = 'UPDATE failed, SQLSTATE=' + SQLSTATE;
  write qsysprt prtLine;

  exec sql
    GET DIAGNOSTICS CONDITION 1
      :wMsgId   = DB2_MESSAGE_ID,
      :wMsgText = MESSAGE_TEXT;
  prtText = wMsgId;
  write qsysprt prtLine;
  prtText = wMsgText;
  write qsysprt prtLine;
endif;
```

`SET TOKNM = CONCAT(TOKNM, '')`は、同じ値をそのまま書き戻すだけの無変更な`UPDATE`です(このレッスンを何度実行しても`TXRESET`が要らないよう、わざとこう作ってあります)。文字列連結には`||`ではなく`CONCAT`関数を使っています。`||`はCCSID 273の可変文字で、配布ソースでは使えない約束になっているためです(`docs/style-guide.md`の配布ソースの文字・書式の節を参照)。

`SQLSTATE`がエラーを示したときは、`GET DIAGNOSTICS`でより詳しい情報を取り出せます。`CONDITION 1`は、直前のSQL文が起こした条件のうち最も詳しい(あるいは唯一の)ものを指します。**項目名には実機ごとの差があります。** 一次資料(埋め込みSQLプログラミングの手引き)の実例には`DB2_MESSAGE_ID`と`DB2_MESSAGE_TEXT`を並べて使うものがありますが、この教材が対象にしている実機(現在のPTFレベル)では`DB2_MESSAGE_TEXT`は無効なトークンで`SQL0104`になり、正しくは接頭辞なしの`MESSAGE_TEXT`でした(下の「実機メモ」参照)。**マニュアルの実例と実機の挙動が食い違ったときは、コンパイラー自身が返す診断メッセージ(有効なトークンの一覧を含みます)を優先してください。**

### `SQL7008`はなぜ`UPDATE`側でだけ起きるのか

コミットメント制御(`commit = *chg`、`CRTSQLRPGI`の既定値)は、変更(`UPDATE`/`INSERT`/`DELETE`)を後からロールバックできるように、変更内容をジャーナルに記録しながら実行します。**`TOKUIM`はジャーナルされていない表なので**、記録する場所が無く、`SQL7008`(表がジャーナルされていない)という失敗になります。**`SELECT INTO`のような読み取りには、そもそもロールバックする対象がありません。** ジャーナルを必要としないため、この問題には触れません。これが、`Q0613A`の`SET OPTION`が`commit = *none`を明示している理由であり、次の演習で実際に確かめる内容です。

## 実演

**この実演で作る`Q0613A`は、著者による実機コンパイル・実行(V2、接続結果の`run`セクションの生テキストで確認。下の「実機メモ」参照)まで確認済みです。このハーネス(非対話SSH)では`CPYSPLF`が常に`CPF3303`で失敗し、印字出力を実スプール・ファイルとして回収できないため、上の確認は`WRKSPLF`ではなく接続結果の生テキストによるものです。学習者自身が5250で`CALL`する場合は、`WRKSPLF`で同じ内容を確認できるはずです(この部分はV3、未検証)。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込む。`QRPGLESRC`は06-01b/06-03までのどこかで、すでに作成済みのはずです(まだ無ければ`CRTSRCPF FILE(<USER>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')`で作成してください)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/q0613s.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/Q0613A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`CRTSQLRPGI`でコンパイルする(`CRTBNDRPG`ではありません)。

   ```text
   CRTSQLRPGI OBJ(<USER>1/Q0613A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(Q0613A) OBJTYPE(*PGM) COMMIT(*NONE)
   ```

   Highest Severity 00になることを確認してください。**この`COMMIT(*NONE)`はソースの`SET OPTION`(`commit = *none`)と同じ値です。値が競合していないため、これだけでは「両方指定された場合はソース側の`SET OPTION`が優先される」という上の「説明」の主張を、実際に対立する値で試したことにはなりません。この優先順位は一次資料の記述に基づく説明であり、対立する値で実機確認したものではありません。**

4. `CALL PGM(<USER>1/Q0613A)`を実行し、`WRKSPLF`で次の3行が印字されていることを確認してください(著者の環境での確認結果は下の「実機メモ」のとおりです)。

   ```text
   Found C00001: ACME TRADING CO
   Zip=1000001 Rep=T00001 Updated=20260901
   UPDATE OK
   ```

## 演習

1. **`SET OPTION`から`commit = *none,`だけを取り除くと何が起きるか、自分のコピーで確かめてください。**

   ```text
   CPYSRCF FROMFILE(<USER>1/QRPGLESRC) TOFILE(<USER>1/QRPGLESRC) FROMMBR(Q0613A) TOMBR(Q0613B) MBROPT(*REPLACE)
   ```

   `WRKMBRPDM`で`Q0613B`を開き、`SET OPTION`の行から`commit = *none,`だけを取り除いてください(`naming = *sys, closqlcsr = *endmod;`はそのまま残します)。**行全体を消すのではなく、この1句だけを外す**のがポイントです。

   ```text
   CRTSQLRPGI OBJ(<USER>1/Q0613B) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(Q0613B) OBJTYPE(*PGM)
   ```

   **`COMMIT()`パラメーターをこのコマンドにも指定しないでください。** これで`Q0613B`は`CRTSQLRPGI`自身の既定値`*CHG`のままコンパイルされます。`CALL PGM(<USER>1/Q0613B)`し、`WRKSPLF`で次の5行が出ることを確認してください(実機メモに挙げた確認済みの値です)。

   ```text
   Found C00001: ACME TRADING CO
   Zip=1000001 Rep=T00001 Updated=20260901
   UPDATE failed, SQLSTATE=55019
   SQL7008
   TOKUIM in <USER>2 not valid for operation.
   ```

   1〜2行目(`SELECT INTO`)は成功したままで、3行目以降(`UPDATE`)だけが失敗することを確認してください。

2. (発展)`DSPJOBLOG`で、この`UPDATE`失敗の直接の原因として`CPF4328`(`Member TOKUIM not journaled to journal *N.`)が記録されていることを確認してください。`SQL7008`(SQLの側からの報告)と`CPF4328`(データベース・マネージャーの側からの報告)が、同じ1つの失敗を別の層から報告したものであることを確かめてください。

## セルフチェック

- [ ] `SET OPTION`の`commit`/`naming`/`closqlcsr`それぞれが何を指定しているか説明できる。
- [ ] `SELECT INTO`のあと`SQLSTATE`で成否を判定できる。
- [ ] `UPDATE`失敗時に`GET DIAGNOSTICS`で詳細なメッセージ(メッセージID・メッセージ文)を取り出せる。
- [ ] `SET OPTION`から`commit = *none,`を外すと`SQL7008`が起きること、`SELECT INTO`ではなく`UPDATE`側でだけ起きることを、実機で確認できた。
- [ ] `Q0613A`を実行し、`Found C00001: ACME TRADING CO`ほかの3行が印字されることを確認できた。

## 片付け

`Q0613A`・`Q0613B`はそのまま残してください。どちらの`UPDATE`も`TOKUIM`の中身を実際には変えていません(`Q0613A`はCONCATによる無変更の書き戻し、`Q0613B`は`SQL7008`で失敗し変更されません)。`TXRESET`は不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Embedded SQL | 埋め込みSQL |
| Precompile | プリコンパイル(SQL文を実行可能な呼び出しに変換する前処理) |
| Host variable | ホスト変数(`:`を付けてSQL文の中から参照するRPG変数) |
| Commitment control | コミットメント制御 |
| Journal | ジャーナル |
| SQLSTATE | SQL状態(SQL文の実行結果を表す5文字の戻りコード) |
| Diagnostics area | 診断域(`GET DIAGNOSTICS`で読み出す詳細情報) |

次のレッスン(06-14)では、カーソルで複数行を1行ずつ読み出し、`PREPARE`と`?`マーカーによる動的SQLを扱います。

## 実機メモ

- 確認日: 2026-09-27(接続`part06-1314-sql`、2回接続)。**1回目の接続で、`GET DIAGNOSTICS`の項目名`DB2_MESSAGE_TEXT`が実機(V7R5M0)では`SQL0104`(無効なトークン)になることを発見した(V1)。** コンパイラー自身の診断メッセージが出す有効トークン一覧には`DB2_MESSAGE_ID`はあったが`DB2_MESSAGE_TEXT`は無く、接頭辞なしの`MESSAGE_TEXT`が正しいと分かった。一次資料の実例が挙げるスタイル(`DB2_MESSAGE_ID`と`DB2_MESSAGE_TEXT`を並べて使う形)とは食い違ったが、実機のコンパイラー診断が示す事実を優先し、`src/qrpglesrc/q0613s.sqlrpgle`を`MESSAGE_TEXT`に修正した。
- **2回目の接続でCONFIRMED SUCCESS(V2、接続結果の`run`セクションの生テキストで確認)**: `Q0613A`を`CRTSQLRPGI`(`COMMIT(*NONE)`明示)でコンパイル(Highest Severity 00)し`CALL`したところ、`Found C00001: ACME TRADING CO` → `Zip=1000001 Rep=T00001 Updated=20260901` → `UPDATE OK`の3行が、この順で確認できた。`SELECT INTO`・`UPDATE`とも`SQLSTATE='00000'`(成功)側の経路をたどっている。
- **`SET OPTION`から`commit = *none,`だけを取り除いた検証専用の変種(`verify/part06-1314-sql/src/q0613v.sqlrpgle`、`Q0613V`。`COMMIT()`パラメーターを指定せずコンパイル)で、`SQL7008`を実際に再現できた(V2)**: `Found C00001: ACME TRADING CO` → `Zip=1000001 Rep=T00001 Updated=20260901` → `UPDATE failed, SQLSTATE=55019` → `SQL7008` → `TOKUIM in <USER>2 not valid for operation.`の順(`SELECT INTO`は`Found`/`Zip`の2行分、`UPDATE`が残り3行分)。ジョブ・ログには原因として`CPF4328: Member TOKUIM not journaled to journal *N.`が記録されており、これで`TOKUIM`がジャーナルされていないことも確定した(P12)。`SELECT INTO`は影響を受けず成功しており、失敗するのは`UPDATE`だけだった——上の「説明」の主張どおりの結果になっている。
- **依存するプローブ`P12`・`P25`の確認範囲**: `P12`(ジャーナル)は`TOKUIM`が未journaledであること(`CPF4328`)のみ確認しており、`CRTJRN`・`STRJRNPF`・`DSPJRN`そのものの実演は行っていません。`P25`(`CRTSQLRPGI`)はメンバーからのコンパイルと、`SET OPTION`から`commit = *none,`を外す→`SQL7008`再現のみ確認しており、IFSソースからの直接コンパイル・`/COPY`・`RPGPPOPT(*LVL2)`は未検証です(それぞれのプローブが本来カバーする範囲全体ではありません)。
- **印字出力(`QSYSPRT`)は、このハーネスの非対話SSHジョブでは実スプール・ファイルにならない。** `CPYSPLF`で回収を試みても対象の物理ファイルは0件のままで(既知の制約)、上記の実行結果はすべて接続結果の`run`セクションの生テキストを読んで確認したものであり、`WRKSPLF`で確認したものではない。学習者自身が5250で`CALL`したときは、`WRKSPLF`で同じ内容を確認できるはずです(この部分はV3、未検証)。
- `CLOSQLCSR`(既定`*ENDACTGRP`・本レッスンの`*ENDMOD`)の違いそのもの(カーソル・準備済みステートメントの解放タイミング)は、`Q0613A`自身がカーソルも準備済みステートメントも持たないため、実機で観察可能な違いとしては確認していない(V1: コンパイルが通ることのみ確認)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
