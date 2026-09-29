# 08-07 IBM iサービスと権限

> 所要時間: 60分 / 前提レッスン: 08-06 / 目標番号: 6 / 観測方法: SQLの結果(`SELECT`)・ジョブ・ログ(`GRTOBJAUT`/`RVKOBJAUT`の確認メッセージ、`JOBLOG_INFO`経由)/ 道具: SQL(ACSの「実行SQLスクリプト」、CLコマンドとSQLを混在実行)/ 同時接続数: ACS×1(5250は使いません)/ 作る・変えるオブジェクト: なし(既存の`<自分のユーザー名>1/JUCSRV`の`*PUBLIC`権限を`GRTOBJAUT`→`RVKOBJAUT`で一時的に変更し、必ず元に戻す。手順1で05-07の`DSPPGMREF`を実際にもう一度実行した場合のみ、`QTEMP`に一時ファイルができます)/ DBVER: 1 / 依存するプローブ: P30(確認済み)・P42(RPG III・プロトタイプ経由の呼び出しは05-04/06-05で確認済み、SQLの`CALL QSYS2.QCMDEXC`経由は未実施のまま)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- 08-07-1: `OBJECT_STATISTICS`・`USER_STORAGE`・`OBJECT_PRIVILEGES`・`PROGRAM_INFO`という4つのIBM iサービスを、必ず自分自身の範囲にフィルターして使い、自分のライブラリー・オブジェクト・使用量を調べられる。
- 08-07-2: `GRTOBJAUT`/`RVKOBJAUT`で、「誰が」ではなく「何に対して何ができるか」という考え方に基づき、既存オブジェクトの権限を付与・取り消しできる。
- 08-07-3: `QCMDEXC`をSQLから呼び出す際のコマンド注入リスクを説明し、脆弱なコード例のどこが危ないか、どう直せばよいかを指摘できる。

## ウォームアップ

<details><summary>前回までの復習(05-07/06-05)</summary>

1. (05-07)`DSPPGMREF`の`*OUTFILE`をSQLで読むとき、`DSPPGMREF`を実行したジョブと`SELECT`を実行するジョブが同じでなければならなかったのはなぜですか?
2. (06-05・05-04)`QCMDEXC`は何をするプログラムでしたか?「任意のCLコマンドを実行できる」わけではなかったのは、どういう意味でしたか?

答え: 1. `QTEMP`はジョブ・スコープの特別なライブラリーで、そのジョブが終わると自動的に消える、そのジョブだけの作業ライブラリーだからです。別のジョブ・別の接続からは中身が見えません。 2. `QCMDEXC`はRPG(05-04はRPG III、06-05は`**FREE`)からCLコマンドを実行するプログラムです。ただし実行できるのは、各CLコマンドが持つ`ALLOW`属性(そのコマンドがどの環境から実行してよいかを定めた属性)に`QCMDEXC`のような環境が含まれているコマンドだけです。`SNDPGMMSG`は`QCMDEXC`経由では実行できず`CPD0031`になったのが実例でした。

</details>

## なぜ学ぶか

**第8部はここまで、ビルド(08-01)・自動化(08-02)・静的解析(08-03)・テスト(08-04)・リファクタリング(08-05/08-05b)・データ定義の近代化(08-06)と、「現代的な開発の道具」を積み重ねてきました。** このレッスンは、その仕上げとして**セキュリティの視点**を加えます。ここまでの全レッスンで、`<自分のユーザー名>1`の`*PUBLIC`権限がどうなっているか、自分がどれだけの記憶域を使っているか、自分のプログラムが実際にどんな権限を持っているかを、一度も直接確認したことはありませんでした。

IBM iには昔から`DSPOBJD`・`DSPPGM`・`DSPUSRPRF`・`WRKOBJ`のような、システムの状態を調べるCLコマンドが数多くあります。近年のIBM iは、この種の情報の多くを**SQLの表関数・ビュー**(`QSYS2`スキーマ配下、通称「IBM iサービス」)としても提供しています。CLコマンドの1つ1つのパラメーターを覚える代わりに、使い慣れたSQLの`WHERE`句・`JOIN`・`ORDER BY`で同じ情報を自在に絞り込める——これは、08-06が扱う予定の「DDSからSQL DDLへの近代化」と同じ、旧来の形をSQLへ置き換えていく流れの、権限・監査の領域での現れです。

ただし、この便利さには**CLコマンドには無かった新しい危険**が伴います。`DSPOBJD LIB(...)`のようなCLコマンドは、対象を指定するパラメーターを省略すればたいてい実行時エラーで止まります。ところがSQLの`SELECT * FROM QSYS2.OBJECT_PRIVILEGES`は、`WHERE`句が無くても**文法的には正しく実行でき**、システム全体(他の利用者の情報を含む)を静かに返してしまいます。PUB400のような共有機では、これは単なる行儀の問題ではなく、実際に問題を起こしうる操作です。このレッスンの中心にある学びは、便利な新しい道具(IBM iサービス)には、その道具ならではの新しい使い方の規律(自分自身にフィルターする)が伴う、という現代的な開発全体に通じる教訓です。

あわせて、05-07(影響調査)で使った`DSPPGMREF`+SQLの手法を振り返ります。`DSPOBJD`・`DSPPGM`のような対象確認コマンドの多くはこのレッスンで見るとおりSQLサービスに置き換わりつつある一方、`DSPPGMREF`(依存関係の調査)自体にはSQL単独の直接的な代替が見つかっていません——「どこまでがSQLに置き換わっていて、どこがまだ置き換わっていないか」を区別し、過大な主張をしないことも、この教材が一貫して大事にしてきた姿勢です。最後に、SQLからCLコマンドを呼ぶ`QCMDEXC`(05-04・06-05で既習)を、今度は**SQLから呼び出す際の注入リスク**という新しい角度から見直します。この視点は、次のレッスン(08-08、`<自分のユーザー名>1`から`<自分のユーザー名>2`への昇格)で権限を慎重に扱う姿勢にも直結します。

## 新出

