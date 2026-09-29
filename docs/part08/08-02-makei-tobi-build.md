# 08-02 makei(TOBi)でビルドする

> 所要時間: 90分(長め) / 前提レッスン: 08-01 / 目標番号: 6 / 観測方法: `makei build`の標準出力(`Build Successful!`・`Nothing to be done for 'all'`)・`WRKSPLF`(`DRIVER`の10行)・5250(`DSPSRVPGM`・`DSPFFD`、任意の確認)/ 道具: PCのgit/SSHクライアント(08-01と同じ経路でのプロジェクト配送)、SSH(`makei build`の実行)、5250(`DRIVER`の動作確認・`TXRESET`に必須。`DSPSRVPGM`・`DSPFFD`は任意)/ 同時接続数: SSH×1 + 5250×1 + PC側のgitクライアントが張るSSH接続(08-01と同じ、別経路)/ 作る・変えるオブジェクト: `$HOME/zaisrv-bare.git`・`$HOME/zaisrv-clone`(新規、IBM i側)・`<自分のユーザー名>1/ZAISRV`(既存の*MODULE→*SRVPGM。07-05と中身は同じまま、makei経由で作り直す)・`<自分のユーザー名>1/TESTPF`(演習で新規作成する*FILE)。PC側にも新しい小さなgitプロジェクト(`zaiproject`)ができますが、PUB400上のオブジェクトではありません / DBVER: 1 / 依存するプローブ: P16(08-01で解消済み)・P28(`makei --version`・RPGLE/SRVPGMのビルドは実機確認済み。定義に含まれるDSPFのビルドはこのレッスンでは未実施)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- 08-02-1: 依存グラフに沿って`makei build`を一括実行でき、`iproj.json`・`Rules.mk`の役割(特に`Rules.mk`のターゲット宣言が必須であること)を説明できる。
- 08-02-2: 07-05で手作業ビルドした`ZAISRV`を、中身を変えずに`makei`経由で作り直せる。
- 08-02-3: 共有機で不要なクリーン・ビルドを避け、増分ビルド(変更なしはスキップ・変更ありは再ビルド)の仕組みを説明・実践できる。

## ウォームアップ

<details><summary>前回までの復習(08-01/07-05)</summary>

1. (08-01)ソースがメンバーではなくSRCSTMF(IFS上のストリーム・ファイル)から来ても、コンパイラー自身にとって何が変わり、何が変わりませんでしたか?
2. (07-05)`ZAISRV`は`CRTSRVPGM`のどのパラメーターで作られていましたか? `reserve`に`UNLOCK`を1行追加したのは、そのパラメーターとどう関係していましたか?

答え: 1. コンパイラー自身は同じです。メンバーもSRCSTMFも、コンパイラーから見れば「文字の並びが書かれた入れ物」という点で同じであり、中身さえ同じなら同じオブジェクトができます。 2. `ACTGRP(*CALLER)`です。`ZAISRV`は独自の活動化グループを持たず、呼び出し元の活動化グループに活動化されるため、`F0608A`(`*PGM`)では`*inlr`到達時に自動的に解放されていたロックが、`*SRVPGM`化すると呼び出し元の設計次第で長く残ってしまう可能性があり、`reserve`のSHORT分岐(実際にロックを取った1分岐)だけに`UNLOCK`を追加しました。

</details>

## なぜ学ぶか

08-01では、`JUCSRV`という2オブジェクト(*MODULE・*SRVPGM)だけを対象に、`CRTRPGMOD`→`CRTSRVPGM`を手で1回ずつ打ちました。オブジェクトが2つならこれでも苦になりませんが、実際の開発では依存関係を持つオブジェクトが数十・数百に増えます。「どのオブジェクトをどの順で、どのオプションでビルドするか」を毎回手で組み立てるのは、規模が大きくなるほど現実的ではありません。

`makei`(通称TOBi)は、IBM i上で動く、プロジェクトの依存グラフに沿って一括ビルドするツールです。宣言的な設定ファイル(`iproj.json`・`Rules.mk`)に「何を」「どこへ」ビルドするかを書いておけば、`makei build`という1コマンドだけで、変更されたオブジェクトだけを正しい順序で作り直してくれます。この課では、07-05でチェックポイントとして手作業ビルドした`ZAISRV`(在庫サービス、`get`・`reserve`・`release`)を題材に、まったく同じ中身を`makei`経由で作り直します。

**このレッスンでは、08-01の`myproject`(`JUCSRV`)とは別の、新しいプロジェクトを使います。** `ZAISRV`のソースは`JUCSRV`と同じ`//===`という罫線コメントの書式を使っています。次のレッスン(08-03)は`myproject`のディレクトリー全体を対象に`rpglint`を1回実行し、その合計件数を確認可能な数値として使います——ここに`ZAISRV`を混ぜてしまうと、08-03が確認する合計件数が変わってしまいます。`myproject`には一切手を入れず、`ZAISRV`には`ZAISRV`専用の新しいプロジェクト(`zaiproject`)を別に用意します。

あわせて、PUB400は多くの利用者が同時に使う共有機です。オブジェクトを1から全部作り直す「クリーン・ビルド」の習慣は、他の利用者のCPU・ディスクを無駄に消費する不作法になり得ます。`makei build`が実際にどう「変更が無ければ何もしない」かを確かめ、この配慮を実践します。

## 新出

- 中核概念:
  1. **依存グラフに沿った一括ビルドという発想。** 単発の`CRTxxx`をオブジェクトの数だけ積み上げる代わりに、`makei build`という1コマンドで、プロジェクト全体を正しい順序でビルドします(この発想自体は`make`・`npm`・`maven`のような他の言語のビルド・ツールと同じで、IBM iの世界での現れが`makei`です)。
  2. **`iproj.json`+`Rules.mk`という宣言的なビルド設定。** `iproj.json`は「どこへ(ビルド先ライブラリー)」を、`Rules.mk`は「何を(対象オブジェクトとその依存関係)」を、それぞれ宣言します。**`Rules.mk`はエッジケース向けの任意ファイルではありません。** `オブジェクト名.オブジェクト型: ソース・ファイル`という形のターゲット行を1つも書かなければ、`makei`はビルド対象を1つも認識せず、対象ライブラリーの中身が空だろうと既存オブジェクトがあろうと`make: Nothing to be done for 'all'`のまま終わります(下の「説明」で詳しく扱います)。
  3. **共有機での増分ビルドの配慮。** `makei build`は、ソースに変更が無いオブジェクトを実際にスキップし、変更があるオブジェクトだけを再ビルドします。PUB400のような共有機では、「困ったら全部作り直す」というクリーン・ビルドの習慣を避け、この増分ビルドの仕組みに任せるのが作法です。
- 構文:
  1. `iproj.json`(プロジェクト記述ファイル。`objlib`・`curlib`等を宣言)。
  2. `makei build`(プロジェクト全体を一括ビルドするコマンド)。
  3. `Rules.mk`(対象オブジェクトを宣言する、ビルドの主たる仕組み)。
  4. `makei --version`(TOBi自身のバージョンを確認するコマンド)。
  5. `bash -c '...'`(複数のコマンドを1つの非対話SSHコマンドとしてまとめて実行する形。中身には02-04で確立済みの`export PATH=...`・`&&`をそのまま使います)。

