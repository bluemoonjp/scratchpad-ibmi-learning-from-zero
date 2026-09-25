# 実機プローブの結果

PUB400 上で実際に確認した事実を、日付付きで記録します。プローブ番号(P01〜P44)は設計時のロードマップに対応します。

**表記の約束:** 実在のユーザー名・ライブラリー名は `<USER>` に置き換えて記録します(このリポジトリーは公開のため)。著者側の検証には `<USER>1`(著者の私的な学習領域)を使わず、`<USER>2` を使います。

## P01: 自分のライブラリー構成(読み取り専用、確認日 2026-09-24)

SSH(qsh 経由、`db2` で SQL 実行)で、自分の名前を持つ 3 つのライブラリーの中身を確認した。

```sql
SELECT OBJNAME, OBJTYPE, OBJOWNER
  FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>1','*ALL')) X
 ORDER BY OBJNAME FETCH FIRST 10 ROWS ONLY;

SELECT OBJNAME, OBJTYPE, OBJOWNER
  FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>2','*ALL')) X
 ORDER BY OBJNAME FETCH FIRST 10 ROWS ONLY;

SELECT OBJNAME, OBJTYPE, OBJOWNER
  FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>B','*ALL')) X
 ORDER BY OBJNAME FETCH FIRST 10 ROWS ONLY;
```

結果:

- **`<USER>1`**: オブジェクトあり(10 件以上。ソース物理ファイル QCLSRC/QDDSSRC/QRPGLESRC/QRPGSRC/QCBLLESRC/QCPPSRC と、プログラム数本)。**著者の私的な学習領域として既に使用中。本カリキュラムの著者側検証では使わない。**
- **`<USER>2`**: 存在するが **0 件(空)**。
- **`<USER>B`**: 存在するが **0 件(空)**。

**結論**: 3 つのライブラリー(`<USER>1`/`<USER>2`/`<USER>B`)は実在する。PUB400 のアカウントには標準でこの 3 つが割り当てられる、という調査時の情報(2016 年の welcome.pdf、および 2026 年の複数アカウントでの確認例)と一致する。

**著者側の検証方針(確定)**: 以後のすべての実機検証は `<USER>2` を使う。`<USER>1` には触れない。

**影響**: 01-04, 01-05, 05-12, 06-02, 08-08。全体方針 §7(ライブラリーの使い分け)。

## 環境の基礎情報(P01 と同じセッションで確認、確認日 2026-09-24)

```sql
SELECT OS_VERSION, OS_RELEASE, HOST_NAME FROM SYSIBMADM.ENV_SYS_INFO;
```

結果: `OS_VERSION=7`, `OS_RELEASE=5`(IBM i 7.5)。ホスト名 `WWW.PUB400.COM`。

```sql
SELECT AUTHORIZATION_NAME, STORAGE_USED, MAXIMUM_STORAGE_ALLOWED
  FROM QSYS2.USER_STORAGE WHERE AUTHORIZATION_NAME = CURRENT_USER;
```

結果: 使用量 79,568 KB / 上限 1,000,000 KB(約 1GB)。既存の学習作業でも容量には十分な余裕がある。

**注記**: `QSYS2.USER_STORAGE` は `WHERE AUTHORIZATION_NAME = CURRENT_USER` で自分自身に絞って使うこと。フィルターなしで実行すると他ユーザーの情報も返るため、2025-08 の一斉ロックアウト事例に鑑み、絶対に行わない(08-07 のレッスンにもこの注意を明記する)。

## P08: SSH・PASE・OSS ツールの有無(確認日 2026-09-24)

SSH の remote command として `/usr/bin/qsh` を直接起動し(ログイン・シェルの bsh は経由しない)、標準入力からシェル・コマンドを渡して確認した。

```text
echo PATH=$PATH
command -v git; git --version
command -v bash
command -v makei; makei --version
command -v python3
command -v gmake
command -v make
```

結果:

- `PATH=/usr/bin:.:/QOpenSys/usr/bin` — **既定の PATH に `/QOpenSys/pkgs/bin` は含まれない。**
- `bash`: `/usr/bin/bash` にあり、既定 PATH で見つかる。
- `make`: `/QOpenSys/usr/bin/make`(PASE 標準の make。GNU make と非互換なオプション体系)。
- `git`: 既定 PATH では **見つからない**(`qsh: 001-0019 Error found searching for command git.`)。
- `makei`: 既定 PATH では **見つからない**。

追加確認(`/QOpenSys/pkgs/bin/` を直接指定):