- 中核概念(3つ):
  1. **IBM iサービスは、必ず自分自身にフィルターして使うという安全規律。** IBM iサービス(`QSYS2`配下のSQL表関数・ビュー)は、`DSPxxx`のような従来のCLコマンドが持っていた「対象を指定するパラメーター」を、SQLの`WHERE`句に置き換えたものにすぎません。パラメーターを書き忘れれば、CLコマンドなら実行時エラーで止まることが多い一方、SQLは`WHERE`句が無くても文法的には正しく実行でき、**システム全体(他の利用者の情報を含む)を静かに返してしまいます。** `docs/probes.md`が触れる2025-08の一斉ロックアウト事例(**詳しい確からしさは下の「説明」の「安全規律」節を参照してください**)は、この危険の具体例として教材内で参照されてきました。`OBJECT_PRIVILEGES`/`PROGRAM_INFO`/`USER_STORAGE`だけでなく、本レッスンで扱う`ACTIVE_JOB_INFO`・`JOBLOG_INFO`にも、**同じ規律を及ぼします**——「自分の範囲かどうか」は個々のサービスの注意点ではなく、IBM iサービス全体に共通する設計規律です。
  2. **権限は「誰が」ではなく「何に対して何ができるか」の付与という考え方。** `GRTOBJAUT`(権限付与)は、「この利用者は信頼できる・できない」という判断ではなく、「このオブジェクトに対して、この利用者(または`*PUBLIC`)は、この操作(`*USE`・`*CHANGE`等)ができる」という、**オブジェクト起点**の宣言です。`USRPRF(*OWNER)`(プログラムが所有者の権限を採用する指定)も同じ考え方の延長で、利用者個人への直接の権限は絞り込みつつ、限定された経路(コンパイル済みの特定のプログラム)だけに、より広い権限を「借りさせる」仕組みです。
  3. **`QCMDEXC`はSQLからCLコマンドを呼ぶ経路であり、そのSQLを検証していない入力と組み立てると注入のリスクがある。** `QCMDEXC`自体は05-04(RPG III)・06-05(`**FREE`)で既に扱った技術で、ここでは復習です(新出には数えません)。**新出はこのリスクの説明そのものです**——CLコマンド文字列を、検証していない外部入力とそのまま連結して組み立てると、入力側の値が引用符やコマンドの構造そのものを書き換えてしまう恐れがあります。データベースの世界でよく知られる「SQLインジェクション」と、まったく同じ形の脆弱性です。

- 構文(6つ、上限いっぱい):
  1. `JOBLOG_INFO('*')`(自分のジョブのジョブ・ログをSQLで読む)。
  2. `OBJECT_STATISTICS('<自分のユーザー名>1','*ALL')`(自分のライブラリーの中身をSQLで一覧する。**学習者にとっては正真正銘の新出です**——著者はP01〔01-04の元になった実機確認〕で既にこの形を実行・確認済みですが、この教材のどのレッスン本文もこれまで学習者にこのSQLを教えたことはありません)。
  3. `OBJECT_PRIVILEGES`(自分の範囲、`OBJECT_SCHEMA`でフィルターする)。
  4. `PROGRAM_INFO`(自分の範囲、`PROGRAM_LIBRARY`でフィルターする)。
  5. `USER_STORAGE`(`WHERE AUTHORIZATION_NAME = CURRENT_USER`)。
  6. `GRTOBJAUT`/`RVKOBJAUT`(権限の付与・取り消し)。

**読解用(新出に数えない)**:

- `ACTIVE_JOB_INFO`: `WRKACTJOB`のSQL代替として一言だけ紹介します。深追いはしません(下の「説明」参照)。
- `WRKACTJOB`(01-08・03-12の復習): 他人のジョブを走査しないという規律を、ここでも再確認します。
- `USRPRF(*OWNER)`: 権限を「誰が」ではなく「何に対して何ができるか」で考える、同じ発想の応用です。**このレッスンでは新規オブジェクトを作らないため、実際にコンパイルして試すことはしません**(下の「説明」参照)。構文と考え方だけを扱う読解用の項目です。
- `REPLACE(...)`(SQLのスカラー関数)・`CHGOBJD`(CLコマンド): 演習(c)の脆弱なコード例に登場しますが、どちらもこのレッスンで初めて名前を挙げる構文です。`REPLACE(...)`は文字列中の一致部分を置き換えるという一般的な用途で読めれば十分です。`CHGOBJD`はこの教材の一次資料にパラメーターの完全な一覧が無く、演習内での挙動の一般知識としての正確さは要確認として扱ってください。

**既習の応用(新出に数えない)**:

- `QCMDEXC`(05-04・06-05)。プログラムそのものは復習で、新出はリスクの説明だけです。
- `DSPPGMREF`の`*OUTFILE`をSQLで読む手順、`QTEMP`のジョブ・スコープ(05-07)。

## 説明

### IBM iサービスとは: `DSPxxx`からSQLへ

`QSYS2`スキーマの下には、システムの状態を返す**表関数**(`TABLE(QSYS2.関数名(引数))`という形で`FROM`句に書く)と**ビュー**(ふつうの表のように`FROM QSYS2.ビュー名`と書く)が数多く用意されています。これらは通称「IBM iサービス」と呼ばれ、多くは`DSPOBJD`・`DSPPGM`・`DSPUSRPRF`のような既存のCLコマンドが持っていた情報を、SQLの`SELECT`文として引き出せるようにしたものです。CLコマンドの出力は原則として画面かスプールですが、SQLならその場で`WHERE`・`JOIN`・`ORDER BY`を使って絞り込めます。

### 安全規律: 必ず自分自身にフィルターする

CLコマンドの多くは、対象を指定するパラメーター(`LIB`・`PGM`等)を省略すると、`*LIBL`や実行時のエラーによって、少なくとも「無制限に何でも返す」ことにはなりにくい作りです。ところがSQLの`SELECT`文は、`WHERE`句を書き忘れても**文法的には完全に正しいまま実行でき**、対象の表・ビューが返せる全行(システム上の全利用者・全ライブラリーの情報)をそのまま返してしまいます。

`docs/probes.md`は、2025-08に起きたとされる一斉ロックアウト事例に1行だけ触れています。

> `QSYS2.USER_STORAGE`は`WHERE AUTHORIZATION_NAME = CURRENT_USER`で自分自身に絞って使うこと。フィルターなしで実行すると他ユーザーの情報も返るため、2025-08の一斉ロックアウト事例に鑑み、絶対に行わない。

**正直に書きます。** この事例についてこの教材が持っている記録は、この1行だけです。何が原因で、どういう経緯でロックアウトが起きたのか、誰にどんな実害があったのかを裏付ける詳しい記録は、この教材のどこにもありません。実害を否定するつもりはありませんが、実機で確かめた事実というよりは、**伝聞に基づく警戒**に近いものとして扱ってください。それでも、「`WHERE`句を忘れても文法エラーにならない」という上の性質自体は、この教材が既に05-07で確認した一般原則(`DSPPGMREF`・`DSPDBR`はライブラリーを指定して実行するのが原則)をSQLの領域に広げただけの、疑う余地のない事実です。この規律は、`OBJECT_PRIVILEGES`・`PROGRAM_INFO`・`USER_STORAGE`だけでなく、下で扱う`ACTIVE_JOB_INFO`・`JOBLOG_INFO`にも等しく及ぼしてください。

