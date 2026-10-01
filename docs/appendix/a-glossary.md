# 付録A 用語

この教材が扱ってきた第0部〜第9部の内容から集めています(第6〜7部は「RPG IV」の節、第8部・第9部はそれぞれ専用の節に置いています)。第10部の用語は、この付録には集めていません。各レッスン([10-01](../part10/10-01-preparation-incident.md)〜[10-04](../part10/10-04-api-retrospective.md))の「まとめ」の表にあります。

各レッスンの最後にある「まとめ」の対訳表を1つに集約したものです。同じ用語が複数のレッスンに出てくる場合は1行にまとめ、その用語が最初に出てきたレッスンを「初出レッスン」の列に示しています(訳語が微妙に異なる場合は、初出レッスンでの訳語を採用しています)。英語の見出し語のアルファベット順に並べ、読みやすいようにおおまかな分野ごとに区切ってあります。用語の分野分けはあくまで参照の便宜のためのもので、厳密な分類ではありません。

## 目次

- [5250・基本操作(画面・オブジェクト・ジョブ)](#5250基本操作画面オブジェクトジョブ)
- [データベース(DDS・SQL・ファイル)](#データベースddssqlファイル)
- [CL](#cl)
- [RPG III](#rpg-iii)
- [保守・運用(第5部)](#保守運用第5部)
- [RPG IV(第6〜7部)](#rpg-iv第67部)
- [モダン化・開発手法(第8部)](#モダン化開発手法第8部)
- [API・外部連携(第9部)](#api外部連携第9部)

### 5250・基本操作(画面・オブジェクト・ジョブ)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Batch job | バッチ・ジョブ | 01-08 |
| Call | 呼び出す | 01-07 |
| Cause | 原因 | 01-03 |
| Compile | コンパイル | 01-07 |
| Copy | 複写 | 02-09 |
| Current library | 現行ライブラリー | 01-05 |
| Directory | ディレクトリー | 02-03 |
| Duplicate | 複製 | 01-06b |
| Help | ヘルプ | 01-02 |
| IFS | 統合ファイル・システム | 02-03 |
| Interactive job | 対話式ジョブ | 01-08 |
| Job | ジョブ | 01-08 |
| Job log | ジョブ・ログ | 01-08 |
| Library | ライブラリー | 01-04 |
| Library list | ライブラリー・リスト | 01-05 |
| Member | メンバー | 01-06 |
| Message ID | メッセージID | 01-03 |
| Message queue | メッセージ待ち行列 | 01-09 |
| Object | オブジェクト | 01-04 |
| PASE | PASE(UNIX系プログラムの実行環境) | 02-04 |
| Prompt | プロンプト(補完入力画面) | 01-02 |
| Record length | レコード長 | 01-06 |
| Recovery | 回復 | 01-03 |
| Rename | 改名 | 01-06b |
| Reset | 入力禁止の解除 | 01-01 |
| Restore | 復元 | 02-10 |
| Save file | 保存ファイル | 02-10 |
| Sign off | サインオフ(終了) | 01-01 |
| Source physical file | ソース物理ファイル | 01-06 |
| Sparse checkout | スパース・チェックアウト(部分的な取得) | 02-04 |
| Spooled file | スプール・ファイル | 01-09 |
| Storage | 記憶域 | 01-04 |
| Temporary | 一時的な | 02-09 |

### データベース(DDS・SQL・ファイル)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Access path | アクセス・パス | 02-08 |
| Correlation name | 相関名(SQL のテーブル別名) | 05-08 |
| DDS | データ記述仕様 | 02-02 |
| External field name | 外部フィールド名 | 05-10 |
| Group by | グループ化 | 02-06 |
| Having | (集計後の絞り込み) | 02-07 |
| Join | 結合 | 02-06 |
| Level check | レベル・チェック | 05-09 |
| Logical file | 論理ファイル | 02-01 |
| Omit | 除外 | 02-08 |
| Packed decimal | パック10進 | 02-01 |
| Physical file | 物理ファイル | 02-01 |
| Program-described file | プログラム記述ファイル | 05-09 |
| Record format | 様式(レコード・フォーマット) | 02-01 |
| Record format level ID | 様式レベル ID | 05-09 |
| Select | 選択 | 02-08 |
| Update | 更新 | 02-07 |
| Zoned decimal | ゾーン10進 | 02-01 |

### CL

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Batch | バッチ | 03-12 |
| Command | コマンド | 03-11 |
| Concatenate | 連結する | 03-03 |
| Condition | 条件 | 03-04 |
| CPP | コマンド処理プログラム | 03-11 |
| Declare | 宣言する | 03-02 |
| Else | (そうでなければ) | 03-04 |
| End of file (EOF) | ファイルの終わり | 03-09 |
| Escape message | エスケープ・メッセージ | 03-07 |
| Exception | 例外 | 03-06 |
| Job-scoped | ジョブ・スコープ(そのジョブの間だけ存在する) | 05-07 |
| Label | ラベル | 03-05 |
| Literal | リテラル(直接書いた値) | 03-08 |
| Local Data Area (`*LDA`) | ローカル・データ域 | 05-06 |
| Loop | 繰り返し | 03-05 |
| Message file | メッセージ・ファイル | 03-07 |
| Monitor message (MONMSG) | メッセージの監視 | 03-06 |
| OPNQRYF (Open Query File) | オープン照会ファイル | 05-06 |
| Outfile | 出力ファイル | 03-10 |
| Override | 上書き指定 | 03-10 |
| Pass by reference | 参照渡し | 03-08 |
| Receive file | ファイルを受け取る(1件読む) | 03-09 |
| Severity | 重大度 | 03-01 |
| Shared ODP (Open Data Path) | 共有オープン・データ・パス | 05-06 |
| SNDRCVF (Send/Receive File) | 送信・受信ファイル(CL 駆動の画面表示) | 05-06 |
| Submit job | ジョブを投入する | 03-12 |
| Substring | 部分文字列 | 03-03 |
| Variable | 変数 | 03-02 |

### RPG III

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Allocate | 引き当てる | 04-09 |
| Breakpoint | ブレークポイント | 04-12 |
| Called program / calling program | 呼ばれる側のプログラム / 呼ぶ側のプログラム | 04-08b |
| Combined file | 組み合わせファイル | 04-11 |
| Compare and branch | 比較して分岐(`CABxx`) | 05-02 |
| Compile-time table | コンパイル時テーブル | 05-04 |
| Conditioning indicator | 条件標識 | 04-04 |
| Control break | 制御ブレーク(グループが変わる区切り) | 04-10 |
| Control level | 制御レベル | 04-10 |
| Cross-footing | クロスフッティング(縦計の突き合わせ) | 05-04 |
| Display file | 表示装置ファイル | 04-11 |
| Do While | 条件が真の間繰り返す | 04-05 |
| Edit code | 編集コード | 04-08 |
| Error/exception subroutine | 例外/エラー・サブルーチン | 05-04 |
| Exception output | 例外出力 | 04-01 |
| Extended subfile | 拡張型サブファイル | 05-05 |
| Factor | 項(オペランド) | 04-02 |
| Field rename (I-spec) | フィールドの改名(I 仕様書) | 05-10 |
| Figurative constant | 図形定数 | 04-03 |
| File information data structure (INFDS) | ファイル情報データ構造(INFDS) | 05-04 |
| Full procedural | 全手続き方式 | 04-06 |
| Function key | ファンクション・キー | 04-11 |
| Hang | ハング(応答なしで止まること) | 04-12 |
| Indicator | 標識(インジケーター) | 04-04 |
| Inquiry message | 照会メッセージ | 04-12 |
| Key field | キー・フィールド | 04-07 |
| Left-adjust / Right-adjust | 左詰め / 右詰め | 04-03 |
| Match field | 一致フィールド | 05-03 |
| Matching record | 一致レコード | 05-03 |
| Message subfile | メッセージ・サブファイル | 05-05 |
| MR indicator | 一致レコード標識(`MR`) | 05-03 |
| Operation extender | オペレーション拡張子 | 05-02 |
| Overflow | 桁あふれ | 04-02 |
| Page-at-a-time subfile | ページ単位サブファイル | 05-05 |
| Primary file | プライマリー・ファイル | 04-10 |
| Program status data structure (PSDS) | プログラム状態データ構造(PSDS) | 05-04 |
| QMHSNDPM | プログラム・メッセージ送信 API | 05-05 |
| Random access | ランダム・アクセス(キーによる直接アクセス) | 04-07 |
| READC | 変更されたサブファイル・レコードを読む命令 | 05-05 |
| Record identifying indicator | レコード識別標識 | 05-03 |
| Record lock | レコード・ロック | 04-09 |
| Resulting indicator | 結果標識 | 04-04 |
| RPG cycle | RPG サイクル | 04-10 |
| Parameter list (PLIST) | パラメーター・リスト(`*ENTRY PLIST` は呼ばれる側の入口) | 04-08b |
| Runtime array | 実行時配列 | 05-04 |
| Secondary file | セカンダリー・ファイル | 05-03 |
| SFILE continuation line | SFILE 継続行(F仕様書) | 05-05 |
| SFL / SFLCTL | サブファイル明細レコード様式 / サブファイル制御レコード様式 | 05-05 |
| Specification | 仕様書 | 04-01 |
| Structured opcode | 構造化命令 | 04-05 |
| Subfile | サブファイル | 05-05 |
| Subroutine | サブルーチン | 04-05 |
| Zero balance | ゼロ残高(値がゼロのときの表示) | 04-08 |

### 保守・運用(第5部)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Backup | 退避 | 05-01 |
| Cross-reference | 相互参照 | 05-02 |
| Decimal data error | 10進数データ・エラー | 04-08b(詳しくは 05-11) |
| Direct / indirect reference | 直接参照 / 間接参照 | 05-07 |
| Entry point | 入口 | 05-01 |
| Golden master (test) | ゴールデン・マスター(・テスト) | 05-08 |
| Impact analysis | 影響調査 | 05-07 |
| Incident report | 障害報告書 | 05-11 |
| Legacy system | 旧システム | 05-01 |
| Maintenance record | 改修記録 | 05-01 |
| Promote | (本番への)移送 | 05-12 |
| Reading order | 読む順序 | 05-02 |
| Regression compare | 回帰比較 | 05-08 |
| Rollback | 切り戻し | 05-12 |
| Runbook | 手順書 | 05-12 |
| Zone nibble | ゾーン・ニブル | 05-11 |

### RPG IV(第6〜7部)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Access path | アクセス・パス | 06-14 |
| Activation group | 活動化グループ | 06-05 |
| Bound call | バウンド呼び出し(プログラム呼び出しとの対比) | 06-05 |
| Bind by copy | コピーによる結合 | 07-01 |
| Bind by reference | 参照による結合 | 07-01 |
| Binder language | バインダー言語(`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`) | 07-03 |
| Binding directory (`*BNDDIR`) | バインディング・ディレクトリー | 07-02 |
| Built-in function (BIF) | 組み込み関数 | 06-01b |
| Cursor | カーソル | 06-14 |
| Dynamic SQL | 動的SQL | 06-14 |
| Embedded SQL | 埋め込みSQL | 06-13 |
| Fixed-form | 固定形式 | 06-01 |
| Free-form | 自由形式 | 06-01 |
| Fully free-form | 完全自由形式(`**FREE`) | 06-03 |
| Indicator data structure (INDDS) | 標識データ構造 | 06-10 |
| Module (`*MODULE`) | モジュール | 07-01 |
| Named indicator | 名前付き標識 | 06-03 |
| Null | NULL(値が無いことを表す第3の状態) | 06-14b |
| Null indicator | NULL標識 | 06-14b |
| Prepared statement | 準備済みステートメント | 06-14 |
| Program signature violation | プログラム署名違反(`MCH4431`) | 07-03 |
| Program-entry Procedure Interface | プログラム本体の手続きインターフェース(固定形式`*ENTRY PLIST`の自由形式版) | 06-12 |
| Prototype | プロトタイプ | 06-05 |
| Qualified data structure | 名前空間を分けたデータ構造 | 06-07 |
| Service program (`*SRVPGM`) | サービス・プログラム | 07-02 |
| Signature | シグネチャー | 07-02 |
| Static SQL | 静的SQL | 06-14 |
| Subfile | サブファイル | 06-11 |
| Subprocedure | サブプロシージャー | 06-05 |

**第8部・第9部の節について**: 各レッスンの「まとめ」の対訳表から集めています。「初出レッスン」の列は、その用語が「まとめ」の表に載っているレッスンです(同じ用語が本文中ではもっと前のレッスンに出てくることもあります)。すでに上の節にある用語(制御レベル、制御ブレーク、クロスフッティング、様式レベル ID、エスケープ・メッセージなど)は、重複するため再掲していません。

### モダン化・開発手法(第8部)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Adopted authority | 採用権限(`USRPRF(*OWNER)`、プログラムが所有者の権限を借りて実行される仕組み) | 08-07 |
| Allowlist | 許可リスト方式(あらかじめ許可した値だけを受け入れる検証方法) | 08-07 |
| Assertion | アサーション(比較し、ログに書き、違えば例外を投げる手続き) | 08-04 |
| Bare repository | ベア・リポジトリー(作業コピーを持たないリポジトリー) | 08-01 |
| Build tool | ビルド・ツール(依存グラフに沿って一括ビルドする道具) | 08-02 |
| Capstone | 集大成(複数レッスンの技法を1つの流れに組み合わせるチェックポイント) | 08-08 |
| Changelog | 変更履歴(05-01の改修記録原則のリポジトリー・レベルへの一般化) | 08-08 |
| Characterization test | 特性検定(今の出力を基準にし、実装をどう変えても出力が変わっていないことを確かめる技法) | 08-04 |
| Clean build | クリーン・ビルド(全部消してゼロから作り直すビルド) | 08-02 |
| Command injection | コマンド注入(検証していない入力がコマンドの構文そのものを書き換える脆弱性) | 08-07 |
| Continuous Integration (CI) | 継続的インテグレーション(pushのたびに検査・ビルドを自動実行する仕組み) | 08-03 |
| Declarative configuration | 宣言的な設定(手順ではなく「何が欲しいか」を書く設定) | 08-02 |
| Dependency graph | 依存グラフ(オブジェクト間の「何が何から作られるか」の関係) | 08-02 |
| Fast-forward | 早送り(履歴が一直線につながる、単純な`git pull`の反映のされ方) | 08-01 |
| `GENERATE_SQL` | DDSの外部記述ファイルからSQLの`CREATE TABLE`文等を生成するIBM iサービス | 08-06 |
| IBM i Services | IBM iサービス(`QSYS2`配下のSQL表関数・ビュー) | 08-07 |
| Incremental build | 増分ビルド(変更が無いものはスキップし、変更があるものだけ作り直すビルド) | 08-02 |
| Job-scoped override | ジョブ全体に効く`OVRDBF`の有効範囲(`OVRSCOPE(*JOB)`) | 08-04 |
| Lag cursor | 追従カーソル(片方のカーソルが、もう片方に遅れて追いつく形で進む役) | 08-05b |
| Lint rule | リント・ルール(リンターが検査する個々の規約) | 08-03 |
| Linter | リンター(ソースを読み、規約違反を機械的に検出する道具) | 08-03 |
| `MONITOR` / `ON-ERROR` | 例外を捕まえ、処理を継続させる構文 | 08-04 |
| `NEWOBJ` | `CRTDUPOBJ`が複製先に付ける、元と異なる名前を指定するパラメーター | 08-08 |
| `NUMERIC` / `DECIMAL` | ゾーン10進数 / パック10進数に対応するSQLの数値型 | 08-06 |
| Object authority | オブジェクト権限(オブジェクトに対して何ができるかという権限) | 08-07 |
| Parameter type agreement | パラメーターの型一致(03-08・05-13チケット1の復習) | 08-05b |
| `PRIMARY KEY` | 主キー制約(DDSの`K`はアクセス経路にすぎず、一意性を強制しない) | 08-06 |
| Signature count | シグネチャー数(`DSPSRVPGM DETAIL(*SIGNATURE)`で見る、版を区別する手掛かり) | 08-08 |
| SRCSTMF | ソース・ストリーム・ファイル(メンバーではなくIFS上のファイルから読むソース指定) | 08-01 |
| Static analysis | 静的解析(プログラムを実行せず、ソースを読むだけで行う解析) | 08-03 |
| Target CCSID | コンパイラーがソースを読むときに使うCCSID(`TGTCCSID`) | 08-01 |
| Two-cursor merge | 2カーソル・マージ(08-05bの新出構文) | 08-05b |
| `VARCHAR` | 可変長文字列型(DDSの固定長`A`型との対比) | 08-06 |
| Working copy | 作業コピー(チェックアウトされたファイル一式) | 08-01 |
| Workflow | ワークフロー(GitHub ActionsでCIの手順を定義するYAMLファイル) | 08-03 |

### API・外部連携(第9部)

| 英語 | 日本語 | 初出レッスン |
|---|---|---|
| Adapter | アダプター(外部APIの呼び出しを閉じ込めた、1つのプログラム) | 09-05 |
| API (Application Programming Interface) | プログラムから呼び出すための入口の約束事 | 09-01 |
| API boundary / contract | API境界 / 契約(何を渡すと何が返るか、を型と長さまで決めたもの) | 09-03 |
| Atomicity | 原子性(全部成功するか、全部無かったことになるか) | 09-04 |
| Canned response | 用意した応答(`APIMOCK`の行) | 09-05 |
| CCSID (Coded Character Set Identifier) | 符号化文字集合識別子(文字コードを表す番号) | 09-02b |
| Checkpoint | チェックポイント(複数のレッスンの技法を1つの流れに組み合わせる総合演習) | 09-07 |
| CLOB (character large object) | CLOB(大きな文字データ。応答本文を受ける) | 09-05 |
| Data queue (`*DTAQ`) | データ待ち行列(要求・応答を渡す入れ物) | 09-06 |
| `EXTERNAL NAME` | 外部名(登録する実体の指定。括弧の中はエクスポート名、大文字小文字まで一致) | 09-04 |
| FIFO | 先入れ先出し(入れた順に取り出す) | 09-06 |
| `FORMAT JSON` | 既にJSONである値を、文字列ではなく入れ子のJSONとして入れる指定 | 09-02 |
| Four layers | 4層(実機でやる/観察のみ/読んで設計する/扱わない) | 09-01 |
| Host variable | ホスト変数(埋め込みSQLで、RPGの変数をSQLの文の中で使うもの) | 09-05 |
| `IDENTITY_VAL_LOCAL()` | 直前の`INSERT`が振った、自動採番の値 | 09-05 |
| Idempotent | 冪等(繰り返し呼んでも結果が同じ) | 09-03 |
| `IFS_WRITE_UTF8` | テキストをUTF-8でIFSへ書き出すプロシージャー | 09-02 |
| Input / output data structure | 入力・出力のデータ構造(DS) | 09-03 |
| IWS (Integrated Web Services) | ILEの業務ロジックをWebサービスとして公開する、IBM iに組み込みの仕組み | 09-07 |
| Job queue | ジョブ・キュー(投入したジョブが、動き出すまで待つ場所) | 09-06 |
| JSON | 名前と値の組を波かっこで囲む、結果の書式 | 09-01 |
| JSON object / array | JSONのオブジェクト(`{ }`、名前と値の組)/ 配列(`[ ]`、値の並び) | 09-02 |
| `JSON_OBJECT` / `JSON_ARRAYAGG` | オブジェクトを作る関数 / 複数行を配列に集約する集約関数 | 09-02 |
| `JSON_TABLE` | JSONを行に戻す表関数 | 09-02 |
| Mapepire | マペピア(IBM i上のデーモンにSQLを送る仕組み。この教材では、接続を確かめていない) | 09-07 |
| Message queue (`*MSGQ`) | メッセージ・キュー(通知を溜める、自分専用の入れ物) | 09-06 |
| Mixed data | 混在データ(1バイト文字と2バイト文字が同じ列にある) | 09-02b |
| Mock | モック(あらかじめ用意した応答で、本物の相手の代わりをするもの) | 09-05 |
| `NESTED PATH` | 配列の各要素を、親の行に対応づけて展開する指定 | 09-02 |
| OpenAPI | オープンAPI(HTTPのAPIを、YAMLまたはJSONで記述する仕様。設計書の書式として読む) | 09-07 |
| Order summary API | 受注サマリーAPI(最新の受注N件と、低在庫の件数を、1つのJSONで返す入口) | 09-07 |
| `PARAMETER STYLE GENERAL` | 引数・戻り値がそのまま渡る、素直な引数の渡し方 | 09-04 |
| Path expression / `lax` mode | パス式(`$.lines[*]`など)/ 構造が合わないときのエラーを無視して NULL を返すモード | 09-02 |
| PCML | プログラムの引数の型・長さ・向きを書いたXML(生成される契約書) | 09-03 |
| `PGMINFO` / `INFOSTMF` | プログラム情報の生成指定 / 書き出すIFSファイルのパス(`CRTRPGMOD`のパラメーター) | 09-03 |
| Result code | 結果コード(このレッスンでは、戻り値の`int(10)`) | 09-03 |
| Result set | 結果セット(プロシージャーが開いたまま返すカーソル) | 09-04 |
| REST | HTTPでURLに要求を送って結果を受け取るスタイル | 09-01 |
| Round trip | 往復(表→JSON→表)。元に戻るかで、変換の正しさを確かめる | 09-02 |
| Routine / UDF / UDTF / stored procedure | ルーチン / ユーザー定義関数 / ユーザー定義表関数 / ストアード・プロシージャー | 09-04 |
| SBCS / DBCS | 1バイト文字集合 / 2バイト文字集合(日本語の全角文字など) | 09-02b |
| Sentinel message | 終了要求(ワーカーに終わりを知らせる、特別なメッセージ。ここでは`END`) | 09-06 |
| Shift-Out (SO, X'0E') / Shift-In (SI, X'0F') | シフトアウト / シフトイン(DBCS区間の前後に置く制御バイト) | 09-02b |
| Special authority (`*ALLOBJ`・`*IOSYSCFG`) | 特別権限(すべてのオブジェクト/入出力・通信構成) | 09-01 |
| `SPECIFIC` name | 特定名(有効なシステム名で、同名のオブジェクトが無ければ、実体のオブジェクト名になる。10文字以内) | 09-04 |
| SQL path | SQLパス(ルーチンの中の無修飾の名前を探す場所。作成時のものが保存される) | 09-04 |
| Substitution character | 代替文字(変換できない文字が置き換わる。この実機の結果は`3F`) | 09-05 |
| Synchronous / Asynchronous | 同期 / 非同期(待ち合わせる / 待ち合わせない) | 09-06 |
| Test evidence | テスト証拠(いつ・何で・どの結果を確かめたかの記録) | 09-07 |
| Unicode code point | Unicodeのコード・ポイント(`UX'3042'`の`3042`) | 09-02b |
| `usage` (`input` / `inputoutput`) | 引数の向き(入力 / 入出力) | 09-03 |
| User class (`*PGMR`) | ユーザー・クラス(プログラマー) | 09-01 |
| `VALUES` statement | 式を1つだけ評価して結果を返すSQL文 | 09-01 |
| Worker | ワーカー(要求を取り出して処理する、短命のジョブ) | 09-06 |
