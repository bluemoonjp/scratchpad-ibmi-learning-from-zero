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
- 直近24時間で8回まで。`auth_failed`/`refused_or_timeout`/`blocked` のいずれかが台帳に一度でもあれば、以後ずっと8回のまま(「遮断が一度も起きなければ12回まで」の緩和は使わない)。
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
  "steps": [
    { "type": "file", "localPath": "src/foo.rpgle", "remoteSrcFile": "QRPGLESRC", "member": "FOO", "ccsid": 37 },
    { "type": "cl", "label": "COMPILE", "cmd": "CRTBNDRPG PGM(&LIB/FOO) SRCFILE(&LIB/QRPGLESRC) SRCMBR(FOO)", "monmsg": ["CPF0000"] },
    { "type": "cl", "label": "RUNIT", "cmd": "CALL PGM(&LIB/FOO)" },
    { "type": "collect", "kind": "sql", "sql": "任意のSELECT文(省略時はSYSTOOLS.SPOOLED_FILE_DATAの既定クエリー)" }
  ]
}
```

- `file` ステップ: `localPath`(このマニフェストのディレクトリーからの相対パス)の中身を heredoc で転送し、`setccsid` で CCSID を付け、`CPYFRMSTMF` で `library` の `remoteSrcFile`/`member` に取り込む。
- `cl` ステップ: 1本の CL ラッパー・プログラムにまとめてコンパイル・実行する(`verify/lib/clgen.mjs`)。各ステップは個別の `MONMSG` で囲み、失敗しても次のステップへ進む。`cmd` 内の `&LIB` は生成時に実際のライブラリー名へ文字列置換される(CL の実行時変数ではない。`CALL...PARM()` の32バイト・パディング問題を避けるため)。**ハングの恐れがあるステップは必ず配列の最後に置くこと。**
- `collect` ステップ: 結果をテキストで回収する。既定は自分のジョブ・自分のユーザーに絞った `SYSTOOLS.SPOOLED_FILE_DATA` からのSELECT(`db2 -s` 経由)。

## 既知の未検証事項(次回の実接続で確認し、docs/probes.md に記録する)

- `qsh` の `system()` 呼び出しが同一ジョブ内で連続するか(違えば `QTEMP` は使えない)。本ハーネスはこれに依存しない設計にしてある(1本の CL ラッパーにまとめて `CALL` する)。
- `SYSTOOLS.SPOOLED_FILE_DATA` の実際の呼び出し方(引数の形)。`collect` の既定クエリーは最有力候補であり、失敗する可能性がある。
- `CPYFRMSTMF ... STMFCCSID(37)` で正しく取り込めるか(CCSID 37 と 273 のどちらを使うべきかは `docs/probes.md` の既存の知見を優先し、必要なら候補を複数同じバッチで試す)。

`verify/harness-selftest/` は、この確認と「INQMSGRPY(*DFT) による RPG0102 の自動応答」をまとめて行う、最初の実接続向けのバッチ。

## 実行結果の保存

`work/verify/results/<batch>-<timestamp>.json` に保存する。実名は `verify/lib/anonymize.mjs` で `<USER>`/`<USER>1`/`<USER>2`/`<USER>B` に置換してから書き込む。`work/` は `.gitignore` 済みなのでコミットされない。教材やレッスンに転記するときは、この結果ファイルの anonymize 済みの内容から書き起こす。