### 自分のライブラリーを見る: `OBJECT_STATISTICS`

```sql
SELECT OBJNAME, OBJTYPE, OBJOWNER
  FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>1','*ALL')) X
 ORDER BY OBJNAME FETCH FIRST 10 ROWS ONLY;
```

第1引数がライブラリー名、第2引数がオブジェクト型のフィルター(`*ALL`はすべての型)です。**必ずライブラリー名を自分の`<自分のユーザー名>1`(または`2`・`B`)にしてください**——`*ALLUSR`のような広い指定は、上の安全規律に反します。このSQLは、著者がP01(2026-09-24)で自分の3ライブラリーに対して既に実行・確認済みであるのに加え、本レッスン専用の検証接続(`part08-07-services`、2026-09-29、下の「実機メモ」参照)でも改めてこの形のまま成功しています。

### 自分の使用量を見る: `USER_STORAGE`

```sql
SELECT AUTHORIZATION_NAME, STORAGE_USED, MAXIMUM_STORAGE_ALLOWED
  FROM QSYS2.USER_STORAGE
 WHERE AUTHORIZATION_NAME = CURRENT_USER;
```

`WHERE AUTHORIZATION_NAME = CURRENT_USER`を**省略しないでください**。省略すると、システムに登録された全利用者の記憶域使用量が返ってしまいます。このSQLも、著者がP01で自分の実際の使用量(使用量79,568 KB/上限1,000,000 KB)を確認済みであるのに加え、本レッスン専用の接続でも改めて成功しています。

### 自分のオブジェクトの権限を見る: `OBJECT_PRIVILEGES`

```sql
SELECT OBJECT_SCHEMA, OBJECT_NAME, OBJECT_TYPE, AUTHORIZATION_NAME, OBJECT_AUTHORITY
  FROM QSYS2.OBJECT_PRIVILEGES
 WHERE OBJECT_SCHEMA = '<自分のユーザー名>1' AND OBJECT_NAME = 'JUCSRV';
```

`OBJECT_SCHEMA`(ライブラリー名に相当)を必ず自分のライブラリーに絞ってください。08-01で作り直した`<自分のユーザー名>1/JUCSRV`(*MODULE・*SRVPGM)に対して実際にこのSQLを実行すると、次の形の結果が返ります(実機確認済み、下の「実機メモ」参照)。

| OBJECT_SCHEMA | OBJECT_NAME | OBJECT_TYPE | AUTHORIZATION_NAME | OBJECT_AUTHORITY |
|---|---|---|---|---|
| `<自分のユーザー名>1` | `JUCSRV` | `*MODULE` | `*PUBLIC` | `*EXCLUDE` |
| `<自分のユーザー名>1` | `JUCSRV` | `*MODULE` | (所有者) | `*ALL` |
| `<自分のユーザー名>1` | `JUCSRV` | `*SRVPGM` | `*PUBLIC` | `*EXCLUDE` |
| `<自分のユーザー名>1` | `JUCSRV` | `*SRVPGM` | (所有者) | `*ALL` |

`*MODULE`と`*SRVPGM`は、同じ`JUCSRV`という名前を持ちますが、権限上は**別々のオブジェクト**として扱われます。`*PUBLIC = *EXCLUDE`は「特に権限を与えられていない利用者は、このオブジェクトを一切使えない」という既定の状態です。所有者だけが`*ALL`(すべての操作)を持っています。

### 自分のプログラムを見る: `PROGRAM_INFO`

```sql
SELECT PROGRAM_LIBRARY, PROGRAM_NAME, PROGRAM_TYPE, PROGRAM_OWNER
  FROM QSYS2.PROGRAM_INFO
 WHERE PROGRAM_LIBRARY = '<自分のユーザー名>1' FETCH FIRST 10 ROWS ONLY;
```

`PROGRAM_LIBRARY`を必ず自分のライブラリーに絞ってください。`PROGRAM_TYPE`列は、`OPM`(RPG III・CL等の旧来のプログラム・モデル)と`ILE`(RPG IV・ILE CL等)を正しく区別して返すことが実機で確認済みです——07-01以降で作ってきたILEのプログラムと、第3〜5部で作ったOPMのプログラムが、このSQL一発で見分けられます。

### 自分のジョブ・ログをSQLで見る: `JOBLOG_INFO`

```sql
SELECT ORDINAL_POSITION, MESSAGE_TEXT
  FROM TABLE(QSYS2.JOBLOG_INFO('*')) X
 ORDER BY ORDINAL_POSITION DESC
 FETCH FIRST 10 ROWS ONLY;
```

`'*'`は現在の自分のジョブを指すと一般に説明されますが、**この一次資料(`rbafy75.txt`)自体にはパラメーターの意味を説明する記載が無く**、この点は一般知識・要確認として扱ってください。`FROM TABLE(QSYS2.JOBLOG_INFO('*')) X`という構文そのものと`ORDINAL_POSITION`という列名は、`rbafy75.txt`(19105-19152行目、監視プロシージャーの実例)に実際の使用例があります(ただしこの実例自体、未定義の相関名を`ORDER BY`で使うという一次資料側の誤りを含んでいます)。**`MESSAGE_TEXT`という列名は、この一次資料の同じ範囲には一度も出現しません**——この列名の裏付けは、この教材自身の検証ハーネス(`verify/lib/clgen.mjs`)が実際に使っている`SELECT ORDINAL_POSITION, SUBSTR(MESSAGE_TEXT, 1, 200) FROM TABLE(QSYS2.JOBLOG_INFO('*')) X`という形です。この検証ハーネスの形は、ほぼすべての実機接続のログ回収に使われ続けており(下の「実機メモ」参照)、`FROM TABLE(QSYS2.JOBLOG_INFO('*')) X`という表関数の呼び出し方と`ORDINAL_POSITION`・`MESSAGE_TEXT`という列名の存在は、V2(実行結果の一致まで確認済み)として扱ってよいものです。**ただし、この本文が示す`WHERE`・`ORDER BY`・`FETCH FIRST`を伴う具体的なSQL文そのものは、検証ハーネスの形とは`SELECT`リスト・`WHERE`・`ORDER BY`のいずれも一致しておらず、個別に実機確認されたものではありません。** `DSPJOBLOG`を5250の画面で目視する代わりに、`MESSAGE_TEXT LIKE '%文字列%'`のような条件でジョブ・ログを検索できます。

### 読み物: `ACTIVE_JOB_INFO`と`WRKACTJOB`の規律

