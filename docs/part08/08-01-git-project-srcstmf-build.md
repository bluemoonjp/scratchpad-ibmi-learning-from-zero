# 08-01 gitプロジェクトとSRCSTMFビルド

> 所要時間: 90分(長め)/ 前提レッスン: 07-05 / 目標番号: 6 / 観測方法: `DSPJOBLOG`(コンパイルの成功メッセージ・`CALL PGM`の出力)・`git log`/`git diff`(pushの前後比較)/ 道具: PC自身のgit/SSHクライアント(実演の主経路)、SSH(02-04で確立済みの接続方法、IFS内リハーサルの代替経路)、5250(`CRTRPGMOD`/`CRTSRVPGM`のコンパイル・実行確認)/ 同時接続数: 5250×1 + PC側のgitクライアントが張るSSH接続(02-04のログインSSHとは別の接続経路です。IFS内リハーサルだけで済ませる場合はSSH×1で代替できます)/ 作る・変えるオブジェクト: `/home/<USER>/pub400-bare.git`・`/home/<USER>/pub400-clone`(A、新規)・`/home/<USER>/rehearsal-pc`・`/home/<USER>/rehearsal-bare.git`・`/home/<USER>/rehearsal-clone`(Bを試す場合のみ、練習用)・`<USER>1/JUCSRV`(既存の*MODULE→*SRVPGM。中身をSRCSTMF経由で作り直しますが、オブジェクトの中身自体は07-02/07-03と同じです)。PC側にも新しい小さなgitプロジェクトができますが、PUB400上のオブジェクトではありません / DBVER: 1 / 依存するプローブ: P08(SSH・PASEのPATH既定値、02-04で確認済み)・P16(設計時点の依存プローブ。実際にはP16自体の手順〔対象5コマンドをF4で開くだけの存在確認〕ではなく、`CRTRPGMOD`/`CRTSRVPGM`の`SRCSTMF`パラメーターを`part08-01-git-srcstmf`接続で実際に実行して確認しました)・P25(`CRTSQLRPGI`の`/COPY`・`RPGPPOPT`。本レッスンの`JUCSRV`は`/COPY`を使わないため、このレッスン自体では未使用)/ PTF 依存: なし / 容量の目安: 数MB程度(A・Bとも、自分の小さなプロジェクトのみです)

## ゴール

- PCの新しいgitプロジェクトを、SSH経由でPUB400へ安全にpushできる(非bareリポジトリへ直接pushする危険を、ベア・リポジトリーで避けられる)。
- メンバーを1つも作らず、IFS上のソース(SRCSTMF)から`CRTRPGMOD`/`CRTSRVPGM`で直接ビルドできる。
- 既存の`JUCSRV`(07-02/07-03の成果物)を、**同じ最終オブジェクトとして、新しいビルド経路で**作り直せる。

## ウォームアップ

<details><summary>前回までの復習(07-02/07-03/02-03)</summary>

1. (07-02)`F0702A`/`F0703A`は、呼び出す`JUCSRV`のライブラリー名をソースに焼き込んでいましたか?
2. (07-03)`CRTSRVPGM`を`EXPORT(*SRCFILE)`で実行するとき、何を読んでエクスポート一覧(シグネチャー)を決めますか?
3. (02-03)CCSID 1208・273は、それぞれ何を表す番号でしたか?

答え: 1. いいえ。`ctl-opt bnddir('JUCSRVBD')`という非修飾名の`*BNDDIR`を経由し、実際にどのライブラリーの`JUCSRV`が使われるかは、そのプログラムが活動化される時点の`*LIBL`で決まります。ライブラリー名は一切コードに焼き込まれていません。 2. `SRCFILE`/`SRCMBR`で指定したバインダー・ソース・メンバー(`QSRVSRC/JUCSRV`)です。`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`という3コマンドで書かれています。 3. 1208はUnicode(UTF-8)系のCCSID、273はドイツ語圏向けのEBCDIC CCSIDです(このPUB400の既定と一致)。IFSのファイルにはこのCCSIDがタグとして付いており、改行コード(CR混入の危険)と並んで、ソースを取り込むときに注意が必要な要素でした。

</details>

## なぜ学ぶか

第7部の案内文(`docs/part07/index.md`)は、この部で扱わないこととして「現代的な開発環境そのもの(git・SRCSTMFビルド・makei等は第8部)」とはっきり予告していました。ここまでの第1部〜第7部では、ソースは常にライブラリーのソース物理ファイルの中の**メンバー**として存在し、教材からの取り込みも`CPYFRMSTMF`でメンバーへコピーする形でした(02-04で取り込んだ`~/ibmi-kyozai`も、あくまで「メンバーへコピーするための一時置き場」という扱いです)。

しかし実際の現場のILE開発では、ソースはPC側のgitリポジトリーで管理され、IBM i上のメンバーを経由せず、IFS上のストリーム・ファイル(**SRCSTMF**)から直接コンパイルするやり方が広がっています。この課では、07-02/07-03で組み立てた`JUCSRV`(`getCustName`・`pingJucsrv`・`countCustOrders`をエクスポートする*SRVPGM)を題材に、**メンバー経由ではなく、PCのgitからpushしたIFS上のソースから、まったく同じオブジェクトを作り直します。** 「同じ物を、新しい方法で作る」という対比が、この課全体の軸です。

同時に、PCから共有機(PUB400)へ`git push`すること自体が持つ固有の危険(非bareリポジトリーへの直接pushの危険)と、`docs/style-guide.md`が定める「認証に2回失敗したら接続をやめる」という運用規律をSSH鍵の場面でどう守るかも、この課で扱います。

## 新出