**読解用(新出に数えない)**:

- `makei init`: 新規プロジェクトを対話式に初期化するサブコマンドです。「descriptive application name」「objlib」等をプロンプトで尋ねる、対話式のウィザードです(非対話で直接呼び出すと入力待ちで停止します)。このレッスンでは使わず、`templates/part08-zaisrv/`のファイルをそのままコピーする方法を取ります。
- `makei cvtsrcpf`: 既存のソース物理ファイル・メンバーをUTF-8のIFSファイルへ変換する、TOBi自身の専用サブコマンドです。**この教材ではまだ実機確認していません。** この課では、代わりに03-10で既習の`CPYTOSTMF`(下の「説明」参照)を使います。

**既習の応用(新出に数えない)**:

- `git init`/`git add`/`git commit`/`git remote add`/`git push`/`git clone`/`git pull`(08-01)。新しいプロジェクトに、同じ操作をそのまま適用します。
- `CPYTOSTMF`(03-10で既習。07-05の`CPYFRMSTMF`とは逆方向〔メンバー→IFS〕の操作です)。
- `ACTGRP(*CALLER)`・`EXPORT(*SRCFILE)`(07-05)。`ZAISRV`の設計自体は変えません。
- `TGTCCSID(*JOB)`(08-01)。`makei`が生成する`CRTRPGMOD`にもこのパラメーターが自動的に付くことを、下の「説明」で確認します。

## 説明

### なぜ一括ビルドが要るのか

08-01の`JUCSRV`は`*MODULE`→`*SRVPGM`の2段階だけでした。実際のプロジェクトは、これがモジュール何十個・サービス・プログラム何個という依存関係の連なりになります。「どのオブジェクトが古くなったか」「どの順でビルドし直すべきか」を毎回自分で判断して`CRTxxx`を打つのは、規模が増えるほど手に負えなくなります。**一般によく使われる解決策は、依存関係を宣言的な設定ファイルに書いておき、ビルド・ツールにその依存グラフをたどらせることです**(`make`・`npm`・`maven`のような道具が広く使われているのと同じ考え方です)。`makei`(通称TOBi)は、この考え方をIBM iのILEオブジェクト向けに実装したツールです。

### `iproj.json`: ビルド先を宣言する

`templates/part08-zaisrv/iproj.json`の中身です。

```json
{
  "version": "0.0.1",
  "description": "ZAISRV (Part 8 makei rebuild) - objlib/curlib both set to the learner's own dev library",
  "objlib": "YOURUSER1",
  "curlib": "YOURUSER1",
  "includePath": [],
  "preUsrlibl": [],
  "postUsrlibl": []
}
```

`YOURUSER1`はプレースホルダーです。自分のユーザー名1(`<自分のユーザー名>1`)に書き換えて使います。

- `objlib`: ビルドしたオブジェクトの置き場所です。**空のライブラリーを対象にした場合と、既に`ZAISRV`が存在するライブラリーを対象にした場合の両方で、`objlib`が実際にビルド先を制御することを実機確認済みです**(下の「実機メモ」参照)。既定の`*CURLIB`任せではなく、ここで明示したライブラリーに作られます。
- `curlib`: ビルド時のカレント・ライブラリーです。**この検証では`objlib`と常に同じ値に設定しているため、2つの役割を切り分けて個別に確認したわけではありません。** `objlib`(ビルド先)が実際に効くことは確認済みですが、`curlib`単独の効果までは確認していません。
- `includePath`: 08-01の`INCDIR`に相当する項目です(`/COPY`ディレクティブのコピー・ファイル検索パス)。`zaisrv.rpgle`は`/COPY`を使わないため、`jucsrv.rpgle`のときと同様、このレッスンでは実際には使いません。
- `preUsrlibl`/`postUsrlibl`: ビルド・ジョブの`*LIBL`のユーザー部に、明示的にライブラリーを追加する項目です。既定は空配列で、このレッスンでもそのままにします。

### `Rules.mk`: 何をビルドするかを宣言する、必須のファイル

`templates/part08-zaisrv/Rules.mk`の中身です。

```text
# makeiが実際に何をビルドするかを宣言するファイル(必須)。iproj.jsonと
# 同じディレクトリー(または各サブディレクトリー)に置くとmakeiが自動的に
# 読み込む。TOBi自身のドキュメント(PUB400上の
# /QOpenSys/pkgs/lib/tobi/docs/prepare-the-project/rules.mk.md、
# work/design/refs/にはミラーされていない一次資料)によれば、
# 「オブジェクト名.オブジェクト型: ソース・ファイル」という形の行(ルール)
# を1つも書かなければ、makeiは「ビルドするものが無い」と判断する
# (このリポジトリでの実機確認: `docs/probes.md`のpart08-02-makei-probe2、
# コメントのみのRules.mkでは`make: Nothing to be done for 'all'`になった)。
#
# オブジェクト名は大文字、`.MODULE`/`.SRVPGM`のようなIFS拡張子を付けて
# 書く(TOBi自身の規約)。ソース・ファイル名は実際のファイル名をそのまま
# 小文字で書いてよい(`$(d)/`のような接頭辞は現在のTOBiでは不要)。

ZAISRV.MODULE: zaisrv.rpgle
ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd
```

`ZAISRV.MODULE: zaisrv.rpgle`は「`ZAISRV`という`*MODULE`は、`zaisrv.rpgle`から作る」という意味です。`ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd`は「`ZAISRV`という`*SRVPGM`は、`ZAISRV.MODULE`(1行目で作ったモジュール)と`zaisrv.bnd`(バインダー・ソース)から作る」という意味で、モジュール→サービス・プログラムという依存関係そのものを表しています。

**このコメントが「必須」と明記しているとおり、この2行こそがこのファイルの本体です。** このリポジトリの調査では、当初このファイルが100%コメントのまま(ターゲット行ゼロ)で`makei build`を試し、対象ライブラリーが空だろうと`ZAISRV`が既に存在していようと、常に同じ`make: Nothing to be done for 'all'`で終わることが確認されました。原因はライブラリーの中身とは無関係で、単に依存グラフに何も登録されていなかったことでした。**`Rules.mk`に正しいターゲット行が無ければ、`iproj.json`の設定がどれだけ正しくても、`makei build`は何もしません。**

**コメントの有無・中身はビルドの成否に影響しません**——GNU makeは`#`から始まる行の中身を一切解釈しないためです。上のコメント付き`Rules.mk`(2行のターゲット宣言込み)を使ったビルドと、コメントを一切含まない2行だけの`Rules.mk`を使ったビルドの両方が、実際に成功しています(詳細は下の「実機メモ」参照)。

### `make: Nothing to be done for 'all'`には2つの意味がある

この同じメッセージが出る場面は、実は2通りあります。

1. **`Rules.mk`にターゲット行が1つも無い場合。** この場合、`objlib`に何が入っていようと関係なく、常にこのメッセージになります——新規プロジェクトで最初にこのメッセージを見たら、まず`Rules.mk`の中身を疑ってください。
2. **`Rules.mk`は正しいのに、ソースに変更が無い場合。** この場合は、実際に「ビルド済みで最新だからスキップした」という、正常な増分ビルドの結果です。