`WRKACTJOB`(01-08・03-12で既習)は、システム上の実行中ジョブを一覧するCLコマンドです。`ACTIVE_JOB_INFO`は、その情報をSQLの表関数として提供するIBM iサービスです。**このレッスンでは深追いしません。** 一次資料(`rbafy75.txt`8586-8592行目)には、次のような実働例があります。

```sql
SELECT JOB_NAME, AUTHORIZATION_NAME
  FROM REMOTE TABLE (REMOTESYS.QSYS2.ACTIVE_JOB_INFO(DETAILED_INFO => 'WORK'))
 WHERE JOB_ACTIVE_TIME < CURRENT TIMESTAMP - 20 MINUTES;
```

**このSQLは、そのままこの教材の環境で試さないでください。** `REMOTE TABLE`は、複数のIBM iシステムにまたがる分散照会のための構文であり、この教材はPUB400という単一システムだけを対象にしています。ここでは「`WRKACTJOB`に相当する情報が、SQL側にも存在する」という事実と、一次資料に実際にこの形の例がある、ということだけを読み物として知っておいてください。**この一次資料の例自体には、自分自身に絞る`WHERE`条件が入っていません**(`JOB_ACTIVE_TIME`による時間の条件だけで、利用者を絞る条件はありません)。上の安全規律(自分自身にフィルターする)は`ACTIVE_JOB_INFO`にも等しく及ぶため、実際にこの種のSQLを使う場合は、自分自身の利用者名で絞る条件を必ず加えてください。

`WRKACTJOB`・`ACTIVE_JOB_INFO`のどちらを使う場合も、`docs/style-guide.md`が既に定めている規律——**他人のジョブを走査しない**(`*ALLUSR`を対象にした汎用検索のようなことを行わない)——がそのまま当てはまります。上の安全規律(自分自身にフィルターする)の、ジョブに対する現れです。

### 権限は「誰が」ではなく「何に対して何ができるか」: `GRTOBJAUT`/`RVKOBJAUT`と`USRPRF(*OWNER)`

`GRTOBJAUT`(Grant Object Authority)は、指定したオブジェクトに対し、指定した利用者(または`*PUBLIC`)に、指定した権限(`*USE`・`*CHANGE`・`*ALL`等)を与えるコマンドです。**「この人は信用できるから」という判断ではなく、「このオブジェクトに対して、この操作までを許す」というオブジェクト起点の宣言**である点が要です。取り消しは対になる`RVKOBJAUT`(Revoke Object Authority)で行います。

```text
GRTOBJAUT OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(*SRVPGM) USER(*PUBLIC) AUT(*USE)
RVKOBJAUT OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(*SRVPGM) USER(*PUBLIC) AUT(*USE)
```

一次資料(`cl_commands_75.txt`6519-6522行目)は、あるプログラムのAUT(権限)パラメーターの説明の中で、次のように述べています。

> The authority can be altered for all or for specified users after the program is created with the CL commands Grant Object Authority (GRTOBJAUT) or Revoke Object Authority (RVKOBJAUT).
> (この権限は、プログラムが作成されたあと、GRTOBJAUT・RVKOBJAUTというCLコマンドで、全利用者または指定した利用者について変更できる。)

**`GRTOBJAUT`・`RVKOBJAUT`のどちらも、この一次資料には独立したパラメーター表の節がありません。** `OBJ`/`OBJTYPE`/`USER`/`AUT`という引数の形は、上の言及と、実機での確認結果(下の「実機メモ」参照)から確認したものです。**ただし実機で実際にこの形のまま成功したのは、2回の接続のうち2回目だけです**——1回目の接続は`REVOKE`という誤記のためラッパー自体のコンパイルが失敗し、`GRTOBJAUT`はまだ一度も実行されていませんでした(下の「見つかった実機の落とし穴」参照)。

**`USRPRF(*OWNER)`は、同じ考え方をプログラム単位で実現する仕組みです。** `CRTBNDRPG`等のプログラム作成コマンドが持つ`USRPRF`パラメーターについて、一次資料(`cl_commands_75.txt`6509-6513行目)は次のように説明しています。

> `*OWNER`: The program runs under the user profile of both the program's user and owner. The collective set of object authority in both user profiles are used to find and access objects while the program is running.
> (`*OWNER`: プログラムは、プログラムの利用者と所有者の両方のユーザー・プロファイルの下で実行される。プログラムの実行中にオブジェクトを探し、アクセスする際には、この2つのユーザー・プロファイルが持つオブジェクト権限をあわせたものが使われる。)

つまり、ある利用者に対象オブジェクトへの直接の権限を一切与えなくても、**`USRPRF(*OWNER)`で作られた、より強い権限を持つ所有者のプログラム経由でだけ**、その操作をさせることができます。これも「利用者を信用するかどうか」ではなく、「どの経路(プログラム)を通ればその操作ができるか」という、オブジェクト・プログラム起点の設計です。**このレッスンでは新規オブジェクトを作らないため、`USRPRF(*OWNER)`を実際にコンパイルして試すことはしません。** ここでは構文と考え方だけを扱います。

### 見つかった実機の落とし穴: `REVOKE`はCLコマンドではない

このレッスンの実機検証で、著者自身が実際に踏んだ間違いです。`GRTOBJAUT`の対語のつもりで`REVOKE`というコマンドを書いたところ、次のメッセージでラッパー・プログラムのコンパイル自体が失敗しました。

```text
CPD0030: Command REVOKE in library *LIBL not found.
```

| メッセージ | 原因 | 対処 |
|---|---|---|
| `CPD0030` | `REVOKE`はSQL文(`REVOKE ... FROM ...`)のキーワードであり、CLコマンドとしては存在しない | `GRTOBJAUT`に対応するCLコマンドは`RVKOBJAUT`(Revoke Object Authority)を使う |

**`REVOKE`はSQLの世界の予約語であり、CLコマンドの世界には同じ綴りのコマンドがありません。** この教材はここまで、SQLとCLを行き来する場面(05-07のACS「実行SQLスクリプト」等)を何度も扱ってきましたが、「同じ操作でも、SQL側とCL側でコマンド名が違う」という具体例として覚えておいてください。この失敗と修正の経緯自体は、下の「実機メモ」に詳しく記録してあります。**なお、この失敗はこの教材の検証ハーネスが生成した独立のCLプログラムのコンパイルとして起きたものであり、上の実演(`CL:`プレフィックス経由でACSの「実行SQLスクリプト」内から実行する形)そのものでこのエラーを確認したわけではありません。挙動自体は同じはずですが、厳密には別の実行経路です。**

### `QCMDEXC`をSQLから呼ぶ: コマンド注入のリスク

