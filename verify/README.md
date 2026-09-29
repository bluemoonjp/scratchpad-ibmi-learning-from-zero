# 検証ハーネス(verify/)

PUB400 への実機接続をすべてこの1本のハーネスに通すための道具。素の Node.js(依存パッケージなし)で動く。目的は次の2つ:

1. SSH 接続数の歯止め(間隔・拒否後の停止・認証失敗後の全停止)を、思い込みではなく台帳(`work/verify/ledger.json`)から機械的に判定すること。
2. 1回の接続で「転送 → コンパイル → 実行 → 結果の回収」までまとめて済ませ、接続回数そのものを減らすこと。

## 使い方

```sh
node verify/run.mjs --status              # 台帳の状態と、次に接続してよい時刻を表示する
node verify/run.mjs --next-allowed        # 次に接続してよい時刻だけを ISO8601 で表示する(スクリプト用)
node verify/run.mjs --dry-run <batchDir>  # verify/<batchDir>/manifest.json から送るスクリプトを
                                           # 組み立てて表示するだけ(接続しない)
node verify/run.mjs <batchDir>            # 実際に1回接続し、結果を
                                           # work/verify/results/<batch>-<timestamp>.json に保存する
```

`<batchDir>` は `verify/` 直下のディレクトリー名(例: `harness-selftest`、将来 `part05` 等)。

**必ず Bash 経由で実行すること(PowerShell から直接 `node verify/run.mjs` を実行しない)。** このマシンでは `ssh` という名前の実行ファイルが2つある(Git 付属の OpenSSH と Windows 標準の OpenSSH)。Bash(Git Bash)経由で node を起動した場合、`child_process.spawn('ssh', ...)` は Git 付属の OpenSSH(`C:\Program Files\Git\usr\bin\ssh.exe`)を解決する(2026-09-25 に確認済み)。PowerShell から直接起動すると Windows 標準の OpenSSH(`C:\Windows\System32\OpenSSH\ssh.exe`)が解決される可能性があり、鍵ファイルの ACL 要件などが異なるため、狙った経路と違う認証結果になりうる。

**必ず `--dry-run` で送るスクリプトを確認してから、実際の接続を行うこと。** 歯止めは15分間隔・拒否/タイムアウト後3時間停止・認証失敗後の全停止の3つのみで、24時間あたりの回数上限は無い(2026-09-26、台帳198件の実測に基づき撤廃済み。詳細は下記)。

**実接続(`--dry-run` を付けない実行)は必ずこのリポジトリーの主ワークツリー(`git worktree list` の先頭、`.git` がディレクトリーとして存在する場所)から行うこと。** `verify/lib/paths.mjs` の `repoRoot()` は自分自身のファイル・パス(`__dirname`)基準で解決するため、`git worktree add` で作った別ワークツリーから実行すると、`work/verify/ledger.json`(接続台帳)・`verify/config.local.json`(接続情報)がそのワークツリー独自の(通常は存在しない)ものとして扱われる。`work/`・`*.local.*` はどちらも `.gitignore` 済みで、ワークツリー間で共有されない。台帳が空の別ワークツリーから実行すると、15分間隔等の歯止めがそのワークツリーでは効いていないかのように見えてしまう(実際には主ワークツリー側の台帳と食い違うだけで、歯止めの回避にはならないが、記録が分裂し状況把握を誤らせる)うえ、接続情報が無ければ接続自体に失敗するか、`--dry-run` の既定プレースホルダー(`DRYRUN`/`DRYRUN2`)にフォールバックしてしまう。別ワークツリーでマニフェストを作成・編集すること、そこで `--dry-run` を実行すること(接続情報が無くても `DRYRUN`/`DRYRUN2` プレースホルダーで動く設計)は問題ない。**`--dry-run` を付けない実際の接続だけは、必ず主ワークツリーへ切り替えてから実行する。**

## 接続情報の設定

実名・実パスはこのディレクトリーのどのファイルにも書かない(コミットされるため)。次のどちらかで指定する。

- 環境変数 `PUB400_USER`(鍵は既定で `~/.ssh/pub400`)
- `verify/config.local.json`(`.gitignore` の `*.local.*` に一致し、コミットされない)。`verify/config.example.json` をコピーして使う。

```json
{
  "user": "YOUR_PUB400_USER",
  "keyPath": "~/.ssh/pub400",
  "host": "pub400.com",
  "port": 2222
}
```