下の「実演」では、まず`Rules.mk`のターゲット行を一時的に消して1つ目の意味(ターゲット行ゼロ)を確認し、続けて`Rules.mk`を元に戻した状態で2つ目の意味(本当のスキップ)を確認します——同じメッセージが、原因の違う2通りの場面で出ることを、両方とも自分の手で確認します。

### `makei build`の呼び出し方

確認済みの呼び出し形はこれだけです。

```sh
/QOpenSys/pkgs/bin/bash -c 'cd <プロジェクトのディレクトリー> && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
```

02-04で確立したSSH接続(既定でPASEの`bsh`シェルに入ります)から、この`bash -c '...'`という形でまとめて実行してください。**`bsh`自体の2段階`export`形(02-04で確立済み)と組み合わせて`makei build`を実行した接続はまだ無いため、このレッスンでは上の`bash -c`形をそのまま使います。**

内部では、`makei`は実際にGNU makeを、TOBi自身が持つMakefileと`Rules.mk`を合わせて呼び出しています(実機確認済み、下の「実演」の出力例参照)。

```text
> /QOpenSys/pkgs/bin/make -k BUILDVARSMKPATH="..." -k TOBI_PATH="/QOpenSys/pkgs/lib/tobi" -f "/QOpenSys/pkgs/lib/tobi/src/mk/Makefile" all
```

`makei`という1つの入口の裏側で、実際には使い慣れた`make`が依存グラフをたどっている、という構造です。

| 出会う出力 | 原因 | 対処 |
|---|---|---|
| `It looks like /QOpenSys/pkgs/bin/ is not currently in your system PATH.`(`PATH`は実際には正しく通っている) | 5250から`STRQSH`等でqshに入り、そこで`makei`を直接呼んでいる。qshからの直接呼び出しは、`PATH`が実際に正しくても、この誤った診断メッセージを出すことが実機確認済み | 02-04で確立したSSH接続(既定のPASE `bsh`)から、上の`bash -c`形で呼び出す |
| `RNF2120`(外部記述ファイルが見つからない) | `zaisrv.rpgle`は`ZAIKOM`を非修飾名で参照します。`makei`自身のビルド・ジョブが`*LIBL`をどう組み立てるかは、このリポジトリでは未確認です(一般知識、要確認) | `iproj.json`の`preUsrlibl`(または`postUsrlibl`)に自分のライブラリーを明示する。例: `"preUsrlibl": ["<自分のユーザー名>1"]`(フィールド自体はTOBi自身の`iproj-json.md`で確認済みですが、これで実際に`RNF2120`が解消することまではこのリポジトリでは未確認です)。**08-01の`ADDLIBLE`(5250の対話ジョブ向けの対処)は、ここでは使えません**——5250の対話ジョブとSSH経由で`bash -c`が起動する`makei build`のジョブは別物で、一方の`*LIBL`調整はもう一方に影響しません(08-01参照) |

### 増分ビルドが比較しているもの、「クリーン・ビルド」とは何を指すか

上のとおり、内部で実際に動いているのはGNU makeです。GNU makeは、対象オブジェクト(`*MODULE`・`*SRVPGM`等)と、それが依存するソース・ファイルの更新日時(タイムスタンプ)を比較し、**ソースの方が新しければ再ビルド対象、そうでなければスキップ**と判定します(GNU make自身の一般的な仕組みで、この教材固有の挙動ではありません——一般知識)。

**「クリーン・ビルド」とは、この判定に頼らず、対象オブジェクトを手動で削除してから(例: `DLTOBJ`で消してから改めて`makei build`を実行する)ゼロから作り直すことです。** 共有機でこの習慣を避けるべきなのは、こうして消してしまうと、実際には変更されていないオブジェクトまで、毎回CPU・ディスクを使って作り直す羽目になるためです。増分ビルドに任せれば、`makei build`をそのまま繰り返し打つだけで、変更されたオブジェクトだけが対象になります。

### TOBiのバージョン

**このPUB400のTOBiバージョンは`3.2.1`です(`makei --version`の実機出力、確認済み)。**

```text
$ makei --version
TOBi version 3.2.1
```

### 既存の(makei以外で作った)オブジェクトの再ビルド

07-05で`CRTRPGMOD`/`CRTSRVPGM`により手作業で作った`ZAISRV`を、`makei`が正しく再ビルドできることを、実際に07-05由来の本物のオブジェクトが存在するライブラリーに対して確認済みです(下の「実機メモ」参照)。`makei`自身のログに`REPLACE`パラメーターは明示的に表示されませんが、既存オブジェクトへの上書きは問題なく成功します(`REPLACE`の既定値は`*YES`と確認できています)。

### プロジェクトの配置はフラット

このレッスンで確認したプロジェクトは、`iproj.json`・`Rules.mk`・`.gitattributes`・`zaisrv.rpgle`・`zaisrv.bnd`がすべてプロジェクトの直下に並ぶ、**サブディレクトリー無しのフラットな構成**です。08-01の`myproject`(`src/qrpglesrc/`・`src/qsrvsrc/`というサブディレクトリー構成)とは異なります。`Rules.mk`には`SUBDIRS`宣言でサブディレクトリーを束ねる仕組みもあるようですが、この課ではまだ実機確認しておらず(V3)、`myproject`とは別のプロジェクトとして扱うことで、この未確認の組み合わせを避けています。

### 07-05のソースをこの新しいプロジェクトへ持ち込む: `CPYTOSTMF`

07-05では、`zaisrv.rpgle`・`zaisrv.bnd`はメンバー(`<自分のユーザー名>1/QRPGLESRC.ZAISRV`・`QSRVSRC.ZAISRV`)として存在しています。この新しいIFSプロジェクトへ持ち込むには、03-10で既習の`CPYTOSTMF`(メンバー→IFS。07-03/07-05で使った`CPYFRMSTMF`〔IFS→メンバー〕の逆方向)を使います。

```text
CPYTOSTMF FROMMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/ZAISRV.MBR') TOSTMF('<コピー先のパス>/zaisrv.rpgle') STMFOPT(*REPLACE) STMFCCSID(1208) ENDLINFMT(*LF)
```

`STMFCCSID(1208)`はUTF-8として書き出す指定(02-03既習)、`ENDLINFMT(*LF)`は改行コードをLFに強制する指定です。この組み合わせで、`git clone`直後のファイルと同じ条件(UTF-8・LF)のストリーム・ファイルができることを実機確認済みです。

### git配送と`.gitattributes`: CRLFでも安心な理由

`templates/part08-zaisrv/.gitattributes`は、08-01の`templates/part08-project/.gitattributes`と同じ内容です(コメント行は省略して引用します)。

```text
* text=auto eol=lf

*.rpg text eol=lf
*.rpgle text eol=lf
*.clp text eol=lf
*.clle text eol=lf
*.pf text eol=lf
*.lf text eol=lf
*.dspf text eol=lf
*.prtf text eol=lf
*.cmd text eol=lf
*.rpgleinc text eol=lf
*.bnd text eol=lf
*.sql text eol=lf
*.sqlrpgle text eol=lf
*.md text eol=lf
*.json text eol=lf
```