`QCMDEXC`は、SQLからも同じ形で呼び出せます。一次資料(`rbafy75.txt`20911-20933行目)には、実際に次のような例があります(Javaのトラスト・ストアを作成する手順の一部です)。

```sql
-- Step 1. Use QCMDEXC and QSH and mkdir to create a directory
CALL QSYS2.QCMDEXC('QSH CMD(''mkdir ' CONCAT NEW_TRUST_DIRECTORY CONCAT ''')');
```

この例自体は、`NEW_TRUST_DIRECTORY`をこの少し前で`SET`文により固定の文字列から組み立てているため、危険はありません。**しかし、まったく同じ「文字列をそのまま`CONCAT`で連結する」という形は、`NEW_TRUST_DIRECTORY`に相当する値が、検証していない外部からの入力(利用者が入力した値、他の表から読んだ値等)だったとたんに危険になります。** 例えばその値に単一引用符(`'`)が1つ含まれていれば、その引用符がCLコマンド文字列の引用符を早期に閉じてしまい、それ以降の文字列が**データではなくCLコマンドの構文そのもの**として解釈されてしまいます。これは、データベースの世界でよく知られる「SQLインジェクション」(検証していない入力がSQL文の構造を書き換えてしまう脆弱性)と、まったく同じ形の問題です。**`CALL QSYS2.QCMDEXC(...)`というSQLからの呼び出し経路自体は、この一次資料に実例がありますが、この教材の検証ハーネスでは実機で実行確認していません**(下の「実機メモ」参照)。下の「演習」では、この危険を**実機で実際に動かすのではなく、静的なコードの読解として**扱います。

**この種の危険を避ける基本的な対策は3つあります。**

- **許可リスト方式**: 値の種類が有限な入力(オブジェクト型、操作の種類等)は、あらかじめ決めた許可リストとの完全一致でのみ受け入れる。
- **値の検証**: 自由入力は、CLコマンド文字列へ渡す前に、文字種・長さを厳密に検証する(想定外の文字が1つでもあれば実行を拒否する)。
- **そもそもCLコマンド文字列を動的に組み立てない設計**: 可能な限り、実行する操作を少数の固定コマンド・テンプレートに限定し、検証済みの値だけをそこへ差し込む。あるいは、目的の操作を行う専用のAPI・サービスが別にあれば、`QCMDEXC`を経由せずそちらを直接呼ぶことを検討する。

下の「演習」では、この3つの対策を実際のコード例に当てはめて考えます。

### 限界の明記: 拒否効果そのものは実演できない

`GRTOBJAUT`/`USRPRF(*OWNER)`が実際に権限を**拒否する**効果(たとえば`*PUBLIC`を`*EXCLUDE`にした状態で、別の利用者が本当にそのオブジェクトを使えなくなること)は、**このレッスンでは実演しません。** PUB400のアカウントは1人1アカウントであり(P01実測、自分名義の3ライブラリー以外を試す手段がありません)、拒否される側の「もう1人の利用者」を用意できないためです。本文・実演で確認できるのは、あくまで**文法**(`GRTOBJAUT`/`RVKOBJAUT`が実際にエラーなく実行でき、その往復の前後で`OBJECT_PRIVILEGES`が同じ状態〔`*PUBLIC` = `*EXCLUDE`〕に戻ることの**自己確認**)までです。**権限が往復の途中で実際に`*USE`へ変わったこと自体は、`OBJECT_PRIVILEGES`を往復の途中で読んで確かめたのではなく、ジョブ・ログの`CPI2201`(付与)/`CPI2202`(取り消し)という確認メッセージから確認しています。**拒否そのものの効果を確かめたい場合は、複数の利用者プロファイルを持つ環境(勤務先の開発機等)で試してください。

## 実演

**この実演で使う`OBJECT_STATISTICS`・`USER_STORAGE`・`OBJECT_PRIVILEGES`・`PROGRAM_INFO`・`GRTOBJAUT`/`RVKOBJAUT`は、すべて実機(`part08-07-services`、2026-09-29、2回の接続)でCONFIRMED SUCCESSまで確認済みです。** ACSの「実行SQLスクリプト」を開き、05-07と同じ要領で、CLコマンド(`CL:`)とSQLを1つのスクリプトの中に混在させて進めます。

1. **05-07の技法を振り返る(変わっていない部分)。** 05-07で行った`DSPPGMREF PGM(<自分のユーザー名>1/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)`+SQLの手順は、このレッスンでも変わっていません。`DSPPGMREF`のSQL単独での完全な代替(依存関係を直接返すIBM iサービス)は、この教材の一次資料には見つかりませんでした。**この部分の列名・挙動は、05-07自身がまだ実機で確認しきれていない内容のままです(依存するプローブP18は今も未実施です)。** ここでは、この技法が今も現役であることだけを確認し、深追いはしません(必要なら05-07の手順をそのままもう一度実行してください)。

2. 自分のライブラリーの中身を、純粋なIBM iサービスで一覧します。

   ```sql
   SELECT OBJNAME, OBJTYPE, OBJOWNER
     FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>1','*ALL')) X
    ORDER BY OBJNAME FETCH FIRST 10 ROWS ONLY;
   ```

   自分のライブラリーの中身のうち、名前順で先頭の10件が一覧されます。**`FETCH FIRST 10 ROWS ONLY`を付けているため、ライブラリーの中身が11件以上あり、かつ`JUCSRV`が名前順で11番目以降になる場合は、この一覧に`JUCSRV`自身は含まれません**(実機確認済み、下の「実機メモ」参照)。`JUCSRV`自身を確認したい場合は、`WHERE OBJNAME = 'JUCSRV'`を付けるか、`FETCH FIRST`を外して結果全体を見てください。

3. 自分の記憶域の使用量を確認します。

   ```sql
   SELECT AUTHORIZATION_NAME, STORAGE_USED, MAXIMUM_STORAGE_ALLOWED
     FROM QSYS2.USER_STORAGE
    WHERE AUTHORIZATION_NAME = CURRENT_USER;
   ```

4. `JUCSRV`の現在の権限を確認します(往復の**前**、基準の状態です)。

   ```sql
   SELECT OBJECT_SCHEMA, OBJECT_NAME, OBJECT_TYPE, AUTHORIZATION_NAME, OBJECT_AUTHORITY
     FROM QSYS2.OBJECT_PRIVILEGES
    WHERE OBJECT_SCHEMA = '<自分のユーザー名>1' AND OBJECT_NAME = 'JUCSRV';
   ```

   `*MODULE`・`*SRVPGM`のどちらも、`*PUBLIC` = `*EXCLUDE`(誰にも特別な権限を与えていない既定の状態)になっているはずです。**`*SRVPGM`の`*PUBLIC`が`*EXCLUDE`であることを確認してから、次の手順6へ進んでください**——手順6の往復(`GRTOBJAUT AUT(*USE)`→`RVKOBJAUT AUT(*USE)`)は、この`*EXCLUDE`という開始状態を前提にしています。開始状態が`*EXCLUDE`でない場合、往復後も元の状態には戻りません(下の「実機メモ」参照)。

