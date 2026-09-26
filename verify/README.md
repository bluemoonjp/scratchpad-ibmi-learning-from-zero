# 検証ハーネス(verify/)

PUB400 への実機接続をすべてこの1本のハーネスに通すための道具。素の Node.js(依存パッケージなし)で動く。目的は次の2つ:

1. SSH 接続数の歯止め(間隔・24時間の回数上限・拒否後の停止・認証失敗後の全停止)を、思い込みではなく台帳(`work/verify/ledger.json`)から機械的に判定すること。
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

**必ず `--dry-run` で送るスクリプトを確認してから、実際の接続を行うこと。** 接続の予算は極めて限られている(直近24時間で8回、遮断が起きていれば実質それ未満)。

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
- 直近24時間で24回まで。直近24時間に `refused_or_timeout`/`blocked` のいずれかが記録されていれば、その間は8回まで(2026-09-26、台帳174件の実測に基づき緩和。根拠は `verify/lib/ledger.mjs` のコメント参照)。
- `refused_or_timeout` または `blocked` が記録されたら、そこから3時間は停止。
- `authFailedEver` が真になったら(=認証失敗が1回でも記録されたら)、無期限に全停止する。台帳を書き換えて解除することはできない(意図的にそうしてある)。解除が必要な状況になったら、ユーザーに報告してから対応すること。

台帳は排他ロック(`work/verify/ledger.json.lock`、60秒で失効)を取ってから読み書きする。接続の「前」に `recordStart` で `started` エントリーを追加し、終わったら `recordEnd` で更新する(クラッシュしても1回とカウントされるようにするため)。

**2026-09-25 時点の実績**: 前のセッションで同日中に174回(!)接続していたことが transcript から復元できている(`work/verify/ledger.json` の `batch: "historical-reconstruction"` のエントリー群)。このため本ハーネスの最初の実接続は、上記の歯止めにより次に許可される時刻(`--next-allowed` で確認)まで待つ必要がある。

## マニフェスト(`verify/<batchDir>/manifest.json`)

1つのバッチ = 1回の接続で流す一連の作業。スキーマ:

```json
{
  "batch": "harness-selftest",
  "description": "人間向けの説明",
  "library": "<省略時は <USER>2>",
  "remoteDir": "<省略時は vfy/<batch>>",
  "wrapperCcsid": "<省略可。CLラッパー自身のソース転送に使うCCSID。省略時は既定値1208、falseで無指定>",
  "steps": [
    { "type": "file", "localPath": "src/foo.rpg", "remoteSrcFile": "QRPGSRC", "member": "FOO", "ccsid": "<省略時は既定値1208、falseで無指定>" },
    { "type": "cl", "label": "COMPILE", "cmd": "CRTRPGPGM PGM(&LIB/FOO) SRCFILE(&LIB/QRPGSRC) SRCMBR(FOO)", "monmsg": ["CPF0000"] },
    { "type": "cl", "label": "RUNIT", "cmd": "CALL PGM(&LIB/FOO)" },
    { "type": "collect", "kind": "sql", "sql": "任意のSELECT文(cl以外の追加の回収が要る場合だけ使う)" }
  ]
}
```