- 中核概念:
  1. **ソースの単位が、メンバーからIFSストリーム・ファイル(SRCSTMF)に変わります。** メンバー(ソース物理ファイルの中の1つの実体)もSRCSTMF(IFS上の1つのファイル)も、RPGコンパイラーにとっては同じソースの2つの置き場所に過ぎません——中身が同じなら、同じオブジェクトができます(下の「実演」で、`JUCSRV`を両方の経路で作り比べます)。
  2. **PCからPUB400への`git push`は、「作業コピー(working copy)を持つ通常のリポジトリーへの直接push」という固有の危険を持ちます。** 通常の(非bareの)リポジトリーは、チェックアウトした作業ディレクトリーを同時に持っています。そこへ外部から直接pushすると、作業ディレクトリーの中身とpush後のHEADとの間に食い違いが生まれ、gitが混乱します。この教材は、作業コピーを持たない**ベア・リポジトリー**(`git init --bare`)をPUB400側に置くことで、この危険をそもそも起こさない形にします。
  3. **SSH鍵を使って認証する場合、鍵を複数提示すると認証失敗としてカウントされ得ます**(**一般知識、要確認**: ssh-agentに複数の鍵が登録されていると、1回の接続の中でそれらが順に試され、正しい鍵にたどり着く前の失敗分もサーバー側が数えることがある、という一般的なSSH運用知識です。`docs/probes.md`の実測は「短時間の多数回接続でSSHが不通になった」という接続**数**の実測であり、鍵の**本数**そのものに関する実測ではないため、このリポジトリでは未確認のまま「一般知識」として扱います)。`docs/style-guide.md`が明記する「認証に2回失敗したら接続をやめる」という運用規律をSSH鍵の場面でも守るため、`IdentitiesOnly yes`で使う鍵を1本に絞ります。
- 構文:
  1. `git init --bare`(この教材の決定: 非bareリポジトリーへの直接pushを安全にするもう1つの選択肢`receive.denyCurrentBranch=updateInstead`は、PUB400実機(git 2.47.0)での動作を一次資料で確認できないため、bareに一本化します。詳しくは下の「説明」参照)。
  2. `~/.ssh/config`の`IdentitiesOnly yes`テンプレート(`templates/part08-project/.ssh-config.example`)。
  3. `CRTRPGMOD`/`CRTSRVPGM`の`SRCSTMF`パラメーター(`CRTRPGMOD`側は`TGTCCSID(*JOB)`を伴わせる必要があります——詳しくは下の「説明」参照)。
  4. `INCDIR`(`/COPY`ディレクティブを使うソースのための、コンパイラーのコピー・ファイル検索パス追加指定です。**今回作り直す`JUCSRV`は`/COPY`を1つも使わないため、この構文はこのレッスンの実演・演習では実際に試せません**——存在と役割を知っておくだけの項目です)。
  5. PC側新規リポジトリーの`.gitattributes`(LF強制。`templates/part08-project/.gitattributes`)。

**読解用(新出に数えない)**:

- `receive.denyCurrentBranch=updateInstead`: 非bareリポジトリーへの直接pushを許す、もう1つのgitの設定です。名前だけ知っておいてください(上の構文項目(1)参照)。
- `git config remote.<名前>.receivepack`/`uploadpack`: リモート側で実行するプログラムのパスを明示する設定です(**一般知識、要確認**。下の「説明」のトラブルシューティング参照)。
- `makei`・`iproj.json`・`rpglint`: 08-02・08-03でそれぞれ扱います。

**既習の応用(新出に数えない)**:

- `git clone`/`git pull`(02-04)。今回は`git init`/`git add`/`git commit`/`git remote add`/`git push`/`git log`/`git diff`という、一般的なgitの操作を新しく使いますが、これらはIBM i固有の新しい構文ではなく、02-04で前提にした「gitという道具そのもの」の自然な延長として扱い、新出構文の数には数えません。
- `ADDLIBLE`(01-05)。コンパイル・ジョブの`*LIBL`に`<USER>1`を含める場面で使います。
- `CRTRPGMOD`/`CRTSRVPGM`の基本形、`ACTGRP(*CALLER)`、`*BNDDIR`経由の`*LIBL`解決(07-02/07-03)。この課で変わるのは「ソースをどこから読むか」だけで、モジュール→サービス・プログラムという2段階ビルドの構造自体は同じです。
- CCSID 1208・273という数字そのもの(02-03)。この課では、この数字がコンパイル・コマンドの挙動にどう影響するかという新しい場面に応用します。

## 説明

### ソースの置き場所: メンバーとSRCSTMFは同じコンパイラーへの2つの入口

`CRTRPGMOD`(RPG IVモジュールを作るコマンド)は、ソースの場所を指定する方法を2つ持っています。

- `SRCFILE`/`SRCMBR`: ソース物理ファイルの中のメンバーを指定する、これまでどおりの方法。
- `SRCSTMF`: IFS上のストリーム・ファイルのパス名を直接指定する方法(一次資料: `cl_commands_75.txt`、`CRTRPGMOD`のパラメーター表に`SRCSTMF | Source stream file | Path name | Optional`として明記)。

どちらを使っても、コンパイラー自身は同じです。**メンバーもSRCSTMFも、コンパイラーから見れば「文字の並びが書かれた入れ物」という点で同じであり、中身(文字の並び)さえ同じなら同じオブジェクトができます。** この課で行うのは、07-02/07-03で`SRCFILE(<USER>1/QRPGLESRC) SRCMBR(JUCSRV)`として渡していたのと**中身が同じ**`jucsrv.rpgle`を、今度は`SRCSTMF('/home/<自分のユーザー名>/.../jucsrv.rpgle')`としてIFSから直接渡すことです。

`CRTSRVPGM`(サービス・プログラムを作るコマンド)にも`SRCSTMF`パラメーターがありますが、**用途がまったく違います。** 一次資料(`cl_commands_75.txt`)によれば、`CRTSRVPGM`の`SRCSTMF`は"Export source stream file"(エクスポート・ソース・ストリーム・ファイル)——つまり07-03で`QSRVSRC/JUCSRV`メンバーに書いたバインダー言語(`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`)を、メンバーの代わりにIFS上のストリーム・ファイルから読む、という指定です。**モジュールのソース(RPGのコード)の話ではありません。** この課では、`CRTRPGMOD`の`SRCSTMF`は`jucsrv.rpgle`を、`CRTSRVPGM`の`SRCSTMF`は`jucsrv.bnd`(バインダー・ソース)を、それぞれ指すことになります。