5. 自分のライブラリーのプログラム一覧を確認します。

   ```sql
   SELECT PROGRAM_LIBRARY, PROGRAM_NAME, PROGRAM_TYPE, PROGRAM_OWNER
     FROM QSYS2.PROGRAM_INFO
    WHERE PROGRAM_LIBRARY = '<自分のユーザー名>1' FETCH FIRST 10 ROWS ONLY;
   ```

6. **`JUCSRV`(*SRVPGM)の`*PUBLIC`権限を、`GRTOBJAUT`で一時的に`*USE`へ変更し、`RVKOBJAUT`ですぐに元へ戻します。** 権限が変わっている時間をできるだけ短くするため、間に他の処理を挟まず、続けて実行してください。

   ```text
   GRTOBJAUT OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(*SRVPGM) USER(*PUBLIC) AUT(*USE)
   RVKOBJAUT OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(*SRVPGM) USER(*PUBLIC) AUT(*USE)
   ```

   **`REVOKE`と書かないよう注意してください**——上の「説明」で見たとおり、`REVOKE`はCLコマンドとしては存在せず`CPD0030`になります。

7. 往復が実際に起きたことを、`JOBLOG_INFO`で確認します。

   ```sql
   SELECT ORDINAL_POSITION, MESSAGE_TEXT
     FROM TABLE(QSYS2.JOBLOG_INFO('*')) X
    WHERE MESSAGE_TEXT LIKE '%JUCSRV%'
    ORDER BY ORDINAL_POSITION;
   ```

   「Authority given to user *PUBLIC for object JUCSRV ...」「Authority revoked from user *PUBLIC for object JUCSRV ...」という対のメッセージが見つかるはずです(実機確認済み、下の「実機メモ」参照)。

8. 手順4と同じSQLをもう一度実行し、`*PUBLIC`が`*EXCLUDE`(手順4と同じ、元の状態)に戻っていることを確認してください。

## 演習

**脆弱なコード3つ。** 次の3つは、いずれも`QCMDEXC`へ検証していない入力を連結して渡す、SQLからのコマンド注入パターンです。**実際にこれらを実機で実行しないでください**——ここでは静的なコード読解として、「どこが危ないか」「どう直すか」を考えます。

### (a) 素朴な連結(短い識別子)

```sql
-- 得意先コード(6文字のはず)を、そのままCLコマンド文字列へ連結する
SET CMD = 'CHGDTAARA DTAARA(*LDA (1 6)) VALUE(''' CONCAT CUSTCODE CONCAT ''')';
CALL QSYS2.QCMDEXC(CMD);
```

<details><summary>どこが危ないか</summary>

`CUSTCODE`は「6文字の得意先コード」のはずですが、それを**保証する検証がどこにもありません**。「短い識別子だから安全だろう」という思い込み自体が危険です。もし単一引用符を1つでも含む値(あるいは想定より長い値)が渡されれば、`VALUE('')`の引用符の境界が壊れ、以降の文字列がCLコマンドの構文として解釈されてしまいます。

**直し方**: 実在する得意先コードの一覧(許可リスト)と照合してから使うか、少なくとも文字種(英数字のみ)・長さ(ちょうど6文字)を、コマンド文字列を組み立てる前に厳密に検証します。

</details>

### (b) 自由入力をそのまま埋め込む

```sql
-- 利用者が自由に入力したメモを、そのままCLコマンドの引数へ埋め込む
SET CMD = 'CHGOBJD OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(*SRVPGM) TEXT(''' CONCAT NOTE CONCAT ''')';
CALL QSYS2.QCMDEXC(CMD);
```

<details><summary>どこが危ないか</summary>

`NOTE`は自由記述のメモを想定しているため、(a)のような「短い識別子だから」という言い訳すら使えません。**悪意が無くても**、利用者が普通の文章(例えば`Don't ship yet`のような、アポストロフィを含む英文)を入力しただけで、単一引用符が`TEXT('')`の境界を壊し、以降がCLコマンドの構文として解釈されます。(a)よりも危険度が高い版です。

**直し方**: 値をCLコマンド文字列へ埋め込む前に、単一引用符を正しく複製(`''`にエスケープ)します。ただし、(c)が示すとおり、エスケープだけでは不十分な場合があることに注意してください。

</details>

### (c) 一見サニタイズしているが不十分な版

```sql
-- メモ欄の単一引用符は正しく複製(エスケープ)しているが...
SET SAFE_NOTE = REPLACE(NOTE, '''', '''''');
SET CMD = 'CHGOBJD OBJ(<自分のユーザー名>1/JUCSRV) OBJTYPE(' CONCAT OBJTYPE_INPUT CONCAT
          ') TEXT(''' CONCAT SAFE_NOTE CONCAT ''')';
CALL QSYS2.QCMDEXC(CMD);
```

<details><summary>どこが危ないか</summary>

`SAFE_NOTE`の単一引用符のエスケープ自体は正しく書けています。**しかし、この修正は`NOTE`だけにしか効いていません。** `OBJTYPE_INPUT`(本来は`*SRVPGM`・`*MODULE`のような、CLの特殊値のつもりの入力)は、CLコマンドの中では**引用符で囲まずに**書く値であるため、そもそも「引用符をエスケープする」という対策の対象にすらなっていません。`OBJTYPE_INPUT`に閉じ括弧`)`を含む値(例えば`*SRVPGM) TEXT('' OBJTYPE(*PGM`のような文字列)が渡されれば、その閉じ括弧から先がそのままCLコマンドの続きとして解釈され、書き手が意図していないパラメーターやキーワードが追加されてしまいます。**`CHGOBJD`自体が実際にどんなパラメーター・キーワードを受け付けるかは、この教材の一次資料に完全なパラメーター表が無く未確認です——ここで大事なのは特定のコマンドで何が起きるかではなく、「引用符で囲まれない位置の値は、括弧を含んでいるだけでコマンドの構造そのものを書き換えられる」という一般的な脆弱性の形です。** **「どこかをエスケープした」という安心感が、別の場所の無防備さを見えにくくしている**、典型的な落とし穴です。