`Rules.mk`・`iproj.json`は拡張子ごとの個別行には無い拡張子ですが、一番上の`* text=auto eol=lf`という既定行がすべてのファイルに効くため、`.mk`・`.json`ファイルもLFに正規化されます。**これは理論上の話ではありません。** このレッスンの検証では、`Rules.mk`をわざとCRLF(`\r\n`)で書いてから`git add`/`git commit`したところ、git自身が次の警告を出しました。

```text
warning: in the working copy of 'Rules.mk', CRLF will be replaced by LF the next time Git touches it
```

そして実際に`git clone`した側の`Rules.mk`をバイト単位で確認すると、コミット前にあった`\r`は無くなり、LFだけになっていました。**学習者自身のPC側のgit設定がCRLFのままだったとしても、`.gitattributes`をプロジェクトに含めておけば、IBM i側に届く時点でLFに正規化される**ということが、この確認で裏付けられています。`templates/part08-zaisrv/iproj.json`・`Rules.mk`と一緒に、この`.gitattributes`も必ず新しいプロジェクトへコピーしてください。

## 実演

**この実演で作る`ZAISRV`のmakeiビルドは、CONFIRMED SUCCESSまで実機確認済みです(下の「実機メモ」参照)。ただし、この本文が示すPC↔IBM i間のファイルの流れそのもの(どちら側でどの手順を行うか)は、このレッスンの検証と完全に同一の経路ではありません——実機メモの該当節を必ず読んでください。**

### A. プロジェクトを用意する(08-01と同じ要領)

08-01で経験した手順とほぼ同じです。ここでは詳しく繰り返さず、コマンドだけ示します(08-01の「実演A」を復習したい場合はそちらを参照してください)。

1. PCに新しい空のディレクトリーを作り、gitリポジトリーとして初期化します。

   ```sh
   mkdir zaiproject && cd zaiproject
   git init -b main
   ```

2. `templates/part08-zaisrv/iproj.json`・`Rules.mk`・`.gitattributes`の3ファイルを、このプロジェクトのルートにコピーします(上の「説明」で見た中身です)。`iproj.json`の`YOURUSER1`(2箇所)を、自分のユーザー名1に書き換えてください。**08-01の`myproject`とは違い、サブディレクトリーは作りません**——`iproj.json`・`Rules.mk`・`.gitattributes`はすべてプロジェクトの直下に置きます。

3. コミットします(PC側のgitユーザー名・メール・アドレスは08-01で設定済みのはずです)。

   ```sh
   git add .gitattributes iproj.json Rules.mk
   git commit -m "Initial ZAISRV makei project"
   ```

4. SSHで接続し、PUB400側にベア・リポジトリーを作ります。**SSH接続の既定シェル(P08確認済みの`bsh`)は語頭の`~`を展開しません**(実機確認済み、下の「実機メモ」参照)——`$HOME`を使ってください。

   ```sh
   git init --bare -b main $HOME/zaisrv-bare.git
   ```

5. PC側に戻り、リモートを登録してpushします(`Host pub400`のエイリアスを設定済みなら`pub400:zaisrv-bare.git`、していなければ`ssh://<自分のユーザー名>@pub400.com:2222/~/zaisrv-bare.git`——08-01と同じ判断です。このURLの`~`はgit自身が解釈する記法で、リモート・シェルの`~`展開には頼っていません)。

   ```sh
   git remote add zaisrv pub400:zaisrv-bare.git
   git push zaisrv main
   ```

6. もう一度SSHで接続し、ビルド用の作業クローンを作ります。

   ```sh
   git clone $HOME/zaisrv-bare.git $HOME/zaisrv-clone
   ```

   この時点で`$HOME/zaisrv-clone`には`iproj.json`・`Rules.mk`・`.gitattributes`の3ファイルだけがあり、`zaisrv.rpgle`・`zaisrv.bnd`はまだありません。

### B. 07-05のソースを、このクローンへ持ち込む

1. **このクローンは、08-01の`$HOME/pub400-clone`とは違い、ここから自分でコミット・pushします。** そのため、gitのユーザー名・メール・アドレスを、このクローンだけに設定してください(`--global`は付けません)。

   ```sh
   cd $HOME/zaisrv-clone
   git config user.name "自分の名前"
   git config user.email "自分のメール・アドレス"
   ```

2. 07-05で作った`<自分のユーザー名>1/QRPGLESRC.ZAISRV`・`QSRVSRC.ZAISRV`の2メンバーを、`CPYTOSTMF`でこのクローンへ書き出します。

   ```text
   CPYTOSTMF FROMMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/ZAISRV.MBR') TOSTMF('/home/<自分のユーザー名>/zaisrv-clone/zaisrv.rpgle') STMFOPT(*REPLACE) STMFCCSID(1208) ENDLINFMT(*LF)
   CPYTOSTMF FROMMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QSRVSRC.FILE/ZAISRV.MBR') TOSTMF('/home/<自分のユーザー名>/zaisrv-clone/zaisrv.bnd') STMFOPT(*REPLACE) STMFCCSID(1208) ENDLINFMT(*LF)
   ```

   07-05のように5250から実行してもかまいませんし、07-05自身がSSHの中で`system "..."`という形で`CPYFRMSTMF`を実行したのと同じ要領(`system`コマンド経由)で、SSHのシェルから実行してもかまいません。

3. コミットし、ベア・リポジトリーへpushし直します。

   ```sh
   git add zaisrv.rpgle zaisrv.bnd
   git commit -m "Bring in ZAISRV source from the 07-05 members"
   git push origin main
   ```

4. PC側で`git pull`し、`myproject`と同じように`zaiproject`にも全ファイルが揃っていることを確認してください(このあとの実演E・演習で、PC側から`zaisrv.rpgle`を編集して再びpushするために必要です)。

    ```sh
    cd zaiproject
    git pull zaisrv main
    ```

### C. 初回ビルド

1. SSHで`$HOME/zaisrv-clone`に接続し、まず`makei --version`で環境を確認します。

    ```sh
    /QOpenSys/pkgs/bin/bash -c 'export PATH=/QOpenSys/pkgs/bin:$PATH && makei --version'
    ```

    ```text
    TOBi version 3.2.1
    ```