### PC側: 自分の新しいgitプロジェクトを作る

02-04で取り込んだ`~/ibmi-kyozai`は、あくまで**この教材自身**のクローンでした。この課では、それとは別に、**学習者自身の新しいプロジェクト**をPC上に作ります。中身は`JUCSRV`一式(07-02/07-03で作ったのと同じロジックのソース)だけの小さなものです。

出発点として、`templates/part08-project/.gitattributes`を使います。

```text
# 既定は LF に正規化する(この教材のトップ .gitattributes と同じ方針)。
* text=auto eol=lf

# RPG III / RPG IV(固定形式)/ CL / DDS は桁位置が意味を持つため、
# CR が 1 バイトでも混入すると壊れる。明示的に LF を強制する。
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

02-03で確認したとおり、固定形式ソース(RPG III・固定形式RPG IV・CL・DDS)は桁位置がそのまま意味を持つため、`CR`が1バイトでも混じると壊れます。この`.gitattributes`は、対象の拡張子を**gitがチェックアウト・コミットする時点でLF改行に正規化する**という指定です(一番上の`* text=auto eol=lf`が既定、下の個別行は固定形式ソースで特に重要な拡張子を明示しています)。`JUCSRV`は`**FREE`のRPGなので改行コード自体には桁位置ほどの意味はありませんが、この教材は配布ソース全体をLFに統一する方針(`docs/style-guide.md`)なので、新しいプロジェクトでも同じ方針を`.gitattributes`で明示します。

### なぜベア・リポジトリーなのか: 非bareへの直接pushの危険

ふつうに`git init`して作ったリポジトリー(**非bare**リポジトリー)は、`.git`ディレクトリーと、チェックアウトされた**作業コピー**を同時に持っています。そこへ外部からpushすると、pushでHEADの位置が変わっても、作業コピーのファイル自体は自動的には書き換わりません——作業コピーとリポジトリーの記録が食い違った状態になります。標準的なgitは既定でこの種のpushを拒否します(`receive.denyCurrentBranch`の既定動作、一般的なgitの仕様です)が、この既定を変えて受け入れる設定(`receive.denyCurrentBranch=updateInstead`)も存在します。

この教材は、この危険を設定に頼らず構造で避ける方針を取ります。**ベア・リポジトリー**(`git init --bare`)は、作業コピーを一切持たない、`.git`の中身だけのリポジトリーです。作業コピーが無いので、外部からのpushで「作業コピーとの食い違い」がそもそも発生しません。ビルドに使う作業コピーは、ベア・リポジトリーとは**別の場所**に`git clone`して用意します。

```sh
git init --bare -b main ~/pub400-bare.git
```

`receive.denyCurrentBranch=updateInstead`という代替設定名も、読み物として知っておいてください(上の「新出」参照)。ただし**この教材ではこの設定を一切使いません**——PUB400のgitバージョン(`git --version`で確認済み、2.47.0)でこの設定が実際にどう動くかは、gitのマニュアル自体がこのリポジトリの一次資料に含まれていないため確認できておらず、恒久的にV3(未検証)のままになる見込みだからです。この課の演習は、必ず`git init --bare`の経路で行ってください。

### SSH鍵を使う場合の注意: `~/.ssh/config`と`IdentitiesOnly yes`

これまでのSSH接続(02-04)はパスワード認証でした(`docs/style-guide.md`が「SSHはパスワード認証を基本とし」と定めるとおりです)。`git push`も、ターミナルから手で打つ分にはパスワード認証のままで構いません。ただし、何度もpushする開発ワークフローでは、毎回パスワードを打たずに済むSSH鍵認証を使いたくなる場面が出てきます。鍵認証に切り替える場合は、次の点に注意してください。

- まだ鍵を持っていなければ、PC側で`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`のように生成し、公開鍵(`~/.ssh/id_ed25519.pub`)の中身をPUB400側の`~/.ssh/authorized_keys`に登録します(登録方法自体はこの教材の対象外です。ホスティング元の案内に従ってください)。
- **`ssh-agent`に複数の鍵が登録されていると、接続のたびにそれらが順に試され、正しい鍵にたどり着く前の失敗分も数えられることがあります**(上の「新出」中核概念(3)参照)。`docs/style-guide.md`の「認証に2回失敗したら接続をやめる」という運用規律を守るため、`~/.ssh/config`に`IdentitiesOnly yes`を指定し、使う鍵を1本に絞ります。

```text
Host pub400
    HostName pub400.com
    Port 2222
    User your_username_here
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

(`templates/part08-project/.ssh-config.example`。`your_username_here`は自分のPUB400ユーザー名に置き換え、PC側の`~/.ssh/config`に追記してください。)この`Host pub400`という別名を設定しておくと、`ssh pub400`や、gitのscp形式のURL(`pub400:パス`)で、ポート番号・ユーザー名・鍵を毎回書かずに済みます。

### pushが失敗したら: リモート側のPATH(一般知識、要確認)

`git push`は、リモート側(PUB400)で`git-receive-pack`という補助プログラムを、SSH経由の**非対話コマンド**として直接実行します。P08(02-04で確認済み)のとおり、PUB400のSSHログイン直後の既定`PATH`には`/QOpenSys/pkgs/bin`(gitの実体がある場所)が含まれていません。02-04はこれを`~/.profile`への追記で解決しましたが、**`git push`が使うこの非対話コマンドの実行経路が`~/.profile`を必ず経由するとは限りません**——このリポジトリでは未検証です。

もし`git push`が`git-receive-pack: command not found`のようなメッセージで失敗したら、リモート側で実行するプログラムのパスを、gitの設定で直接教えてください(`git clone`/`git pull`側で同様の症状が出た場合は`uploadpack`も同様です)。