- `/QOpenSys/pkgs/bin/git` は実在する(`git version 2.47.0`)。
- `/QOpenSys/pkgs/bin/gmake`、`/QOpenSys/pkgs/bin/makei`、`/QOpenSys/pkgs/bin/python3` はいずれも実在する。
- `/QOpenSys/pkgs/bin/tobi` という名前のコマンドは **無い**(TOBi への改称後も、コマンド名は `makei` のまま)。
- `/QOpenSys/pkgs/bin/` には約 1.5GB 相当のパッケージ群がインストール済み(git・Python・GNU make・Ansible 等、多数)。

**結論**: git・GNU make・makei・python3 はすべて使えるが、**既定の PATH には入っていない。** SSH 経由の自動化(02-04 の `git clone`、08-01/08-02 の `makei` ビルド)では、フルパスを使うか、`~/.profile` に `export PATH=/QOpenSys/pkgs/bin:$PATH` を追記する必要がある。

**影響**: 02-04, 03-10, 08-01, 08-02。批評で確定した「中重大度」の修正(PATH の既定に関する項目)を、この実測で裏付けた。

## 接続方法の確認(確認日 2026-09-24)

SSH は `ssh -i <鍵> -p 2222 -o BatchMode=yes -o ConnectTimeout=20 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new <USER>@pub400.com /usr/bin/qsh` とし、シェル・コマンドや SQL スクリプトを **標準入力から** 渡す形で、鍵認証・1 回の接続で複数のコマンドをまとめて実行できることを確認した。パスワードプロンプトへの言及(`-> Enter your password for Logon below:`)はバナーの一部として常に stderr に出るが、鍵認証が成功していれば実害はない。

以後のプローブも、可能な限り 1 回の接続に複数の読み取り専用コマンドをまとめて実行し、接続回数を抑える。

## 接続数に関する注意(確認日 2026-09-25)

TOKUIM の転送・コンパイル検証に成功した直後、5 本のソースをまとめて `scp` しようとしたところ `Connection closed by <IP> port 2222` で即座に切断された(認証エラーではなく、TCP 接続確立の直後に切断)。短時間に 7 回程度の接続を行った後だったため、**同一 IP からの接続数制限に触れた可能性がある**(PUB400 のコミュニティ規約に明記されている `hard restriction on number of connections from a single IP` に該当すると推測)。このときは 15〜20 分ほど間隔を空けたところ、接続できる状態に戻った。

**その後、同じセッション内でさらに接続を重ねた結果、`ssh`(2222番)だけが `Connection timed out` で一切繋がらなくなった。** `Test-NetConnection` で確認したところ、**2222番(SSH)だけが不通**で、**992番(5250 TLS)と443番(HTTPS)は疎通していた。** 認証の失敗を1回も起こしていないにもかかわらず、短時間に多数(合計15回程度)の SSH 接続を行ったことが原因とみられる。

**対応(確定)**:

- 1回の接続で行う作業を、これまで以上にまとめる。
- 同じセッション内で SSH 接続を繰り返す場合、**目安として10回を超えたら、大きく間隔を空けるか、その日はそれ以上接続しない。**
- SSH だけが不通で 5250(992番)は生きている場合がある。**5250 は影響を受けないため、SSH が使えない間は 5250 で進められるレッスンに切り替える**(全体方針 §2 の「SSH が使えない場合のルート」に反映する)。
- この種のブロックが解除されるまでの時間は今回は未計測(私的な学習記録にある「鍵の連続認証失敗による約1日のブロック」とは別の現象とみられる。認証失敗を伴わない、純粋な接続数によるものである可能性が高い)。

**影響**: P37(接続数の確認)。全体方針 §10(接続数と容量の予算)、および §2(SSH が使えない場合のルート)に、この実測を反映する。TXSETUP の実機検証(コンパイル・エラーは残り1件まで絞り込み済み)は、次回 SSH が復旧してから再開する。

## TXSETUP の実機デバッグで分かった CL の落とし穴(確認日 2026-09-25)

`<USER>2` でサンプル DB の DDS 一式(TOKUIM 等6物理ファイル+2論理ファイル)を実際にコンパイルし、CL ツール(TXSETUP)を実装・コンパイルする過程で、次の CL の仕様を実機のコンパイル・リストから確認した。教材(第3部・第4部)にも反映する。