2. `makei build`を実行します。

    ```sh
    /QOpenSys/pkgs/bin/bash -c 'cd $HOME/zaisrv-clone && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
    ```

    次のとおり成功するはずです(実機確認済み、ライブラリー名は自分のユーザー名1に読み替えてください)。

    ```text
    === Creating RPG module [zaisrv.rpgle]
    crtrpgmod module(<自分のユーザー名>1/ZAISRV) srcstmf('/home/<自分のユーザー名>/zaisrv-clone/zaisrv.rpgle') AUT() DBGVIEW(*ALL) DBGENCKEY(*NONE) OPTIMIZE() OPTION(*EVENTF) OUTPUT(*PRINT) TEXT('') TGTCCSID(*JOB) TGTRLS() INCDIR(*NONE) DEFINE()
    ZAISRV.MODULE was created successfully!

    === Creating service program [ZAISRV] from modules [ZAISRV] and service programs []
    CRTSRVPGM srcstmf('/home/<自分のユーザー名>/zaisrv-clone/zaisrv.bnd') SRVPGM(<自分のユーザー名>1/ZAISRV) MODULE(ZAISRV) BNDSRVPGM(*NONE) ACTGRP(*CALLER) ALWUPD(*YES) TEXT('') TGTRLS() AUT() DETAIL(*BASIC) STGMDL(*SNGLVL) OPTION() BNDDIR() USRPRF(*USER) ALWRINZ(*YES)
    ZAISRV.SRVPGM was created successfully!

    Objects:             0 failed 2 succeed 2 total
    Build Successful!
    ```

    (実際の端末では、成功した行の先頭にチェック・マークが表示されます。フォント・端末次第で見え方が変わることがあります。)`crtrpgmod`の行に、08-01が学習者に教えたのと同じ`TGTCCSID(*JOB)`が自動的に付いていること、`CRTSRVPGM`が07-05と同じ`ACTGRP(*CALLER)`を使っていることに注目してください——**同じ`ZAISRV`が、手作業のときとまったく同じ設計のまま、今度は`makei`経由で作られました。**

3. (任意・V3、07-05自身の実機メモのとおりこの検証でも未実施)5250で`DSPSRVPGM SRVPGM(<自分のユーザー名>1/ZAISRV)`を実行し、`GET`・`RESERVE`・`RELEASE`(いずれも大文字)がエクスポートされていることを確認してください。

4. **`makei`が作り直した`ZAISRV`が、07-05のときと実際に同じ振る舞いをするかを確認します。** 07-05の`DRIVER`は`ZAISRVBD`(`ADDBNDDIRE ... OBJ((*LIBL/ZAISRV *SRVPGM))`)を経由して`*LIBL`上の`ZAISRV`を解決する設計のため(07-02で確認済みの「ライブラリー名はコードに焼き込まれない」という仕組みと同じです)、`ZAISRV`を`makei`で作り直した後でも、`DRIVER`自身は再コンパイルせずそのまま使えるはずです。5250で、まず`<自分のユーザー名>1/TXRESET`を実行して`ZAIKOM`を初期状態に戻してから、`DRIVER`を実行してください。

    ```text
    <自分のユーザー名>1/TXRESET
    CALL PGM(<自分のユーザー名>1/DRIVER)
    ```

    `WRKSPLF`で出力を確認し、次の10行(07-05の「説明」・実機メモに記録された`0-BASELINE`〜`7-NOTFOUND-RSV`と、1文字も違わず一致するはずです——実機確認済み、下の「実機メモ」参照)と一致することを確認してください。

    ```text
    0-BASELINE       P00001 QTY=0        OK= Y ZASU=45       get() peek
    1-RESERVE-OK     P00001 QTY=2        OK= Y ZASU=43       expect ON, -qty
    2-RESERVE-SHORT  P00001 QTY=9999999  OK= N ZASU=43       expect OFF, same
    2B-DIAG-CHAIN    P00001 QTY=0        OK= Y ZASU=0        NO CONFLICT SEEN
    3-RELEASE        P00001 QTY=2        OK= Y ZASU=45       expect ON, =start
    4-TWICE-A        P00001 QTY=2        OK= Y ZASU=41       expect ON
    4-TWICE-B        P00001 QTY=2        OK= Y ZASU=41       expect ON, -2*qty
    5-RESTORE        P00001 QTY=2        OK= Y ZASU=45       expect =start
    6-NOTFOUND-GET   P99999 QTY=0        OK= Y ZASU=-1       expect -1
    7-NOTFOUND-RSV   P99999 QTY=2        OK= N ZASU=0        expect OFF
    ```

    一致すれば、「`makei`経由で作り直した`ZAISRV`が、07-05の手作業ビルドのときとまったく同じに振る舞う」という08-02-2の核心を、出力の一致という動作レベルで確認したことになります。確認できたら、もう一度`<自分のユーザー名>1/TXRESET`を実行し、`ZAIKOM`を元の状態に戻しておいてください(演習・以後のレッスンへの影響を避けるため)。

5. **(`Nothing to be done for 'all'`の1つ目の意味を体感します。)** PC側の`zaiproject`で`Rules.mk`を開き、2行のターゲット宣言(`ZAISRV.MODULE:`・`ZAISRV.SRVPGM:`)の行頭に一時的に`#`を追加してコメントアウトしてください。コミットしてpushします。

    ```sh
    git add Rules.mk
    git commit -m "Temporarily comment out the target lines (meaning #1 demo)"
    git push zaisrv main
    ```

6. SSHで`$HOME/zaisrv-clone`に接続し、pullしてから同じビルド・コマンドをもう一度実行してください。

    ```sh
    cd $HOME/zaisrv-clone
    git pull origin main
    /QOpenSys/pkgs/bin/bash -c 'cd $HOME/zaisrv-clone && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
    ```

    さきほどと同じ`make: Nothing to be done for 'all'.`が出ますが、**今回は意味が違います**——`ZAISRV`が既にビルド済みだからではなく、`Rules.mk`にターゲット行が1つも無いからです(上の「説明」で見た1つ目の意味そのもので、`part08-02-makei-probe2`の実機確認と同じ結果です)。

7. 確認できたら、PC側で`Rules.mk`の`#`を削除して元に戻し、再びコミット・push・pullしてください。

    ```sh
    git add Rules.mk
    git commit -m "Restore the target lines"
    git push zaisrv main
    ```

    ```sh
    cd $HOME/zaisrv-clone
    git pull origin main
    ```

    次の「D」で、この状態から改めて`makei build`を実行し、正しく「本当のスキップ」になることを確認します。

### D. 増分ビルド(1): 変更なし→スキップ

1. 何もソースを変更せず、同じビルド・コマンドをもう一度実行します。

    ```sh
    /QOpenSys/pkgs/bin/bash -c 'cd $HOME/zaisrv-clone && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
    ```

    ```text
    > /QOpenSys/pkgs/bin/make -k BUILDVARSMKPATH="..." -k TOBI_PATH="/QOpenSys/pkgs/lib/tobi" -f "/QOpenSys/pkgs/lib/tobi/src/mk/Makefile" all
    make: Nothing to be done for 'all'.
    Objects:            0 failed 0 succeed 0 total
    ```

    **今回の`Nothing to be done for 'all'`は、上の「説明」で見た2つの意味のうち後者(本当のスキップ)です。** `Rules.mk`には正しいターゲット行があり、`zaisrv.rpgle`・`zaisrv.bnd`のどちらも実演Cの初回ビルドから変更していないため、`makei`は「作り直す必要が無い」と正しく判定しています。

### E. 増分ビルド(2): 変更あり→再ビルド

1. PC側の`zaiproject`で、`zaisrv.rpgle`に、動作に影響しないコメント行を1行だけ追加してください(例: ファイル末尾近くに`// makei rebuild test: <今日の日付>`)。

2. コミットしてpushします。

    ```sh
    git add zaisrv.rpgle
    git commit -m "Add a round-trip test comment"
    git push zaisrv main
    ```