```sh
git config remote.pub400.receivepack /QOpenSys/pkgs/bin/git-receive-pack
git config remote.pub400.uploadpack /QOpenSys/pkgs/bin/git-upload-pack
```

### CCSIDの壁: `TGTCCSID(*SRC)`と`TGTCCSID(*JOB)`

`git clone`でIFSにチェックアウトされたファイルは、CCSID 1208(UTF-8)としてタグ付けされます(PASEのgit自身がこの形で一貫してファイルを作成します)。ところが`CRTRPGMOD`の`TGTCCSID`パラメーターの既定値は`*SRC`で、一次資料(`cl_commands_75.txt`)によれば次のとおりです。

> `*SRC`: The source is read in the CCSID of the primary source file, or if the file is an IFS file with an ASCII CCSID, the EBCDIC CCSID related to the ASCII CCSID. This is the default.

つまり既定では「ソース自身のCCSIDで読む」だけなのですが、**CCSID 1208のようなUnicode系CCSIDは、この既定動作の対象外です。** 何もパラメーターを付けずに`git clone`直後のIFSファイルを`CRTRPGMOD`にかけると、次のメッセージで失敗します(実機確認済み)。

```text
RNS9380: The source file CCSID 1208 is a Unicode CCSID which cannot be
used with TGTCCSID(*SRC).
```

対処は、`TGTCCSID(*JOB)`を明示することです。一次資料の該当箇所は次のとおりです。

> `*JOB`: The source is read in the job CCSID. If the job CCSID is 65535, the source is read in the default CCSID of the job.

`*JOB`を指定すると、コンパイラーはソース・ファイル自身のCCSIDタグ(1208)を手掛かりに、ジョブのCCSIDへ変換してから読み込みます——単に「タグを無視する」のではなく、実際に変換を試みる指定です。このリポジトリの実機確認でも、この組み合わせ(`git clone`でチェックアウトした本物のUTF-8/LFファイル + `TGTCCSID(*JOB)`)で正しくコンパイルが成功しています(下の「実機メモ」参照)。

| メッセージ | 原因 | 対処 |
|---|---|---|
| `RNS9380` | `CRTRPGMOD`の既定`TGTCCSID(*SRC)`は、CCSID 1208(UTF-8)のようなUnicode系CCSIDを受け付けない | `TGTCCSID(*JOB)`を明示する |

なお`CRTSRVPGM`には、そもそもCCSID関連のパラメーターが1つもありません(一次資料`cl_commands_75.txt`のパラメーター表全体で確認済み)。実機確認でも、`CRTSRVPGM`の`SRCSTMF`(バインダー・ソースを読む方)には何も指定せずに成功しています——`CRTSRVPGM`のバインダー言語の読み込みは、`CRTRPGMOD`のRPGソース読み込みとは別の扱いのようです(この違いの内部的な理由までは、このリポジトリでは未確認です)。

### `*LIBL`の壁: `ADDLIBLE`を忘れずに

`jucsrv.rpgle`は`TOKUIM`・`JUCHUM`という外部記述ファイルを(ライブラリー名を修飾せずに)参照しています。`CRTRPGMOD`は、コンパイルの時点でこれらの外部記述を`*LIBL`から探します——ソースがメンバーから来ようとSRCSTMFから来ようと、この探し方自体は変わりません。コンパイル・ジョブの`*LIBL`に対象ライブラリーが見当たらないと、`TOKUIM`・`JUCHUM`の外部記述が解決できず、参照しているファイルの数だけ次の形のメッセージ(`RNF2120`、重大度40)が記録されます(実機確認済み。`jucsrv.rpgle`は2ファイルを参照するため、実際には2行出ます)。

```text
RNF2120: External descriptions for file TOKUIM not found; file is
ignored.
RNF2120: External descriptions for file JUCHUM not found; file is
ignored.
```

**5250の対話ジョブでは、通常`<USER>1`が現行ライブラリー(`*CURLIB`)として`*LIBL`に入っています**(01-04のとおり、サインオン時の既定です)。現行ライブラリーはユーザー部より先に探されるため(01-05のとおりです)、`<USER>1`にある`TOKUIM`/`JUCHUM`は通常問題なく見つかります。`CHGCURLIB`で現行ライブラリーを変えている場合や、`SBMJOB`で投入したバッチ・ジョブのような対話式でない実行経路では、`ADDLIBLE`でユーザー部へ明示的に追加する必要があります。まず`DSPLIBL`で、`<USER>1`が現行ライブラリーにも`*LIBL`のどこにも見当たらないことを確認してから、次のように追加してください。

```text
ADDLIBLE LIB(<自分のユーザー名>1) POSITION(*FIRST)
```

| メッセージ | 原因 | 対処 |
|---|---|---|
| `RNF2120` | 外部記述ファイル(`TOKUIM`/`JUCHUM`)がコンパイル・ジョブの`*LIBL`から見つからない | `DSPLIBL`で確認し、無ければ`ADDLIBLE`で対象ライブラリーを`*LIBL`に入れてからコンパイルし直す |

### 試せない構文: `INCDIR`

`CRTRPGMOD`には`INCDIR`というパラメーターもあります。一次資料(`cl_commands_75.txt`)によれば、これは`/COPY`ディレクティブで参照するコピー・ファイルを探す、追加の検索ディレクトリーを指定するものです(既定`*NONE`でもソース自身のディレクトリーは常に検索されます)。**ただし今回作り直す`jucsrv.rpgle`は`/COPY`ディレクティブを1つも使っていないため、`INCDIR`はこのレッスンの実演・演習では実際に使う場面がありません。** 存在と役割だけ知っておいてください。将来、`/COPY`で分割したソースを扱うときに戻ってくる項目です。

## 実演