接続の形は `docs/probes.md` の実績どおり:

```sh
ssh -i <鍵> -p 2222 -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=30 \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new <USER>@pub400.com /usr/bin/qsh
```

リモート・コマンドとして `/usr/bin/qsh` を直接起動し、標準入力からシェル・コマンドを渡す。

## 台帳(`work/verify/ledger.json`)と歯止め

`work/verify/` は `.gitignore` 済みで、実名を含んでいてもコミットされない。台帳のスキーマ:

```json
{
  "schemaVersion": 1,
  "updatedAt": "...",
  "authFailedEver": false,
  "connections": [
    { "startedAt": "...", "endedAt": "...", "status": "success", "batch": "...", "note": "..." }
  ]
}
```

`status` は `started`(記録直後、まだ終わっていない)・`success`・`auth_failed`・`refused_or_timeout`・`blocked`・`unknown` のいずれか。

歯止め(`verify/lib/ledger.mjs` の `computeGate` が機械的に判定する。安全側に倒し、緩和条件は自己申告しない):

- 接続の間隔は15分以上(前回の `startedAt` から)。
- `refused_or_timeout` または `blocked` が記録されたら、そこから3時間は停止。
- `authFailedEver` が真になったら(=認証失敗が1回でも記録されたら)、無期限に全停止する。台帳を書き換えて解除することはできない(意図的にそうしてある)。解除が必要な状況になったら、ユーザーに報告してから対応すること。

**2026-09-26に「直近24時間で24回まで(拒否/タイムアウトが記録されていれば8回まで)」という累計上限は撤廃した。** 台帳198件の実測(拒否6件はいずれも短時間バーストの直後に集中し、24時間累計148〜174回では無事故だった)に基づき、上記3つの歯止めだけで十分と判断した。

台帳は排他ロック(`work/verify/ledger.json.lock`、60秒で失効)を取ってから読み書きする。接続の「前」に `recordStart` で `started` エントリーを追加し、終わったら `recordEnd` で更新する(クラッシュしても1回とカウントされるようにするため)。

**2026-09-25 時点の実績**: 前のセッションで同日中に174回(!)接続していたことが transcript から復元できている(`work/verify/ledger.json` の `batch: "historical-reconstruction"` のエントリー群)。このため本ハーネスの最初の実接続は、上記の歯止めにより次に許可される時刻(`--next-allowed` で確認)まで待つ必要がある。

## マニフェスト(`verify/<batchDir>/manifest.json`)

1つのバッチ = 1回の接続で流す一連の作業。スキーマ:

```json
{
  "batch": "harness-selftest",
  "description": "人間向けの説明",
  "library": "<省略時は <USER>2。\"*B\" なら <USER>B(SAVF/退避役)に解決される>",
  "remoteDir": "<省略時は vfy/<batch>>",
  "wrapperCcsid": "<省略可。CLラッパー自身のソース転送に使うCCSID。省略時(またはfalse)は無指定>",
  "sshTimeoutMs": "<省略可。この接続のkillタイマー(verify/lib/ssh.mjs)。省略時は既定180000(180秒)。makei等、時間が読めない処理を含むマニフェストで上書きする>",
  "steps": [
    { "type": "file", "localPath": "src/foo.rpg", "remoteSrcFile": "QRPGSRC", "member": "FOO", "ccsid": "<省略時(またはfalse)は無指定>" },
    { "type": "cl", "label": "COMPILE", "cmd": "CRTRPGPGM PGM(&LIB/FOO) SRCFILE(&LIB/QRPGSRC) SRCMBR(FOO)", "monmsg": ["CPF0000"] },
    { "type": "cl", "label": "RUNIT", "cmd": "CALL PGM(&LIB/FOO)" },
    { "type": "collect", "kind": "sql", "sql": "任意のSELECT文(cl以外の追加の回収が要る場合だけ使う)" }
  ]
}
```