3. SSHで`$HOME/zaisrv-clone`に接続し、pullします。

    ```sh
    cd $HOME/zaisrv-clone
    git pull origin main
    ```

4. 同じビルド・コマンドをもう一度実行します。

    ```sh
    /QOpenSys/pkgs/bin/bash -c 'cd $HOME/zaisrv-clone && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
    ```

    今度は「Nothing to be done」にはならず、実演Cの初回ビルドと同じ`crtrpgmod`→`CRTSRVPGM`のフル実行になります(実機確認済み、`part08-02-makei-probe3`の`EDITSRC`→`BUILD2`)。

    ```text
    === Creating RPG module [zaisrv.rpgle]
    crtrpgmod module(<自分のユーザー名>1/ZAISRV) srcstmf('...') ... TGTCCSID(*JOB) ...
    ZAISRV.MODULE was created successfully!

    === Creating service program [ZAISRV] from modules [ZAISRV] and service programs []
    CRTSRVPGM srcstmf('...') SRVPGM(<自分のユーザー名>1/ZAISRV) MODULE(ZAISRV) ... ACTGRP(*CALLER) ...
    ZAISRV.SRVPGM was created successfully!

    Objects:             0 failed 2 succeed 2 total
    Build Successful!
    ```

    **`zaisrv.bnd`(バインダー・ソース)は今回1バイトも変更していないのに、`ZAISRV.SRVPGM`も再ビルドされている点に注目してください。** これは依存グラフの伝播です——`Rules.mk`の2行目(`ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd`)は`ZAISRV.SRVPGM`が`ZAISRV.MODULE`にも依存すると宣言しており、その依存先の`ZAISRV.MODULE`が(`zaisrv.rpgle`の変更で)再ビルドされた以上、`ZAISRV.SRVPGM`も古いと判定され、連鎖して再ビルドされます。**変更が無ければスキップし、変更があれば(依存先を通じてでも)実際に再ビルドする——この両方向が、依存グラフに基づく増分ビルドの実体です。** クリーン・ビルド(全部消してゼロから作り直す)をしなくても、`makei build`をそのまま繰り返し打つだけで、共有機に配慮した最小限のビルドになります。

## 演習

**PFを追加します。** `Rules.mk`は、`*MODULE`・`*SRVPGM`だけでなく、DDSで書く`*FILE`(物理ファイル)も同じ形式で宣言できます。

1. PCの`zaiproject`に、`testpf.pf`という新しいファイルを作り、次のDDSソースをそのまま入力してください。

   ```text
        A                                      UNIQUE
        A          R TESTPFR
        A            TPKEY          6A         TEXT('Test key')
        A            TPVAL         10A         TEXT('Test value')
        A          K TPKEY
   ```

   **DDS(固定形式)は桁位置が意味を持ちます。** `A`は6桁目に置いてください。タブは使わないでください(`docs/style-guide.md`のとおり、この教材はタブを使わない方針です)。

2. `Rules.mk`に、`testpf.pf`をビルド対象として宣言する行を1行追加してください。上の`ZAISRV.MODULE: zaisrv.rpgle`と同じ形(`オブジェクト名.オブジェクト型: ソース・ファイル`)です。このパターンから類推して、オブジェクト型・オブジェクト名をどう書くべきか、自分で考えてみてください。

   <details><summary>答え</summary>

   ```text
   TESTPF.FILE: testpf.pf
   ```

   (`Rules.mk`の末尾に、この1行を追記します。)

   </details>

3. コミットしてpushし、`$HOME/zaisrv-clone`でpullします(実演Eのコミット・push・pullと同じ要領です)。

   ```sh
   git add testpf.pf Rules.mk
   git commit -m "Add TESTPF as a PF build target"
   git push zaisrv main
   ```

   ```sh
   cd $HOME/zaisrv-clone
   git pull origin main
   ```

4. `makei build`を実行します。

   ```sh
   /QOpenSys/pkgs/bin/bash -c 'cd $HOME/zaisrv-clone && export PATH=/QOpenSys/pkgs/bin:$PATH && /QOpenSys/pkgs/bin/makei build'
   ```

   次のとおり成功するはずです(実機確認済み)。

   ```text
   === Creating PF [testpf.pf] in <自分のユーザー名>1
   /QOpenSys/pkgs/lib/tobi/src/scripts/crtfrmstmf --ccsid *JOB  -f /home/<自分のユーザー名>/zaisrv-clone/testpf.pf -o TESTPF -l <自分のユーザー名>1 -c CRTPF -p AUT() DLTPCT(*NONE) OPTION(*EVENTF *SRC *LIST) REUSEDLT(*NO) SIZE() ALWUPD(*YES) TEXT('')
   TESTPF.FILE was created successfully!

   Objects:             0 failed 1 succeed 1 total
   Build Successful!
   ```

   **`ZAISRV`は今回ビルドされていません**(`2 succeed`ではなく`1 succeed`)。`zaisrv.rpgle`・`zaisrv.bnd`のどちらも直前のビルドから変更していないため、`makei`は`ZAISRV`をスキップし、新しく追加した`TESTPF`だけを対象にしました——増分ビルドが、意図どおり「変更したものだけ」を見分けている実例です。

   `crtfrmstmf`は、DDSソースから物理ファイルを作る、TOBi自身のスクリプトです(`CRTRPGMOD`/`CRTSRVPGM`のような素のCLコマンドではなく、`makei`側が用意した専用の変換手段)。

5. (任意・V3、この検証では未実施)5250で`DSPFFD FILE(<自分のユーザー名>1/TESTPF)`(02-02既習)を実行し、`TPKEY`・`TPVAL`という2フィールドが定義されていることを確認してください。

6. `TESTPF`は練習用のオブジェクトです。残しても実害はありませんが、片付けたい場合は`DLTF FILE(<自分のユーザー名>1/TESTPF)`で削除してかまいません。**`Rules.mk`の`TESTPF.FILE: testpf.pf`の行を残したままオブジェクトだけ削除すると、次回同じプロジェクトで`makei build`を実行したときに`TESTPF`が(対象オブジェクトが無い=古いと判定され)再作成される可能性が高いです**(一般的なmakeの意味論からの推測で、この組み合わせ自体はこのリポジトリでは実機確認していません)。完全に片付けたい場合は、`DLTF`と合わせて`Rules.mk`のこの行も削除してください。

## セルフチェック

- [ ] `iproj.json`の`objlib`がビルド先ライブラリーを制御することを説明できる。
- [ ] `Rules.mk`にターゲット行が無いと`makei build`が何もしない理由を説明でき、`Nothing to be done for 'all'`という同じメッセージが「ターゲット無し」と「本当のスキップ」の2つの意味を持ち得ることを説明できる。
- [ ] `ZAISRV`(07-05で手作業ビルド済み)を、中身を変えずに`makei build`で作り直せた。`DRIVER`を再実行し、07-05の実機メモと同じ10行が出ることも確認した。
- [ ] 変更なし→スキップ、変更あり→再ビルドの両方を、自分の手で確認した。
- [ ] 共有機でクリーン・ビルドを避けるべき理由を、増分ビルドの仕組みと結び付けて説明できる。
- [ ] `ZAISRV`が`myproject`ではなく別の新しいプロジェクトになっている理由を説明できる。
- [ ] `TESTPF`を`Rules.mk`に1行追加するだけで、`makei build`経由で作成できた。