**この実演で作る`JUCSRV`(*MODULE・*SRVPGM)は、実機での実行確認(V2)まで済んでいます。** ただし実機で実際に検証されたのは、下の「A」(本物のPCからの接続を要するため、このリポジトリの検証ハーネスでは構造的に確認できません)ではなく、「B」に相当するIFS内リハーサルを**構成する個々の要素**(ベア・リポジトリー+cloneという経路、SRCSTMFビルドのコマンド自体)です。「B」節が指示するこの具体的な手順そのもの(`cp`によるコピー)は、個別には検証していません。詳しくは下の「実機メモ」の区別を必ず読んでください。

**A・Bどちらか一方だけを行えば、上の「ゴール」の2つ目・3つ目(SRCSTMFからのJUCSRVビルド、同じオブジェクトの作り直し)は達成できます。** ただし1つ目のゴール(本物のPCからPUB400への安全なpush)は、Aでしか確かめられません——Bは本物のPCを使わない代替リハーサルです。PCでgit・SSHがすぐ使える人はAを、まだ準備できていない人はまずBで練習し、あとでAに進んでください(下の「演習」はAを前提にします)。Aは`~/pub400-clone`、Bは`~/rehearsal-clone`というIFS上のディレクトリーに、それぞれ`jucsrv.rpgle`・`jucsrv.bnd`が揃った状態になります——下のC・Dは、どちらのディレクトリーに対しても同じ手順です(コマンド例は`~/pub400-clone`で示すので、Bだけを行った場合は`~/rehearsal-clone`と読み替えてください)。

### A. 本筋: PCからPUB400へのgit push

1. PCに、新しい空のディレクトリーを作り、gitリポジトリーとして初期化します。

   ```sh
   mkdir myproject && cd myproject
   git init -b main
   ```

2. `templates/part08-project/.gitattributes`をこのプロジェクトのルートにコピーします(上の「説明」で見た中身のファイルです)。`src/qrpglesrc/`・`src/qsrvsrc/`という2つのサブディレクトリーも作っておきます。

3. この教材のリポジトリーをPCにも`git clone`し(`~/ibmi-kyozai`はPUB400側だけの話です。PC側にも同じリポジトリーをクローンして構いません)、`src/qrpglesrc/jucsrv.rpgle`・`src/qsrvsrc/jucsrv.bnd`の2ファイルだけを、`myproject`の同じ名前のサブディレクトリーへコピーします。教材のgit履歴は持ち込みません——単なるファイル・コピーです。

4. コミットします。**まだPCでgitのユーザー名・メール・アドレスを設定したことがなければ、最初の`git commit`の前に一度設定してください**(無指定だと`git commit`は「Please tell me who you are」で失敗します)。既に他のプロジェクトで設定済みなら、この手順は不要です。

   ```sh
   git config --global user.name "自分の名前"
   git config --global user.email "自分のメール・アドレス"
   git add .gitattributes src
   git commit -m "Initial JUCSRV project"
   ```

5. **SSH鍵認証を使う場合は**、PC側の`~/.ssh/config`に、上の「説明」で見た`Host pub400`のエントリーを追記します(`your_username_here`は自分のユーザー名に置き換え)。パスワード認証のまま進める場合はこの手順を飛ばしてください(手順7で使うリモートURLが変わります)。

6. SSH(02-04で確立済みの接続方法で構いません)で接続し、PUB400側にベア・リポジトリーを作ります。

   ```sh
   git init --bare -b main ~/pub400-bare.git
   ```

7. PC側に戻り、リモートを登録してpushします。

   手順5で`Host pub400`を設定した場合:

   ```sh
   git remote add pub400 pub400:pub400-bare.git
   git push pub400 main
   ```

   `Host pub400`のエイリアスにより、ポート番号・ユーザー名・鍵は`~/.ssh/config`から自動的に補われます。パスワード認証のまま進める場合(手順5を飛ばした場合)は、ポート番号・ユーザー名を書いたリモートURLを使います。

   ```sh
   git remote add pub400 ssh://<自分のユーザー名>@pub400.com:2222/~/pub400-bare.git
   git push pub400 main
   ```

   (`<自分のユーザー名>`は自分のユーザー名に置き換えてください。パスワードを尋ねられたら入力します。)**もし`git-receive-pack: command not found`のようなメッセージで失敗したら**、上の「説明」の「pushが失敗したら」を参照してください。

8. もう一度SSHで接続し、ビルド用の作業クローンを作ります(ベア・リポジトリー自身には作業コピーが無いため、ビルドには**別の**クローンが要ります)。

   ```sh
   git clone ~/pub400-bare.git ~/pub400-clone
   ```

### B. 代替: PUB400のIFS内だけで練習する(PCの準備がまだの場合)

**この経路は、A(本筋)と中身は同じ小さなプロジェクトを、PUB400のIFS内だけで(SSH接続だけで)用意する簡略版です。** ベア・リポジトリー+cloneという経路と、次のC・DのSRCSTMFビルドの手順そのものを、PCの用意を待たずに練習できます。Aで使う`~/pub400-bare.git`・`~/pub400-clone`とは別の名前を使うので、あとでAを行うときに衝突しません。

1. SSH(02-04で確立済みの接続方法)で接続します。
2. 練習用の作業ディレクトリーを作り、`git init`します(ベアではない、ふつうのリポジトリーです)。

   ```sh
   mkdir -p ~/rehearsal-pc/src/qrpglesrc ~/rehearsal-pc/src/qsrvsrc
   cd ~/rehearsal-pc
   git init -b main
   ```

3. 02-04で取り込み済みの`~/ibmi-kyozai`から、`jucsrv.rpgle`・`jucsrv.bnd`の2ファイルだけをコピーします。

   PUB400は共有アカウントなので、gitのユーザー名・メール・アドレスはこのリポジトリーだけに設定します(`--global`は付けません)。

   ```sh
   cp ~/ibmi-kyozai/src/qrpglesrc/jucsrv.rpgle src/qrpglesrc/
   cp ~/ibmi-kyozai/src/qsrvsrc/jucsrv.bnd src/qsrvsrc/
   git config user.name "自分の名前"
   git config user.email "自分のメール・アドレス"
   git add src
   git commit -m "Rehearsal: JUCSRV project"
   ```

   **この`cp`がコピー元のCCSIDタグ(1208)をそのまま保つかどうかは、このレッスンでは個別に検証していません(未検証)。** ただし、このあと実際にコンパイルするのは手順5で`git clone`によりチェックアウトされる側のファイルです。PASEのgit自身は一貫してCCSID 1208(UTF-8)タグ付きファイルを作成することが実機確認済みなので(下の「実機メモ」参照)、`git clone`で得られるファイルのCCSIDタグは`cp`側の挙動によらず1208になるはずです。