**直し方**: 引用符のエスケープは、その値が実際に引用符の中に置かれる場合にしか意味がありません。`OBJTYPE_INPUT`のように**値の種類が有限**な入力は、あらかじめ決めた許可リスト(`*SRVPGM`・`*MODULE`など)と完全一致するかどうかで検証し、一致しなければ実行そのものを拒否します。

</details>

**安全な対処(まとめ、上の「説明」で扱った3つの対策の再確認)**:

- **許可リスト方式**: 値の種類が有限な入力(オブジェクト型、操作の種類等)は、あらかじめ決めた許可リストとの完全一致でのみ受け入れる。
- **値の検証**: 自由入力は、CLコマンド文字列へ渡す前に、文字種・長さを厳密に検証する(想定外の文字が1つでもあれば実行を拒否する)。
- **そもそもCLコマンド文字列を動的に組み立てない設計**: 可能な限り、実行する操作を少数の固定コマンド・テンプレートに限定し、検証済みの値だけをそこへ差し込む。あるいは、目的の操作を行う専用のAPI・サービスが別にあれば、`QCMDEXC`を経由せずそちらを直接呼ぶことを検討する。

## セルフチェック

- [ ] IBM iサービスを使うとき、なぜ必ず自分自身にフィルターしなければならないかを説明できる(2025-08の事例がどの程度の確からしさの根拠かも含めて)。
- [ ] `OBJECT_STATISTICS`・`USER_STORAGE`・`OBJECT_PRIVILEGES`・`PROGRAM_INFO`を、自分のライブラリー・自分のオブジェクトに絞って実行できた。
- [ ] `JOBLOG_INFO('*')`で自分のジョブ・ログをSQLで読めた。
- [ ] 権限が「誰が」ではなく「何に対して何ができるか」の付与であることを、`GRTOBJAUT`/`USRPRF(*OWNER)`を例に説明できる。
- [ ] `GRTOBJAUT`→`RVKOBJAUT`の往復を実行し、`OBJECT_PRIVILEGES`の結果が変化前と同じ状態(`*PUBLIC` = `*EXCLUDE`)に戻ることを確認した。
- [ ] `REVOKE`がCLコマンドとして存在しない理由と、正しいコマンド(`RVKOBJAUT`)を説明できる。
- [ ] `QCMDEXC`(復習)をSQLから呼び出す際に、なぜコマンド注入が起きうるかを説明できる。
- [ ] 脆弱なコード例(a)〜(c)それぞれについて、どこが危ないか、どう直すかを自分の言葉で説明できる。
- [ ] `GRTOBJAUT`/`USRPRF(*OWNER)`の拒否効果そのものは、この環境(PUB400、1人1アカウント)では実演できないことを理解している。
- [ ] `ACTIVE_JOB_INFO`・`WRKACTJOB`のどちらを使う場合も、他人のジョブを走査しないという規律を再確認した。

## 片付け

**このレッスンでは新規オブジェクトを作っていません。** `<自分のユーザー名>1/JUCSRV`の`*PUBLIC`権限は、実演の手順6〜8で`GRTOBJAUT`→`RVKOBJAUT`により既に元の状態(`*EXCLUDE`)へ戻っていることを確認済みです。手順1で05-07の`DSPPGMREF`をもう一度実行した場合、`QTEMP`にできる一時ファイルは、ジョブが終われば自動的に消えます(手順1自体は任意の振り返りであり、必須ではありません)。演習の3つのコード例は静的な読解にとどめており、コンパイル・実行はしていないため、後片付けの対象になるオブジェクトはありません。

## まとめ

| 英語 | 日本語 |
|---|---|
| IBM i Services | IBM iサービス(`QSYS2`配下のSQL表関数・ビュー) |
| Object authority | オブジェクト権限(オブジェクトに対して何ができるかという権限) |
| Adopted authority | 採用権限(`USRPRF(*OWNER)`、プログラムが所有者の権限を借りて実行される仕組み) |
| Command injection | コマンド注入(検証していない入力がコマンドの構文そのものを書き換える脆弱性) |
| Allowlist | 許可リスト方式(あらかじめ許可した値だけを受け入れる検証方法) |

次のレッスン(08-08、チェックポイント)では、`<自分のユーザー名>1`から`<自分のユーザー名>2`への昇格を実際に最後まで通します。このレッスンで学んだ「自分自身にフィルターする」「権限は何に対して何ができるかで考える」という姿勢が、そこでも生きてきます。

## 実機メモ