- `file` ステップ: `localPath`(このマニフェストのディレクトリーからの相対パス)の中身を heredoc で転送し、`CPYFRMSTMF` で `library` の `remoteSrcFile`/`member` に取り込む。`ccsid` は**省略(または `false`)すると何も出さない(既定、無指定のまま)**。具体的な数値を指定した場合だけ `setccsid`/`STMFCCSID()` が出る(2026-09-26、`harness-selftest` の実測で確定済み。下記「既知の未検証事項」参照)。`remotePath`(省略可、既定は `<remoteDir>/<localPathのbasename>`というフラットな置き方)を指定すると、`$HOME`からの任意の相対パスへ直接置ける(2026-09-27追加)。`remoteSrcFile`/`member`も省略すると、IFS上にファイルを置くだけで終わり、`CPYFRMSTMF`は一切実行されない——`TXLEGACY`/`TXSNAP`/`TXMIGR`のように`CLONEDIR`配下の実ツリーを前提に**自分自身で**`CPYFRMSTMF`するツールを検証するとき、そのツールが期待する相対パスへ直接ファイルを置くのに使う(`verify/part05-txlegacy-exec`参照)。
- `sh` ステップ: `cmd`をqsh(PASE)のシェル・コマンドとしてそのまま埋め込む(`system("...")`でCLコマンドとして解釈させるのではない)。CLには無い操作が必要なときに使う(2026-09-27追加)。**`file`ステップの後・`cl`ステップ(1本のラッパーにまとめてコンパイル・実行される)の前に、常にこの順序で挟まる**(マニフェスト内での前後関係は今のところ無視される。任意の順序で挟めるようにする一般化は未着手)。
  - **`"after": true` を付けた `sh` ステップは、`cl` ステップの後・`collect` の前に置かれます(2026-09-30追加)。** `cl` ステップが作った表やオブジェクトを使う qsh コマンドや、IFS のパスを CL コマンドへ渡す必要がある処理(`system "RUNSQLSTM SRCSTMF('$HOME/vfy/<batch>/x.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(&LIB)"` など)に使います。`$HOME` は qsh が展開します(`file` ステップが置く `$HOME/vfy/<batch>/<ファイル名>` と同じ場所です)。qsh の `system()` は呼び出しごとに別ジョブなので、`CHGCURLIB` の結果は引き継がれません。作成先は `DFTRDBCOL(&LIB)` などで必ず明示してください。
- `cl` ステップ: 1本の CL ラッパー・プログラムにまとめてコンパイル・実行する(`verify/lib/clgen.mjs`)。各ステップは個別の `MONMSG` で囲み、失敗しても次のステップへ進む。`cmd` 内の `&LIB` は生成時に実際のライブラリー名へ文字列置換される(CL の実行時変数ではない。`CALL...PARM()` の32バイト・パディング問題を避けるため)。**ハングの恐れがあるステップは必ず配列の最後に置くこと。** `cl` ステップが1つでもあれば、ラッパーは `DONE`/`FAILSAFE` のどちらで終わっても、まず自分自身にその終端マーカーをメッセージで送ってから、自分のジョブ・ログをライブラリー内の永続表(`<library>/VFYLOG`、なければ自動作成)へ書き出す(この順序が重要: 逆順だとマーカー自身のメッセージがまだジョブ・ログに乗っていない時点で書き出しが走ってしまい、VFYLOG からは一生見えなくなる)。接続の最後に自動でその表を `SELECT`(`===VFY:vfylog===` セクション)する。`QTEMP` ではなく永続表にしているのは、qsh の個々の `system()` 呼び出しが別々のジョブとして実行される(下記「既知の未検証事項」参照。2026-09-28、`part06-p43-lockdiag`接続で確認: `CALL PGM(...)`を実行した`system()`呼び出し自身のジョブ・ログが「system CALL PGM(...)」という行そのものから始まっており、それより前の(同じ接続内の他の`system()`呼び出しが出したはずの)CPYFRMSTMF等のメッセージが一切含まれていなかった。2026-09-26の別接続でも同じ観測パターンが独立に得られている)ためで、この設計判断はもともと正しかったことになる。
- `collect` ステップ: 上記の自動回収(vfylog)以外に、追加で結果をテキストで回収したいときだけ使う。既定は自分のジョブ・自分のユーザーに絞った `SYSTOOLS.SPOOLED_FILE_DATA` からのSELECT。`db2` へはフラグを付けず(そもそも命名規則を切り替えるフラグは存在しない)、パイプ経由の標準入力ではなく引用符付きの位置パラメーターとして渡す(`db2 "SQL文"`)。マニフェスト側で書く `&LIB/table` は `<library>.table`(ドット区切り)に変換してから渡す(2026-09-26、IBM Docs「Qshell db2 Utility」・rbafy75.txtで確認済み。詳細は `verify/lib/batch.mjs` 冒頭のコメント参照)。