4. ベア・リポジトリーを作り、pushします。

   ```sh
   git init --bare -b main ~/rehearsal-bare.git
   git remote add rehearsal ~/rehearsal-bare.git
   git push rehearsal main
   ```

5. ビルド用の作業クローンを作ります。

   ```sh
   git clone ~/rehearsal-bare.git ~/rehearsal-clone
   ```

`~/rehearsal-clone/src/qrpglesrc/jucsrv.rpgle`・`~/rehearsal-clone/src/qsrvsrc/jucsrv.bnd`が、A(本筋)の`myproject`と同じ内容で揃います(`.gitattributes`はこの簡略版には含めていません——git自身の改行正規化を練習する主眼はAにあるためです)。

### C. SRCSTMFからのビルド(A・B共通)

1. 5250に切り替えます(`DSPLIBL`は画面系のコマンドで、`docs/style-guide.md`の作法どおりSSHの中では使いません。5250とSSHは別々のジョブとして両方開いたままにしておけます——02-04参照)。`DSPLIBL`で`<自分のユーザー名>1`が`*LIBL`に入っていることを確認します。入っていなければ`ADDLIBLE LIB(<自分のユーザー名>1) POSITION(*FIRST)`を実行してください(上の「説明」参照)。

2. `CRTRPGMOD`で、`jucsrv.rpgle`をSRCSTMFから直接コンパイルします。**`TGTCCSID(*JOB)`を忘れないでください**(無指定だと`RNS9380`になります)。IFSパスが長い場合は、コマンド名だけ入力して`F4`(プロンプト)を押すと、パラメーターごとに別々の入力欄に分けて書けます。

   ```text
   CRTRPGMOD MODULE(<自分のユーザー名>1/JUCSRV) SRCSTMF('/home/<自分のユーザー名>/pub400-clone/src/qrpglesrc/jucsrv.rpgle') TGTCCSID(*JOB) REPLACE(*YES)
   ```

   成功すると、次のようなメッセージになります(実機確認済み)。

   ```text
   Module JUCSRV placed in library <自分のユーザー名>1. 10 highest severity.
   ```

   **最高重大度が`10`であって`00`ではない点に注意してください。** `CRTRPGMOD`の`GENLVL`(生成を打ち切る重大度のしきい値)パラメーターの既定値は10です——一次資料(`cl_commands_75.txt`)によれば「コンパイル時のエラーがすべてこのしきい値以下なら、モジュール・オブジェクトを生成する」という規則で、既定の10ちょうどはこの「生成する」側に含まれます。この`10`は、07-02/07-03でメンバー経由の`JUCSRV`をコンパイルしたときに見たのと同じ`RNF7534`(「非サイクル・モジュールでは`TOKUIM`を明示的にクローズすべき」という助言のみ、実機確認済み)です。ソースの中身が同じ以上、警告の中身も同じになる——これも「メンバーとSRCSTMFは同じコンパイラーへの2つの入口に過ぎない」ことの一例です。`00`ではなく`10`になっても、慌てず先に進んでください。

3. `CRTSRVPGM`で、`jucsrv.bnd`(バインダー・ソース)をSRCSTMFから直接読み、サービス・プログラムを作り直します。`MODULE()`には、手順2で作った*MODULEオブジェクトを(ライブラリー修飾つきで)指定します。

   ```text
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV) EXPORT(*SRCFILE) SRCSTMF('/home/<自分のユーザー名>/pub400-clone/src/qsrvsrc/jucsrv.bnd') ACTGRP(*CALLER) REPLACE(*YES)
   ```

   成功すると、既存の`JUCSRV`(*SRVPGM)が退避されてから置き換わったことを示すメッセージが出ます(実機確認済み)。

   ```text
   Replaced object JUCSRV type *SRVPGM was moved to QRPLOBJ.
   Service program JUCSRV created in library <自分のユーザー名>1.
   ```

### D. 動作確認(A・B共通)

07-02/07-03で作った`F0702A`・`F0703A`は、`*LIBL`経由で`JUCSRV`を解決する設計でした(上の「ウォームアップ」参照)。ソースもオブジェクト名も一切変えていないので、**再コンパイルする必要はありません**——今作り直した`JUCSRV`に対して、そのまま実行するだけで確認できます。

```text
CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00001')
CALL PGM(<自分のユーザー名>1/F0703A) PARM('C00001')
```

`DSPJOBLOG`で、07-02/07-03で見たのとまったく同じ値が出ることを確認してください。

```text
CPF9898:  F0702A: getCustName(C00001) = ACME TRADING CO.
CPF9898:  F0703A: countCustOrders(C00001) call 1 = 2.
CPF9898:  F0703A: countCustOrders(C00001) call 2 = 2.
CPF9898:  F0703A: MATCH - both calls agree; JUCHUM repositioning is correct..
```

**「メンバー経由で作った`JUCSRV`」と「SRCSTMF経由で作り直した`JUCSRV`」が、呼び出し側から見てまったく同じ結果を返すこと**——これがこの課の核心です。

## 演習

**この演習は、上の「A. 本筋」(PC側の本物のプロジェクト)を前提にします。** まだ「B. 代替」しか試していない場合は、先にAを行ってください——1行変更→push→pullの一往復は、bareリポジトリーへの本物のPC pushでこそ意味を持つ確認です。