- `file` ステップ: `localPath`(このマニフェストのディレクトリーからの相対パス)の中身を heredoc で転送し、`CPYFRMSTMF` で `library` の `remoteSrcFile`/`member` に取り込む。`ccsid` を**省略すると既定値1208が使われ**、`setccsid`/`STMFCCSID()` が出る(下記「既知の未検証事項」参照)。`false` を明示した場合だけ、これらを一切出さない。
- `cl` ステップ: 1本の CL ラッパー・プログラムにまとめてコンパイル・実行する(`verify/lib/clgen.mjs`)。各ステップは個別の `MONMSG` で囲み、失敗しても次のステップへ進む。`cmd` 内の `&LIB` は生成時に実際のライブラリー名へ文字列置換される(CL の実行時変数ではない。`CALL...PARM()` の32バイト・パディング問題を避けるため)。**ハングの恐れがあるステップは必ず配列の最後に置くこと。** `cl` ステップが1つでもあれば、ラッパーは `DONE`/`FAILSAFE` のどちらで終わっても、まず自分自身にその終端マーカーをメッセージで送ってから、自分のジョブ・ログをライブラリー内の永続表(`<library>/VFYLOG`、なければ自動作成)へ書き出す(この順序が重要: 逆順だとマーカー自身のメッセージがまだジョブ・ログに乗っていない時点で書き出しが走ってしまい、VFYLOG からは一生見えなくなる)。接続の最後に自動でその表を `SELECT`(`===VFY:vfylog===` セクション)する。`QTEMP` ではなく永続表にしているのは、qsh の `system()` 呼び出しが同一ジョブ内で連続する保証がない(下記、未検証)ため。
- `collect` ステップ: 上記の自動回収(vfylog)以外に、追加で結果をテキストで回収したいときだけ使う。既定は自分のジョブ・自分のユーザーに絞った `SYSTOOLS.SPOOLED_FILE_DATA` からのSELECT。`db2` へはフラグを付けず(そもそも命名規則を切り替えるフラグは存在しない)、パイプ経由の標準入力ではなく引用符付きの位置パラメーターとして渡す(`db2 "SQL文"`)。マニフェスト側で書く `&LIB/table` は `<library>.table`(ドット区切り)に変換してから渡す(2026-09-26、IBM Docs「Qshell db2 Utility」・rbafy75.txtで確認済み。詳細は `verify/lib/batch.mjs` 冒頭のコメント参照)。

## 既知の未検証事項(次回の実接続で確認し、docs/probes.md に記録する)

- `qsh` の `system()` 呼び出しが同一ジョブ内で連続するか。ラッパーの結果回収(上記 VFYLOG)はこれに依存しない設計にしてあるので、この点自体は未確定のままでもハーネスは動く。
- `SYSTOOLS.SPOOLED_FILE_DATA` の実際の呼び出し方(引数の形)。`collect` ステップの既定クエリーは最有力候補であり、失敗する可能性がある(未使用でも問題ない設計にしてある)。
- **heredoc で書いたファイルが実際にどの CCSID でタグ付けされるか。** `file`/`wrapperCcsid` の `ccsid` を省略すると既定値 1208(`verify/lib/batch.mjs` の `DEFAULT_CCSID`)を使う。これは `tools/qclsrc/txsetup.clp` が git clone で届いたソースの `CPYFRMSTMF` に実際に使い、実機で完走を確認済みの値をそのまま踏襲したもので、推測ではない。ただし heredoc 経由(git clone 経由ではなく)でも同じ既定でよいかどうかは、このハーネスではまだ確認していない。`ccsid: false` を明示すれば `setccsid`/`STMFCCSID()` を一切出さない(候補比較用)。garbled な結果になった場合は、この結果を見てから次の接続で別の候補を追加する。

`verify/harness-selftest/` は、この確認と「`CHGJOB INQMSGRPY(*DFT)` による RPG0102(OPM RPG III のゼロ除算照会。Part 5 が必要とするのもこちら)の自動応答」をまとめて行う、最初の実接続向けのバッチ。RPG III(`CRTRPGPGM`)を使っている。ILE(`CRTBNDRPG`)では `RNQ0102`/`RNX0102` になり別の話になるので注意。

## 実行結果の保存

`work/verify/results/<batch>-<timestamp>.json` に保存する。実名は `verify/lib/anonymize.mjs` で `<USER>`/`<USER>1`/`<USER>2`/`<USER>B` に置換してから書き込む。`work/` は `.gitignore` 済みなのでコミットされない。教材やレッスンに転記するときは、この結果ファイルの anonymize 済みの内容から書き起こす。