## 片付け

- `$HOME/zaisrv-bare.git`・`$HOME/zaisrv-clone`(IBM i側)、およびPC側の`zaiproject`は、以後の第8部のレッスンでも使う可能性があるため、特別な事情がなければ残しておいてください。
- `makei`で作り直した`<自分のユーザー名>1/ZAISRV`はそのまま残してください——07-05から引き続き使われるオブジェクトで、中身は元と同じです。
- `<自分のユーザー名>1/TESTPF`は演習用のオブジェクトです。上の演習手順6のとおり、残しても削除してもかまいません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Build tool | ビルド・ツール(依存グラフに沿って一括ビルドする道具) |
| Declarative configuration | 宣言的な設定(手順ではなく「何が欲しいか」を書く設定) |
| Dependency graph | 依存グラフ(オブジェクト間の「何が何から作られるか」の関係) |
| Incremental build | 増分ビルド(変更が無いものはスキップし、変更があるものだけ作り直すビルド) |
| Clean build | クリーン・ビルド(全部消してゼロから作り直すビルド) |

次のレッスン(08-03)では、`rpglint`を使って`myproject`(`JUCSRV`)の規約違反を機械的に検出します。`ZAISRV`・`zaiproject`は08-03には登場しません。

## 実機メモ

- **TOBiバージョン3.2.1**: 第8部の見出し「`part08-02-makei-probe`: qsh直接呼び出しと`bash`経由呼び出しの比較が初めて成立し、`makei`(TOBi)が実際に動くことを確認」(1回目の接続)で、`bash -x /QOpenSys/pkgs/bin/makei --version`により確認しました(`TOBi version 3.2.1`)。同じ接続で、5250相当のqsh直接呼び出しは(`PATH`が実際に正しく通っていても)誤った「PATHが通っていない」という診断を出すことも確認しました。
- **`Rules.mk`がターゲット宣言ゼロだと何もビルドされない**: 見出し「`part08-02-makei-probe2`: 1回目の接続は2つの自作エラーで失敗、実際のmakeiビルドはまだ未確認」に続く2回目・3回目の接続(いずれも`make: Nothing to be done for 'all'`)、および真因が確定した見出し「`part08-02-makei-probe2`続報: 5回目の接続で真因が確定——`Rules.mk`自体がターゲット宣言ゼロだった」で確認しました。
- **コメント込みの`Rules.mk`を使ったビルドが成功したこと(ただしコメント文自身がバイト単位で無傷のまま転送されたかは、このログからは判定できません)**: 見出し「`part08-02-makei-probe2`続報: 6回目の接続でmakeiビルドがCONFIRMED SUCCESS、ただし未決事項が残る」に対応する接続(`work/verify/results/part08-02-makei-probe2-2026-09-29T04-03-47-896Z.json`の`sh:SETUP`→`---RULES-MK---`)で、`file`型のステップにより`templates/part08-project/Rules.mk`(現在の`templates/part08-zaisrv/Rules.mk`と分割前の同一ファイル、コメント込み)をIFSへ運び、ビルドに成功しています。**この結果ログを見ると、コメント部分の日本語の文字はすべて置換文字(`\u001a`)として記録されています。** ただし、これだけでは「IFS上のファイルの実バイト列が壊れていた」とは断定できません——**同じ接続の`sh:BUILD`セクションでは、ファイル転送を一切経由しない、makei自身がその場の標準出力に出すチェック・マーク記号も同じく`\u001a`として記録されており**、この置換がIFS上のファイル内容そのものの破損なのか、この検証セッションの出力キャプチャー自体が非ASCII文字を一様に`\u001a`へ変換しているだけなのかを、このログから切り分けることはできません。**したがって、この接続で確認できたのは「コメントが(内容の真偽を問わず)ビルドの成否に影響しない」ことだけであり、「コメント文自身がテンプレートとバイト単位で同一のまま転送された」ことは、このログからは判定できません。** 同じステップで、`iproj.json`も`description`・`includePath`・`preUsrlibl`・`postUsrlibl`を含む7フィールドすべてを持つ、テンプレートと同じ形が使われました。コメントを一切含まない2行だけの`Rules.mk`でも成功することは、下の「`.gitattributes`によるCRLF正規化」の`part08-02-makei`本番マニフェスト(`verify/part08-02-makei/manifest.json`のPCREPOステップ、python3バイナリー書き込みによる2行だけの`Rules.mk`)でも確認済みです。
- **`iproj.json`の`objlib`が実際にビルド先ライブラリーを制御する**: 空のライブラリーを対象にした見出し「`part08-02-makei-probe2`続報: 6回目の接続でmakeiビルドがCONFIRMED SUCCESS、ただし未決事項が残る」と、実際の開発ライブラリーを対象にした見出し「08-02: `part08-02-makei`——08-02のレッスン本文用の本番マニフェスト、git配送経路のCRLF正規化と実ライブラリーでの再ビルドをCONFIRMED SUCCESS」の両方で確認しました。**`curlib`単独の効果は、この検証では`objlib`と同じ値に固定していたため切り分けて確認できていません。**
- **既存の(makei以外で作った)`ZAISRV`の再ビルド**: 使い捨てライブラリーでの確認は見出し「`part08-02-makei-probe3`最終確認: 2回目の接続で08-02の中核シナリオがCONFIRMED SUCCESS」、実際にPart 7由来の本物の`ZAISRV`が存在するライブラリーでの確認は見出し「08-02: `part08-02-makei`——…」で行いました。
- **増分ビルド(両方向)**: 「変更なし→スキップ」は見出し「`part08-02-makei-probe2`続報: 6回目の接続でmakeiビルドがCONFIRMED SUCCESS、ただし未決事項が残る」の末尾、【advisor指摘、7回目の接続で一部解消】という段落(6回目の接続の直後に行った7回目の接続)で確認しました。「変更あり→再ビルド」は見出し「`part08-02-makei-probe3`最終確認: 2回目の接続で08-02の中核シナリオがCONFIRMED SUCCESS」の`EDITSRC`→`BUILD2`で確認しました。
- **フラットなプロジェクト配置**: 見出し「`part08-02-makei-probe2`続報: 6回目の接続でmakeiビルドがCONFIRMED SUCCESS、ただし未決事項が残る」末尾の「まだ未検証のまま残っていた点」の(2)で、ネストした構成(`SUBDIRS`)は未検証のままである一方、フラットな構成を採用する設計判断を記録しています。見出し「08-02: `part08-02-makei`——…」が、実際にこのフラットな構成でCONFIRMED SUCCESSまで確認しました。
- **`CPYTOSTMF`(`STMFCCSID(1208) ENDLINFMT(*LF)`)の組み合わせ**: 見出し「08-02: `part08-02-makei`——…」のマニフェストが、07-05由来のメンバーからこの組み合わせでストリーム・ファイルを書き出し、そのままgit配送・makeiビルドに使えることを確認しました。
- **`.gitattributes`によるCRLF正規化**: 見出し「08-02: `part08-02-makei`——…」で、`Rules.mk`をわざとCRLFで書いてコミットし、gitの`CRLF will be replaced by LF`という警告と、クローン後のバイト単位での確認(`\r`が消えていること)の両方で確認しました。**この接続の`Rules.mk`はコメントを一切含まない2行(`ZAISRV.MODULE: zaisrv.rpgle\r\n`・`ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd\r\n`)をpython3のバイナリー書き込みで用意したもので、この2行だけでもビルドは問題なく成功しています**(`verify/part08-02-makei/manifest.json`のPCREPOステップ)。
- **`DRIVER`の再実行によるmakei再ビルド後の振る舞い確認**: `part08-02-driver-bsh`(1回目の接続)で、`part08-02-makei`がmakei経由で再ビルドした`<USER>2`の`ZAISRV`に対して、実際に`TXRESET`→`CALL PGM(DRIVER)`→出力回収→`TXRESET`を実行しました。出力は`0-BASELINE`〜`7-NOTFOUND-RSV`の10行すべてが、07-05自身の実機メモに記録された値と1文字も違わず一致しました(**再コンパイル不要という設計上の期待どおり、実際に動作レベルでCONFIRMED SUCCESS**)。ただし、この接続の出力回収は`CPYSPLF FILE(QSYSPRT) ... JOB(*)`では`CPF3303`(このジョブに`QSYSPRT`という名前の保存済みスプール・ファイルが無い)で失敗し、実際にはコマンドの標準出力そのもの(このハーネスのSSH接続が捕捉する生のジョブ出力)に印字内容がそのまま現れていたものを直接読み取りました——このハーネス固有の挙動で、5250で`WRKSPLF`を使う学習者には無関係です。
- **`bsh`は語頭の`~`を一切展開しない**: 最初の`part08-02-driver-bsh`の`echo A=~`形は、`~`が`echo`の引数の途中(語頭ではない)にあったため、POSIXのチルダ展開規則の対象外で何も判別できていませんでした(advisor指摘)。改めて`part02-bsh-tilde-redirect`で語頭の`~`を試したところ、`echo ~`・`echo ~/x`はそのまま印字され、決定的な証拠として`cd ~/vfy && pwd`が`~/vfy: A file or directory in the path name does not exist.`で失敗しました(`$HOME/vfy`はこのハーネスが毎回作る、確実に存在するディレクトリーです)。02-04の`export PATH=...`結合形バグと同じ種類の、bsh固有の実機バグです。このレッスンの本文は、IBM i側で直接実行するコマンドではすべて`~`ではなく`$HOME`を使っています(`bash -c '...'`の中身はbash自身が展開するため元々問題ありません)。
- **`makei build`の呼び出し形**: `bash -c '...'`という形自体は見出し「`part08-02-makei-probe`: …」(1回目)・「`part08-02-makei-probe2`: …」(2回目以降)・「08-02: `part08-02-makei`——…」で繰り返し確認しています。**02-04が確立した`bsh`の2段階`export`形(見出し「第8部08-02(発端)→第2部02-04(本体の実バグ): `bsh`は`export PATH=...`という結合形を受け付けない——既に公開済みの02-04自体のバグ」で確認済み)と、`makei build`を同じ接続で組み合わせて試したことはまだありません**——確認したのは`bsh`+`makei --version`(バージョンだけ)と、`bash -c`+`makei build`(ビルドそのもの)という別々の組み合わせです。このレッスンは、実際にビルドまで確認できている`bash -c`形をそのまま採用しています。
- **「PFを追加する」演習**: 見出し「第8部08-02/08-03: `part08-02-testpf`の2回目の接続——PF演習はCONFIRMED SUCCESS…」で最初に確認し、見出し「08-02: `part08-02-makei`——…」で同じ`zaisrv`プロジェクトに対しても再確認しました(`0 failed 1 succeed 1 total`——`ZAISRV`が変更されていない状態でのビルドだったため、`TESTPF`だけが対象になっています)。
- **`makei cvtsrcpf`**: 見出し「`part08-02-makei-probe2`続報: 4回目の接続で、TOBi自身の完全なドキュメント一式とinit/cvtsrcpfサブコマンドを発見」で、TOBi自身のドキュメントとヘルプ出力からサブコマンドの存在を確認しましたが、**実際に実行してはいません(V3)**。このレッスンでは代わりに`CPYTOSTMF`を使っています。
- **本文とこのレッスンの検証との構成上の違い(正直に書きます)**: 上の技術的な主張(`objlib`の効き方・既存オブジェクトの再ビルド・増分ビルド・`.gitattributes`のCRLF正規化・`CPYTOSTMF`の組み合わせ・「PFを追加する」演習)はいずれも実機で個別に確認済みですが、**それらを1つの接続の中で本文どおりの順序(PC→push→clone→クローン側でCPYTOSTMF→クローン側でcommit・push→PCでpull→ビルド)でつないで実行したことはありません。**
  - 見出し「08-02: `part08-02-makei`——…」の検証は、SSH接続だけで完結するIFS内リハーサル(08-01の「B. 代替」と同じ考え方)です。`Rules.mk`・`.gitattributes`と`zaisrv.rpgle`・`zaisrv.bnd`(CPYTOSTMF経由)を、PC側の役を務める1つのディレクトリーの中でまとめて用意してから最初のコミットを行っており、本文のように「クローン側で2回目のコミット・pushを行う」という手順そのものは踏んでいません。
  - この接続でgit配送された`iproj.json`は`{"version":"0.0.1","objlib":"...","curlib":"..."}`という3フィールドだけの最小形でした。7フィールドすべてを持つテンプレートと同じ形自体は、上のとおり`part08-02-makei-probe2`の6回目の接続(git配送を経ない、`file`ステップによる直接転送)で確認済みですが、**「7フィールドの`iproj.json`をgit配送した」という組み合わせそのものは確認していません**(`description`・空配列3つが無くても`objlib`/`curlib`は同じ値なので、動作は変わらないはずですが未確認です)。
  - `testpf.pf`と`Rules.mk`への`TESTPF.FILE: testpf.pf`の追記は、**どの接続でもgitを経由していません。** `testpf.pf`は既存のDDSメンバーから`CPYTOSTMF`で書き出したもの、`Rules.mk`への追記はpython3によるバイナリー追記です。本文が指示する「PCで入力→push→クローン側でpull→ビルド」という演習の手順そのものは、このリポジトリでは検証していません(V3)。
  - **個々の要素(git push/clone経路、`CPYTOSTMF`の変換結果、`.gitattributes`のCRLF正規化、`makei build`の挙動)はいずれもV2で確認済みですが、本文が示すこの具体的な手順の並び・PC↔IBM i間のファイルの行き来そのものは、このリポジトリでは個別に検証していません(V3)。**
- **本物のPCからPUB400への実際のgit push**は、08-01自身の実機メモが明記するとおり、このハーネスの検証方法では構造的に確認できません。08-01を参照してください。
- **実際にコンパイル・実行されたライブラリーは`<USER>2`(または使い捨ての`<USER>B`)でした**(この教材の検証ハーネス自身の方針、`docs/probes.md`)。学習者向けの本文では、この教材のこれまでの慣例どおり`<自分のユーザー名>1`への手順として書いています。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