1. PCの`myproject`で、`src/qrpglesrc/jucsrv.rpgle`に、動作に影響しないコメント行を1行だけ追加してください(例: ファイル末尾近くに`// round-trip test: <今日の日付>`のような1行)。
2. コミットしてpushします。

   ```sh
   git add src/qrpglesrc/jucsrv.rpgle
   git commit -m "Add a round-trip test comment"
   git push pub400 main
   ```

   1行だけの挿入なら、`git commit`の要約はおおよそ`1 file changed, 1 insertion(+)`のような小さな差分になるはずです(このレッスンの検証でも、本物のUTF-8/LFファイルへの1行挿入でまったく同じ形の要約を確認しています——詳しくは下の「実機メモ」参照)。
3. SSHで`~/pub400-clone`に接続し、pullします。

   ```sh
   cd ~/pub400-clone
   git pull
   ```

   Fast-forwardで更新されるはずです。`cat src/qrpglesrc/jucsrv.rpgle`(またはお好みのビューアー)で、追加した行が反映されていることを確認してください。
4. 5250から、上の「実演C」の`CRTRPGMOD`/`CRTSRVPGM`を(同じコマンドのまま)もう一度実行し、`JUCSRV`を作り直します。
5. 「実演D」と同じ`CALL PGM(F0702A)`/`CALL PGM(F0703A)`を実行し、**コメント行の追加なので動作(戻り値)自体は変わっていない**ことを確認してください。
6. `git log`で、コミット履歴に今回の1コミットが正しく積み上がっていることを確認してください。

## セルフチェック

- [ ] `git init --bare`と通常のリポジトリーの違いを、「作業コピーの有無」という観点で説明できる。
- [ ] `~/.ssh/config`の`IdentitiesOnly yes`が何を防ぐためのものか説明できる。
- [ ] メンバーを1つも作らず、SRCSTMFから`JUCSRV`を`CRTRPGMOD`/`CRTSRVPGM`でビルドできた。
- [ ] `TGTCCSID(*JOB)`がなぜ必要か、CCSID 1208(UTF-8)と既定の`TGTCCSID(*SRC)`を結び付けて説明できる。
- [ ] コンパイル・ジョブの`*LIBL`に`<自分のユーザー名>1`が入っている必要がある理由を説明できる。
- [ ] `CRTRPGMOD`の`SRCSTMF`と`CRTSRVPGM`の`SRCSTMF`が、指しているもの(モジュールのソース/バインダー・ソース)が別物であることを説明できる。
- [ ] PCで1行変更→push→PUB400でpull→再ビルドの一往復を、自分の手で行った。
- [ ] 再ビルドした`JUCSRV`に対して`F0702A`/`F0703A`を実行し、07-02/07-03と同じ結果が出ることを確認した。

## 片付け

- SRCSTMFビルドで作り直した`<自分のユーザー名>1/JUCSRV`はそのまま残してください——07-02/07-03から引き続き使われるオブジェクトで、中身は元と同じです。削除しないでください。
- `~/pub400-bare.git`・`~/pub400-clone`(A)、およびPC側の`myproject`は、以後の第8部のレッスンでも使う可能性があるため、特別な事情がなければ残しておいてください。
- `~/rehearsal-pc`・`~/rehearsal-bare.git`・`~/rehearsal-clone`(Bの練習用)は、練習が済めば削除してかまいません。容量はわずかです。

## まとめ

| 英語 | 日本語 |
|---|---|
| Bare repository | ベア・リポジトリー(作業コピーを持たないリポジトリー) |
| Working copy | 作業コピー(チェックアウトされたファイル一式) |
| SRCSTMF | ソース・ストリーム・ファイル(メンバーではなくIFS上のファイルから読むソース指定) |
| Fast-forward | 早送り(履歴が一直線につながる、単純な`git pull`の反映のされ方) |
| Target CCSID | コンパイラーがソースを読むときに使うCCSID(`TGTCCSID`) |

次のレッスン(08-02)では、`makei`を使って依存関係に沿った一括ビルドを行います(`iproj.json`・`Rules.mk`という別の`templates/part08-project/`ファイルを使い、`ZAISRV`を題材にします)。

## 実機メモ

- **確認日: 2026-09-28〜2026-09-29。接続`part08-01-git-srcstmf`(合計7回の接続)。** qshの1セッション内でIFS上に擬似「PC側」・「PUB400側(ベア)」・「ビルド用クローン」の3ディレクトリーを作り、`git init --bare`→`git push`→`git clone`という経路をリハーサルしたうえで、`JUCSRV`をメンバー経由ではなくSRCSTMF直接ビルドで作り直す、という実機確認を行いました。
- **V2で確認済み(このverifyハーネス自身がqsh経由で確認済み)**:
  - `git init --bare`→`git push`→`git clone`という経路そのもの。
  - `CRTRPGMOD MODULE(&LIB/JUCSRV) SRCSTMF(...) TGTCCSID(*JOB) REPLACE(*YES)`が、本物のUTF-8/LFの`git clone`済みファイルに対して成功すること(「Module JUCSRV placed in library \<USER\>2. 10 highest severity.」)。
  - `CRTSRVPGM SRVPGM(&LIB/JUCSRV) MODULE(&LIB/JUCSRV) EXPORT(*SRCFILE) SRCSTMF(...) ACTGRP(*CALLER) REPLACE(*YES)`が成功すること(「Replaced object JUCSRV type *SRVPGM was moved to QRPLOBJ.」「Service program JUCSRV created in library \<USER\>2.」)。
  - 再ビルドした`JUCSRV`に対し、`F0702A`/`F0703A`が`*LIBL`経由で正しく解決・動作すること(`getCustName(C00001) = ACME TRADING CO`、`countCustOrders(C00001)`の2連続呼び出しがどちらも`2`——メンバー経由の元のビルドと完全に同じ値)。
  - PCでの1行編集→commit→push→pull→再ビルドという一往復の**機構**(本物のUTF-8/LFファイルへの1行挿入、`git commit`の要約が`1 file changed, 1 insertion(+)`になること、pushの成功、`pub400-clone`側での`git pull`のFast-forward、再ビルドの成功、`F0702A`/`F0703A`の再確認)。