- **確認日: 2026-09-29。接続`part08-07-services`(2回の接続)。** 1回目の接続で、`collect`型ステップの4本のSELECT文(`OBJECT_STATISTICS`・`USER_STORAGE`・`OBJECT_PRIVILEGES`・`PROGRAM_INFO`)はすべて初回で成功しました。`OBJECT_STATISTICS`・`USER_STORAGE`はP01で既に確認済みの形をそのまま`&LIB`(実際に接続したライブラリー。下記のとおり`<USER>2`)に対して再確認したものです。`OBJECT_PRIVILEGES`・`PROGRAM_INFO`は、一次資料に列定義の記載が一切無い状態からの最初の推測でしたが、どちらも一発で成功しました——`OBJECT_PRIVILEGES`は`OBJECT_SCHEMA`/`OBJECT_NAME`/`OBJECT_TYPE`/`AUTHORIZATION_NAME`/`OBJECT_AUTHORITY`という列で、`JUCSRV`の`*MODULE`・`*SRVPGM`それぞれについて`*PUBLIC`=`*EXCLUDE`・所有者=`*ALL`という行を返しました。`PROGRAM_INFO`は`PROGRAM_LIBRARY`/`PROGRAM_NAME`/`PROGRAM_TYPE`(`OPM`/`ILE`の区別を正しく返す)/`PROGRAM_OWNER`という列で、対象ライブラリー内のプログラム一覧を返しました。
- **1回目の接続で見つかった実バグ: `REVOKE`はCLコマンドとして存在しない。** `GRTSELF`ステップ(`GRTOBJAUT`+`REVOKE`)自体のラッパーがコンパイルに失敗しました(`CPD0030`、severity 30、「Command REVOKE in library *LIBL not found.」)。原因は単純な思い違いで、`REVOKE`はSQL文のキーワードであり、CLコマンドとしては存在しません。`GRTOBJAUT`(権限付与)に対応するCLコマンドは`RVKOBJAUT`(Revoke Object Authority)です(`cl_commands_75.txt`6522行目で`GRTOBJAUT`の対語として言及されていますが、`GRTOBJAUT`/`RVKOBJAUT`ともこの一次資料には独立したパラメーター表の節が無く、`OBJ`/`OBJTYPE`/`USER`/`AUT`という引数の形自体は`GRTOBJAUT`の確認済みの形からの類推でした)。ラッパー自体がコンパイルできなかったため、`GRTOBJAUT`も一度も実行されておらず、この1回目の接続の`OBJECT_PRIVILEGES`の結果(`*PUBLIC`=`*EXCLUDE`)は「付与→取り消しの往復をした結果」ではなく「一度も触っていない元の状態」でした。`REVOKE`→`RVKOBJAUT`に修正し、2回目の接続で再検証しました。
- **2回目の接続でCONFIRMED SUCCESS。** `RVKOBJAUT`修正を反映した2回目の接続で、`GRTOBJAUT`→`RVKOBJAUT`の往復が実際に成功しました。ジョブ・ログに「Authority given to user *PUBLIC for object JUCSRV ...」「Authority revoked from user *PUBLIC for object JUCSRV ...」という対の確認メッセージが記録されました。同じ接続の`OBJECT_PRIVILEGES`は、往復後`*PUBLIC`=`*EXCLUDE`(元の状態)に戻っていることを示しています。**ただし`OBJECT_PRIVILEGES`自体は、この接続では往復のあとに1回読んだだけです。往復の途中で実際に`*USE`になったことは、`OBJECT_PRIVILEGES`のSELECTではなく、ジョブ・ログの`CPI2201`/`CPI2202`という対のメッセージから確認しています。** 権限の付与・取り消し自体がエラーなく実行され、かつ`OBJECT_PRIVILEGES`の最終結果が正しく元の状態に戻ることは確認できました。`GRTOBJAUT`/`RVKOBJAUT`はどちらも`OBJTYPE(*SRVPGM)`だけを対象にしており、`*MODULE`側の行は最初から最後まで一度も変更していません。
- **`JOBLOG_INFO('*')`について。** このレッスン専用の新しいプローブとしては実行していませんが、この検証ハーネスの共通ログ機構(`verify/lib/clgen.mjs`)が、ほぼすべての実機接続のログ回収に`FROM TABLE(QSYS2.JOBLOG_INFO('*')) X`という寸分違わぬ形のSQLを使い続けており、上記の`GRTOBJAUT`/`RVKOBJAUT`の確認メッセージ自体も、この仕組み経由でジョブ・ログから読み取られたものです。`docs/probes.md`もこの理由により、新たなプローブなしでV2として扱ってよいとしています。**ただし、これは上の「見つかった実機の落とし穴」節の`CPD0030`と同じ注意が要ります——`CPI2201`/`CPI2202`が読み取られたのは、この検証ハーネスが生成した独立のCLプログラム(ラッパー)のジョブの中であり、本文の実演が指示するACSの「実行SQLスクリプト」内(`CL:`プレフィックス経由)そのものではありません。挙動自体は同じはずですが、厳密には別の実行経路です。**
- **確認できたプローブ**: **P30(`JOBLOG_INFO`・`OBJECT_STATISTICS`・自分のライブラリーの`OBJECT_PRIVILEGES`と`PROGRAM_INFO`・`USER_STORAGE`という5つのIBM iサービス)は確認済みです。`GRTOBJAUT`/`RVKOBJAUT`はP30自体の定義には含まれていませんが、同じ2回目の接続で合わせて確認できています。** **P42(`QCMDEXC`の3つの呼び出し経路)は部分的に確認済みです**——RPG IIIの`CALL`+`PARM`経由(05-04、`part05-qcmdexc-runtime`)、`**FREE`のプロトタイプ経由(06-05、`part06-b8-compile`)はどちらも別レッスンの実機検証で既に確認済みですが、**SQLの`CALL QSYS2.QCMDEXC`経由の経路は、この接続を含め、この教材のどの接続でもまだ実行確認していません。** 本レッスンの演習が、この経路を実機で実際に動かさない(静的な読解にとどめる)設計になっているためです。
- **`GRTOBJAUT`/`USRPRF(*OWNER)`の拒否効果そのもの**は、`design doc`自身が明記するとおり、このPUB400アカウントの構成(P01実測、自分名義の3ライブラリーのみ)では実演できません。V3(未検証)のままです。
- **一次資料ギャップ**: `OBJECT_PRIVILEGES`(7件)・`ACTIVE_JOB_INFO`(2件)・`USER_STORAGE`(2件)は、`secref75.txt`にいずれも権限マトリックス上の名前としての通りすがりの言及があるのみで、列定義・使用例を伴う実ドキュメントではありません。`JOBLOG_INFO`に至っては`secref75.txt`に一度も出現せず(見つかるのは`DSPJOBLOG`/`WRKJOBLOG`という別のCLコマンド名だけです)、この一次資料からの裏付けは実質ゼロです。いずれも「一般知識、要確認」として扱っています。一方`GRTOBJAUT`・`RVKOBJAUT`・`USRPRF(*OWNER)`自体は`secref75.txt`(GRTOBJAUT関連49件)・`cl_commands_75.txt`(`USRPRF`パラメーターの完全な説明)に実質的な記載があり、こちらは一次資料で裏が取れています。`ACTIVE_JOB_INFO`については、`secref75.txt`の通りすがりの言及に加え、`rbafy75.txt`8586-8592行目に`REMOTE TABLE`を使った実働のSQL例が1件ありますが、列定義そのものの記載は無く、かつ分散照会の例であるため、本文では読み物としてのみ紹介し、この教材の単一システム構成でそのまま試すことはしませんでした。
- **`CALL QSYS2.QCMDEXC(...)`(SQLからの`QCMDEXC`呼び出し)** は、`rbafy75.txt`20911-20933行目に実際のIBM公式ドキュメントの例(Javaトラスト・ストア作成手順の一部)がありますが、この教材の検証ハーネスでは実行確認していません。上記のとおり、この経路は本レッスンの演習(静的な読解)の対象であり、意図的に実機で動かしていません。
- **実際にコンパイル・実行されたライブラリーは`<USER>2`でした**(この教材の検証ハーネス自身の方針、`docs/probes.md`)。学習者向けの本文では、この教材のこれまでの慣例どおり`<自分のユーザー名>1`への手順として書いています。**この往復が`<自分のユーザー名>1`でも同じく`*EXCLUDE`に戻ることは、`<自分のユーザー名>1`側で個別に実機確認したわけではありません**——`GRTOBJAUT AUT(*USE)`→`RVKOBJAUT AUT(*USE)`の往復は「`*USE`を与えて、その`*USE`を取り消す」だけの操作なので、往復前の`*PUBLIC`が(`<USER>2`のときと同じく)`*EXCLUDE`であって初めて、往復後も`*EXCLUDE`に戻ります。このためレッスン本文の実演には、手順6へ進む前に手順4の結果で`*EXCLUDE`を確認するよう注記を加えています。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