- **`PARM()` で受け取る変数の `DCL` に `VALUE()` を書くとエラーになる**(`CPD0702`)。既定値が要る場合は、`PGM` の直後で `IF COND(&VAR *EQ ' ') THEN(CHGVAR ...)` のように後から代入する。
- **`ADDLIBLE` は SSH 経由の `system` コマンドを跨いで持続しない。** `system "CL コマンド"` は呼ぶたびに別ジョブになるため(01-08 の実機メモと同じ現象)、`ADDLIBLE` の効果を次の `system` 呼び出しで使うことはできない。ライブラリー・リストを変更してから使う処理は、**同じ CL プログラムの中で完結させる**必要がある。
- **論理ファイルの `PFILE()` キーワードにライブラリー名を書かない場合、`*LIBL` で探す。** 配布用の DDS ソースにライブラリー名を焼き込みたくない場合、`CRTLF` の前に `ADDLIBLE` で対象ライブラリーをライブラリー・リストに入れておく必要がある(上記の「別ジョブ」問題と合わせて、1つの CL プログラム内で行うこと)。
- **`RTVJOBA` でジョブのユーザーを取得するキーワードは `USRPRF` ではなく `USER`。**(`CPD0043`)
- **`%LOWER(%TRIM(&VAR))` のように組み込み関数を直接ネストすると `CPD0181` になる。** いったん `CHGVAR` で中間変数に代入してから、もう一段階 `CHGVAR` で関数を適用する。
- **`ADDPFM` の `SRCTYPE` は `*PF`/`*LF` のような CL 特殊値ではなく、`PF`/`LF` という単なる文字列。** アスタリスクを付けると `CPD0133` になる。

**影響**: 03-01(コンパイル・リストの読み方)、tools/qclsrc/txsetup.clp。

## TXSETUP・TXRESET の続報(確認日 2026-09-25)

SSH が復旧してから、上記の4件を修正した版を実機で再コンパイルしたところ、さらに1件見つかった。

- **`SNDPGMMSG` に `MSGTYPE(*ESCAPE)` を指定すると、`MSG()` の自由形式テキストではなく `MSGID` が必要になる**(`CPD2489`)。`*ESCAPE`・`*NOTIFY`・`*STATUS` のような正式なメッセージ種別は、メッセージ・ファイルに登録された定型メッセージを前提にしている。自前のメッセージ・ファイルを用意しない簡易なエラー処理では、`MONMSG` を付けずに**元のコマンドの失敗メッセージをそのまま未処理のまま伝播させる**(プログラムが異常終了し、その失敗の本来のメッセージが呼び出し元に伝わる)のが簡単で確実。

この修正により、**`TXSETUP` と `TXRESET` は 0 エラーでコンパイルできることを確認した。**

- **`CALL` はライブラリー修飾が要る場合がある。** `system` 経由の `CALL PGM(TXSETUP)`(無修飾)は、コンパイル先のライブラリーがそのジョブの `*LIBL` に入っていないため `CPD0170`(見つからない)になった。`CALL PGM(<LIB>/TXSETUP)` と修飾したところ解決した。
- **`CALL` にパラメーターを一切付けずに実行すると `CPD0172`(渡されたパラメーターが必要なものと一致しない)になった。** 3つの `*CHAR` パラメーターを宣言しているプログラムに対し、`CALL PGM(...)`(パラメーターなし)で呼んだ場合の挙動で、CL プログラムなら本来「渡されなかった分は既定値」で済むはずだが、コマンド行(または `system` 経由の呼び出し)からは同様に振る舞わない場合があるとみられる。**`CALL PGM(...) PARM(値1 値2 値3)` のように、宣言した数だけ明示的に値を渡すことで解決した。** 原因の詳細は未特定。03-08(パラメーターと CALL の罠)で扱う。

**影響**: 03-01, 03-08, tools/qclsrc/txsetup.clp, tools/qclsrc/txreset.clp。

**実行そのものの検証は未完了。** `CALL PGM(AOTSUKI2/TXSETUP) PARM(...)` を投入したセッションが、長時間(30分以上)応答を返さなかった。認証やコンパイルまでは正常に完了していたことから、`RUNSQLSTM` か、いずれかの `CRTPF`/`CRTLF` の呼び出しで待ち状態になっている可能性がある。**競合を避けるため、応答のないセッションと並行して新しい SSH 接続は行わず、この検証は次回のセッションに持ち越す。** 次回は、この待ち状態の原因(ロック待ち、照会メッセージ待ち等)を切り分けてから再実行する。

## 未実施のプローブ

P02〜P44 のうち、上記(P01, P08 の一部)以外は未実施。特に:

- 破壊的な操作を伴うもの(P05, P06, P10, P19, P22, P23 等)は、TX ツール実装(フェーズ2)と合わせて慎重に実施する。
- 新規アカウントが必要なもの(P02, P41)は、ベータ・テスターの協力を得るか、一次資料 + 私的な既存実測(匿名化)で代替する。