`library` の `"*B"` 記号(2026-09-27追加、`verify/lib/config.mjs` の `resolveLibrary`): マニフェストに実ユーザー名を直接書くと私的パターン露出になるため、`library` に `"*B"` と書くと `<USER>B`(SAVF/退避役、01-04で確立済みの命名)に解決される。省略時の既定は開発役 `<USER>2`。それ以外の文字列は将来の拡張のためそのまま library 名として使われる。

## 既知の未検証事項(次回の実接続で確認し、docs/probes.md に記録する)

- `SYSTOOLS.SPOOLED_FILE_DATA` の実際の呼び出し方(引数の形)。`collect` ステップの既定クエリーは最有力候補であり、失敗する可能性がある(未使用でも問題ない設計にしてある)。

**解決済み(2026-09-26・2026-09-28、2回の接続で独立に確認): `qsh` の個々の `system()` 呼び出しは同一ジョブ内で連続しない——それぞれ別のジョブとして実行される。** 根拠: `part06-p43-lockdiag`接続(2026-09-28)で`CALL PGM(...)`を実行した`system()`呼び出し自身のジョブ・ログが、`Job <番号>/QUSER/QP0ZSPWT started ... system CALL PGM(...).`という行そのものから始まっており、同じ接続内でそれより前に実行されていたはずのCPYFRMSTMF等のメッセージを一切含んでいなかった(2026-09-26の別接続でも同じパターンを独立に観測済み)。ラッパーの結果回収(上記VFYLOG)はもともとこれに依存しない設計にしてあったため、ハーネス自体の変更は不要——この解決は設計判断の裏付けという意味を持つ。

**解決済み(2026-09-26、`harness-selftest` で確定): heredoc で書いたファイルは既定で CCSID 273(EBCDIC、PUB400 の QCCSID そのもの)にタグ付けされ、実バイト列も本物の EBCDIC である。** タグとバイト列が一致しているので、`CPYFRMSTMF` は何も指定しなければ正しく変換できる(`CPCA081: Stream file copied to object.`)。逆に `setccsid 1208`/`STMFCCSID(1208)` を明示すると、実際は EBCDIC のバイト列を ASCII/UTF-8 だと偽ってタグ付けすることになり変換が失敗する(`CPFA0A2`/`CPFA095`)。このためハーネスの既定は「CCSID を一切指定しない」(`resolveCcsid()` は `ccsid` を省略または `false` にした場合 `null` を返す)。**`tools/qclsrc/txsetup.clp` 等の git clone 経由の転送が使う `STMFCCSID(1208)` はこれとは別の実績(git 側で ASCII/UTF-8 として送られてくる)であり、混同しないこと。**

`verify/harness-selftest/` は、この確認と「`CHGJOB INQMSGRPY(*DFT)` による RPG0102(OPM RPG III のゼロ除算照会。Part 5 が必要とするのもこちら)の自動応答」をまとめて行う、最初の実接続向けのバッチ。RPG III(`CRTRPGPGM`)を使っている。ILE(`CRTBNDRPG`)では `RNQ0102`/`RNX0102` になり別の話になるので注意。

## `part08-01-git-srcstmf`(2026-09-29、7回の接続)で見つかった、マニフェスト設計全般の落とし穴

git/SRCSTMF/動的CL生成を組み合わせた複雑なマニフェストを書く過程で、既存の「既知の未検証事項」に載っていない新しい落とし穴が複数見つかった。次に似た構成のマニフェストを書くときのために、まとめておく。