- **本文の「B. 代替」節が指示する具体的な手順(`~/ibmi-kyozai`から`cp`で2ファイルだけコピーする簡略版)は、このレッスンの検証ハーネス自身が実行したものと完全に同一ではありません**(ハーネスは、既にコンパイル済みのメンバーから`CPYTOSTMF`で本物のUTF-8/LFストリーム・ファイルを新規に書き出す、という別の方法で種ファイルを用意しました——学習者向けの本文には、この教材のこれまでの`CPYFRMSTMF`/`CPYTOSTMF`の使い方と混同を避けるため、より単純な`cp`を採用しています)。個々の要素(`git init --bare`→`push`→`clone`という経路自体、`SRCSTMF`ビルドのコマンド自体)はいずれも上のとおりV2で確認済みですが、「B」節が指示する**この具体的な組み合わせ**(`cp`によるコピー)そのものは、このリポジトリでは個別に検証していません(V3)。
- **V3のまま(このハーネスでは一度も確認していない、2026-09-29時点)**:
  - 本物のPC→PUB400へのgit push(SSH経由、実際のPCのgitクライアントから)。今回はqshセッション内で「PC側」「PUB400側」の両方を擬似的に再現しただけで、本物のPC側からの接続は一度も行っていません。
  - `~/.ssh/config`の`IdentitiesOnly yes`設定の要否そのもの(複数鍵の提示が認証失敗としてカウントされる、という一般知識に基づく対策です)。
  - `.gitattributes`(LF強制)によるgit自身の改行正規化の経路そのもの——今回のリハーサルでは、この文書とは別の手段で直接LF化したファイルを使っており、`.gitattributes`によるgit自身の正規化は一度も経由していません。
  - `INCDIR`——`JUCSRV`は`/COPY`ディレクティブを持たないため、`CRTRPGMOD`の`INCDIR`パラメーターは一度も実際に使われていません。
  - `receive.denyCurrentBranch=updateInstead`——この教材の決定でbareに一本化したため、そもそも採用していない経路です。
- **見つかった実バグ、2件**(いずれも本文が教える技術的な要点そのものです): (1) `git clone`直後のファイルがCCSID 1208(UTF-8)とタグ付けされているのに対し、`CRTRPGMOD`の既定`TGTCCSID(*SRC)`はUnicode系CCSIDを受け付けず`RNS9380`になる——`TGTCCSID(*JOB)`の明示で解決しました。**ただしこの接続では、`TGTCCSID(*JOB)`を指定するだけでは終わらず、途中で`CPE3490`(「Conversion error.」)にもぶつかっています**——調査の結果判明した真因は、当時使っていた種ファイル自身が、CCSID 1208というタグだけ付いた**本物ではないEBCDICバイト列**だったことでした(このハーネス固有の種ファイル生成方法の問題で、学習者が実際に使う本物のUTF-8ファイルには当てはまりません)。本物のUTF-8シードに切り替えたところ、`TGTCCSID(*JOB)`はそのまま成功しています——つまり本文が教える対処(`TGTCCSID(*JOB)`)が効くのは、「タグと実際のバイト列が一致した、本物のUTF-8ファイル」に対してです。学習者がPC側のエディターで書いたファイルは最初からこの条件を満たしているため、この落とし穴自体を踏む心配はありません。(2) `*LIBL`にコンパイル対象ライブラリーが入っていないと、`TOKUIM`/`JUCHUM`の外部記述が解決できず`RNF2120`(重大度40)になる——`ADDLIBLE`で解決しました。本文の「説明」節は、この2点を中心に構成しています。
- **ハーネス固有の回避策で、学習者向けの本文には一切含めていないもの**: 種ファイルを本物のUTF-8として用意するための`CPYTOSTMF`経由の生成(学習者はPC側の本物のエディターでファイルを作るので不要です)、`*LIBL`をジョブ内で維持するための動的生成CLヘルパー・プログラム(qshの`system()`呼び出しが1回ごとに別ジョブになるという、このハーネス固有の制約への対処です。5250の対話ジョブでは1つのコマンド行の実行がそのまま1つのジョブの中で完結します)、短縮したIFSディレクトリー名やCLの`+`継続行への分割(CL行の桁数制限を避けるための、ハーネス内部限定の対処です。学習者は`pub400-bare.git`/`pub400-clone`のような分かりやすい名前を自由に使えますし、5250の`F4`プロンプトを使えばパラメーターごとに別の入力欄になるため、1行の桁数はハーネスほど気にする必要はないはずです——ただしこの具体的な組み合わせ〔長いIFSパス+F4プロンプト〕自体は、このリポジトリでは個別に検証していません〔一般知識〕)、PCでの編集をシミュレートするPythonスクリプト自体の配送方法(heredoc経由で書き込んだスクリプト自身がEBCDIC化されてしまう、というこのハーネス固有の問題への対処です。学習者はPC側のエディターで直接編集するので無関係です)。
- **「qshのリダイレクト(`>`)がファイルをCCSID 273(EBCDIC)へ再エンコードする」という現象は、qsh固有の挙動であり、一般化しないでください。** 同じ接続でPASEのgit自身は一貫してCCSID 1208タグ付きファイルを作成しており、qshとPASEログイン・シェル(`bsh`、02-04で確立済みのSSH接続で入るシェル)は異なる既定動作を持つ別々の実行環境です。学習者は02-04の方法でSSH接続し、既定のPASE `bsh`シェルを使う分にはqshを明示的に起動しないため、この現象を前提にした心配は不要です。
- **実際にコンパイル・実行されたライブラリーは`<USER>2`でした**(この教材の検証ハーネス自身の方針、`docs/probes.md`)。学習者向けの本文では、この教材のこれまでの慣例どおり`<USER>1`(開発用)への手順として書いています——オブジェクトの中身・動作自体はどちらのライブラリーでも変わりません。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