- **`collect` ステップは、マニフェストでの記述位置に関わらず必ず最後に実行される。** 実際の生成順序は常に `file` → `sh` → `cl` → `collect`(`verify/lib/batch.mjs` の各ループの並び)。「先にオブジェクトの存在確認をしてから作業する」という意図で `collect` を配列の先頭に書いても、実際にはすべての `sh`/`cl` ステップの**あと**に実行される。事前チェックが必要な場合は `cl` ステップ(`CHKOBJ`等)を使うこと。
- **`sh` ステップの `system(...)` 呼び出しは、`cl` ステップの生成ラッパーと違って `ADDLIBLE` が自動発行されない。** `cl` ステップは `verify/lib/clgen.mjs` が生成するラッパーの先頭で常に `ADDLIBLE LIB(&LIB)` + `MONMSG MSGID(CPF2103)` を発行するが、`sh` ステップの `system("CRTxxx ...")` は素のジョブとして走るため、`*LIBL` に `&LIB` が入っておらず、`&LIB` 内の他のオブジェクト(外部記述ファイル等)を無修飾で参照するソースのコンパイルが `RNF2120`(External descriptions ... not found)等で失敗しうる。`*LIBL` 解決が必要な処理は `cl` ステップにするか、`ADDLIBLE` を含む使い捨て CL プログラムを動的生成して `CALL` すること(1回の `system()` 呼び出し=1ジョブなので、`ADDLIBLE` と本体の処理は**同じ** `system()` 呼び出し、つまり同じコンパイル済みプログラムの中に入れる必要がある)。
- **heredoc で qsh から書き込んだファイルは、常に EBCDIC(既定 CCSID 273)になる。** これは上の「解決済み」項目がすでに指摘しているとおりだが、影響範囲は「`CRTxxx` に渡すソース」だけではない——**heredoc で書いた `python3` スクリプト自身も EBCDIC になり、`python3` 自身がそれを解析できずに `SyntaxError: Non-UTF-8 code ... but no encoding declared` で失敗する。** `# -*- coding: ... -*-` という PEP 263 宣言でも直せない(Python 自身の先頭2行スキャンが ASCII 互換を前提にしており、EBCDIC バイト列では宣言そのものを認識できない)。本物の UTF-8 ファイルが必要な場合は、heredoc ではなく、いったん `file` ステップで実在するソース・メンバーとして転送してから `CPYTOSTMF ... STMFCCSID(1208) ENDLINFMT(*LF)` でIFSへ書き出すこと(`CRTRPGMOD`/`CRTSRVPGM` の `SRCSTMF` パラメーターに渡すソースの生成と同じ手法)。
- **`git clone`/`git pull` でチェックアウトされるファイルは CCSID 1208(UTF-8)でタグ付けされる。** `CRTRPGMOD`/`CRTSQLRPGI` 等の `SRCSTMF` パラメーターへそのまま渡すと、既定の `TGTCCSID(*SRC)` は Unicode 系 CCSID を拒否する(`RNS9380`)。`TGTCCSID(*JOB)` を明示すること。
- **CL の物理ソース行は約80桁(`verify/lib/clgen.mjs` の `CL_MAX_COL=80` と同じ目安)を超えると、`CPYFRMSTMF` が `CPIA083`(Stream file copied to object with truncated records)で静かに切り詰める。** 絶対 IFS パスを含む `SRCSTMF('...')` のような1つの長いトークンは、空白の位置でしか折り返せない(`+` 継続行を使う場合も、パラメーターの区切り目でしか折り返せない)ため、ディレクトリー名自体を短くしておくか、`+` 継続行に分割すること。切り詰めは `CPD0014`(引用符不一致)・`CPD0013`(かっこ不一致)のような、一見無関係なエラーとして現れる。
- **CL のラベルは10文字に切り詰められる。** 別々のマニフェスト・ステップに異なるラベル(例: `CLIENTF0702A`/`CLIENTF0703A`)を付けたつもりでも、先頭10文字が同じ(`CLIENTF070`)だと生成される CL ソース上で重複ラベルになり、コンパイル・エラーになる。
- **CL の `MONMSG` は直前の1コマンドしか監視しない。** `ADDLIBLE`→`CALL`→`CALL` のように複数コマンドを並べたあとに1つの `MONMSG` を置いても、それは最後のコマンドしか監視しない——先頭の `ADDLIBLE` 自身が返す無害な `CPF2103`(「既にライブラリー・リストに追加済み」)ですら未監視のまま扱われ、プログラム冒頭のトップレベル `MONMSG` まで伝播して残りの処理(2つの `CALL`)が一切実行されないまま `FAILSAFE` に落ちる。各コマンドを監視したい場合は、コマンドの直後にそれぞれ専用の `MONMSG` を置くこと。

## 実行結果の保存

`work/verify/results/<batch>-<timestamp>.json` に保存する。実名は `verify/lib/anonymize.mjs` で `<USER>`/`<USER>1`/`<USER>2`/`<USER>B` に置換してから書き込む。`work/` は `.gitignore` 済みなのでコミットされない。教材やレッスンに転記するときは、この結果ファイルの anonymize 済みの内容から書き起こす。
