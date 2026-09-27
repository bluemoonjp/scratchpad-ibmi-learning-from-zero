# part05-txmigr-to2b(連結B)の期待値(手計算、実機未確認)

**この接続は `verify/part05-txmigr-to2`(連結A)の後にのみ意味を持つ。**
先に連結Aの `expected/notes.md`・実際の結果を読み、`RUNCHGPF`が成功し
`PROBEB`が`CPF4131 CONFIRMED`を示したことを確認してから、この接続に
進むこと(この接続自身のmanifest.json冒頭「Prerequisite check」参照)。
**この接続(B)を単独で再実行しないこと**——2回目のB実行は、1回目のB
自身が残した`DBVER=2`・修正済み`JUCHUL1`を前提にしてしまい、この
notes.mdの予想はすべて成立しなくなる(`manifest.json`のREVISION 4、
項目5参照)。再実行が必要な場合は、必ず連結Aから再度やり直すこと。

## この接続で答えたい、最大の未確定点

**`TXMIGR`自身の`Step 2`(`JUCHUL1`の再作成、`DLTF`無しの`CRTLF`のみ)は、
`JUCHUL1`が既に存在するこの状況で、本当に失敗するのか?**
`tools/qclsrc/txmigr.clp`自身のヘッダー・コメントは失敗を予想しているが、
実機ではまだ一度も確認していない。もし`db/v1/juchul1.lf`(`R JUCHUR
PFILE(JUCHUM)`、独自の項目リストを持たない)を`CHGPF`だけで自動的に
新しい`JUCHUM`の形へ追随させる何らかの機構が実際にはある場合(この
リポジトリーの一次資料では確認できていない)、`TXMIGR`のこの既知の
限界という前提自体が崩れる可能性がある——`SNAP2JL`がこれを直接判定する。

## 読む前に必ず確認すること(ゲート、2026-09-27追加、advisor再指摘)

**`VFYLOG`に`TXMIGR: done.`で始まる行が実際にあることを、以下
(特に6番`SNAP2JL`・7番`PROBEA`)のどの読み方よりも先に確認すること。**
**注意(2026-09-27再訂正)**: `TXMIGR: done. DBVER=2.`という**そのままの
文字列**で検索しないこと——`txmigr.clp`の`TXDONE`ラベルは
`CHGVAR VAR(&DBVERC) VALUE(&TO)`(`*DEC(3 0)`→`*CHAR(10)`変換)のあと
`%TRIM(&DBVERC)`で組み立てており、`verify/part05-13-tickets/expected/
notes.md`が既に確立した規則(`*DEC`→`*CHAR`変換はゼロ・パディングされ、
`%TRIM`は前後の空白しか取り除かない)どおりなら、実際に出る行は
`TXMIGR: done. DBVER=0000000002. Run TXSTATUS to check; update TXSTATE
by hand if this tool did not.`のはず(05-09本文が引用する
パディング無しの形とは食い違う——`TXCHECK`で既に見つかっている食い違いと
同種)。`TXMIGR: done.`という接頭辞だけで判定すること。
`tools/qclsrc/txmigr.clp`自身の`FAILSAFE`ラベルは`SNDPGMMSG ...
MSGTYPE(*COMP)`のあと**正常に**終わる(`*ESCAPE`を投げ直さない)ため、
`RUNTXMIGR`ステップ自身が`VFYLOG`で`FAILED`と出ることは無い。`TXMIGR`の
`Step 1`(`CPYFRMSTMF`+`CHGPF`)自身にはステップ単位の`MONMSG`が無く、
プログラム・レベルの`MONMSG(CPF0000, GOTO FAILSAFE)`だけが安全網になって
いる——たとえば連結Aの`CVTJUCHUM2`が置いた`$HOME/ibmi-kyozai/db/v2/
juchum.pf`が何らかの理由でこの接続の時点で無くなっていた場合、`TXMIGR`は
`Step 1`の時点で`FAILSAFE`に落ち、`Step 2`/`Step 3`は一度も実行されない。
このゲート文言が無いと、その状態が「`Step 2`が予想どおり失敗した」+
「`Step 3`がたまたま`RUNPROBE`まで届かなかった」という、もっともらしいが
**誤った**読み方に見えてしまう。同様に、連結A自身の`VFYLOG`に`TXSETUP:
done. DBVER=1.`があることも(連結A側で)確認済みであることが前提。

## 各ステップの期待値

1. **`CPTXMIGRRW`(未`PRIME`のコンパイル)**: `tools/qclsrc/txmigr.clp`
   自身のコメントが警告する「`DCLF`が`QTEMP/TXMDBR`・`QTEMP/TXMPGM`を
   コンパイル時に必要とするが、これらは通常は実行時にしか作られない」
   という懸念どおりなら、ここで`CRTCLPGM`自体が失敗する可能性がある。
   失敗しても`MONMSG`で捕捉され、後続の`PRIMEDBR`/`PRIMEOBJ`/
   `CPTXMIGR`(再試行)へ進む。**2026-09-27追加(第3回advisor指摘で発見・
   修正済みの別のバグ)**: `txmigr.clp`の`DCLF`は`OPNID(D)`/`OPNID(P)`
   (単一文字)を使っている——以前の版は`OPNID(TXMDBR)`/`OPNID(TXMPGM)`
   だったが、`ibm.com/docs`(`dclf.htm`、2026-09-27 WebFetchで確認済み)
   が明記する「`OPNID`は`&値_項目名`という形で変数名を置き換える」という
   仕組みにより、以前の版はこの置き換え後の名前(`&TXMDBR_WHRELI`等)へ
   本文の参照を直していなかった——つまり以前の版の`&WHRELI`・`&WHREFI`・
   `&ODOBNM`・`&ODOBAT`はどれも**未宣言の変数**になっており、これだけで
   `CPTXMIGRRW`・後続の`CPTXMIGR`の**どちらも確実にコンパイル失敗して
   いたはず**(これは実演前の静的レビューで確定した欠陥)。**なお、
   もし仮に本文の参照を`&TXMDBR_WHRELI`のように正しく直していたとしても、
   その名前自体がCLの変数名として合法かどうかは別途未確定のまま**
   (WebSearchでは「`&`込みで最大11文字」という一般則が見つかったが、
   同じ`dclf.htm`ページ自身の例`&FILE1_CUSTNAME`は`&`抜きで14文字あり、
   この一般則がOPNID生成名にもそのまま適用されるかどうかは矛盾する
   証拠がある——`txmigr.clp`自身のヘッダー・コメント参照)。今回
   `OPNID(D)`/`OPNID(P)`という短い識別子を選んだのは、この未確定な
   長さの問題自体を回避するための保守的な選択であって、「11文字制限を
   確認したから」ではない。もしこの接続で`CPTXMIGRRW`/`CPTXMIGR`が
   それでも失敗した場合、まず疑うべきは`QTEMP/TXMDBR`・`QTEMP/TXMPGM`
   がコンパイル時に存在しない問題(このファイル自身の別の「UNVERIFIED」
   注記、`CPTXMIGRRW`/`PRIMEDBR`/`PRIMEOBJ`/`CPTXMIGR`という段取り
   そのものが対処しようとしている懸念)であり、`OPNID`絡みの変数名の
   長さそのものではない。
2. **`PRIMEDBR`/`PRIMEOBJ`**: `&LIB/QCLSRC`という確実に存在するオブジェクト
   に対して`DSPDBR`/`DSPOBJD`を実行し、`QTEMP/TXMDBR`・`QTEMP/TXMPGM`を
   同一ジョブ内に作る「呼び水」。
3. **`CPTXMIGR`(再試行)**: `QTEMP`が呼び水で埋まった状態での再コンパイル。
   `CPTXMIGRRW`が成功していれば、これは単なる`REPLACE(*YES)`の再実行に
   すぎない。`CPTXMIGRRW`が失敗し`CPTXMIGR`も同様に失敗した場合、
   `TXMIGR`自体がこのジョブでは一度もコンパイルできず、`RUNTXMIGR`
   (`&LIB/TXMIGR`のCALL、`QCMDEXC`経由)はオブジェクト不在のエラーに
   なるはず——この場合、以降のステップ(`STATUS2`以降)はすべて
   「`TXMIGR`が一度も走っていない」という前提で読み直すこと。
4. **`RUNTXMIGR`**: 成功すれば、内部で`Step 1`(`CHGPF`の再実行、
   `ADDPFM`は`CPF7306`で無害に失敗、`CHGPF`は冪等に同じ形を再適用)・
   `Step 2`(`DSPDBR`→`JUCHUL1`の`CRTLF`試行)・`Step 3`(`&LIB2`内の
   全`*PGM`再コンパイル)を順に実行する。`Step 2`の`CRTLF`が失敗すれば
   `TXMIGR: could not recreate JUCHUL1.`という行がVFYLOGに出るはず
   (本命)。`Step 3`は`JU0900C`・`ZA0500`・`JU0300`・`RUNPROBE`の
   4本すべてを、現在の(`JUCHUL1`再作成の成否によらない)ソースから
   無条件に再コンパイルする——このうち`JU0900C`・`ZA0500`・`RUNPROBE`
   は`JUCHUM`にしか依存しないので、`Step 1`のCHGPF後なら**必ず**
   最新の様式レベルIDを焼き込み直せるはず(`JU0300`だけが`JUCHUL1`
   経由の間接依存を持つため、`Step 2`の成否に左右される)。
5. **`STATUS2`**: `TXMIGR`自身が`CHGDTAARA`を一度も呼ばない(`txmigr.clp`
   自身のコメント・`SNDPGMMSG`本文で確認済み)ため、`RUNTXMIGR`が
   成功していても`DBVER=0000000001`のままのはず——これは異常ではなく、
   `TXMIGR`の既知の未実装部分をこの接続で再確認しているだけ。
6. **`CLNFDJB`(新設、`SNAP2JL`の直前)**: `&LIB2/FDJL1`・`&LIB2/FDJL2`を
   先に`DLTF`で消しておく(連結A自身の`CLNFDJA`/`CLNFDJB`と同じ理由
   ——`DSPFD OUTPUT(*OUTFILE)`のOUTMBR既定動作を確認しきれなかったため
   の予防措置、`manifest.json`のdescription参照)。\
   **`SNAP2JL`(新設)**: `TXMIGR`実行直後・手動修正より前の`JUCHUL1`
   構造。**比較対象は連結Aの`FDJL0`ではなく`FDJL0B`にすること**
   (2026-09-27再訂正、advisor指摘)——`FDJL0B`は「`CHGPF`は既に
   起きたが`JUCHUL1`はまだ何も変わっていないはず」の時点を連結Aの
   最後に確認した値で、`SNAP2JL`と本当に比較すべきなのはこちらである
   (`FDJL0`はさらに前、`CHGPF`より前の値なので、`CHGPF`自体が
   `JUCHUL1`に何か影響を与えていた場合はこの2つが一致しない可能性が
   あり、その場合は`FDJL0B`の方を基準にする——連結A自身のnotes.md
   5番参照)。読み方(`DSPFD *RCDFMT`の実際の列がまだ未確認のため、
   `JUDLV`という文字列だけに頼らない——連結A自身のnotes.md2番と同じ
   注意):
   - `SNAP2JL`(`FDJL1`)の行が**`FDJL0B`と一致すれば**: `TXMIGR`自身の
     `Step 2`(`CRTLF`のみ、`DLTF`無し)が予想どおり失敗し、`JUCHUL1`が
     まだ古い形のまま、ということ(本命)。
   - **異なっていれば**: 予想が外れたことになる——`TXMIGR`の`CRTLF`が
     実際には成功したことになる。この場合`txmigr.clp`自身のヘッダー・
     コメントの前提(「`CRTLF`には`REPLACE`が無いので既存`JUCHUL1`
     相手にはほぼ確実に失敗する」)を実機の事実に合わせて見直す必要が
     ある(接続前には直さない、というこのリポジトリー自身の方針どおり、
     見直しは次のセッションに持ち越すこと)。
7. **`PROBEA`(新設。連結A自身のnotes.md6番と同じ2026-09-27再訂正
   ——`src/runprobe.clp`の`MONMSG`フォールスルー欠陥を`EXEC(DO)...GOTO
   CMDLBL(CLOSE)...ENDDO`形に修正済み。以下は修正後の前提)**: `RUNPROBE`
   は`Step 3`で再コンパイルされている
   はずなので、**`RUNPROBE: RCVF succeeded and read a JUCHUM row - no
   CPF4131, format levels agree.`が出るのが本命**(`JUCHUM`の様式は
   `Step 1`のCHGPFで既に新しくなっており、`RUNPROBE`もそれに合わせて
   再コンパイルされたはずだから)。もし代わりに`RUNPROBE: CPF4131
   CONFIRMED`が再び出た場合、`TXMIGR`の`Step 3`(全`*PGM`再コンパイル)
   が`RUNPROBE`まで実際には届いていない(コンパイル失敗、または
   `DSPOBJD`が`RUNPROBE`を`*PGM`として正しく検出できていない等)ことを
   意味する——`VFYLOG`の`TXMIGR: could not recompile RUNPROBE (CLP).`
   のような行の有無を確認すること。
8. **`DLTJUL1`/`CRTJUL1`/`CPJU0300F`(05-09の手作業手順5-6そのもの)**:
   `TXMIGR`自身の`Step 2`の成否によらず、必ずこの3ステップで
   `JUCHUL1`を`db/v2`相当の(現在のJUCHUMに追随した)形に作り直し、
   `JU0300`をそれに対して再コンパイルする。`DLTJUL1`は`JUCHUL1`が
   (古い形であれ`TXMIGR`が既に作り直した新しい形であれ)必ず存在する
   はずなので、通常は成功するはず。**`CPJU0300F`は`DLTPGM PGM(&LIB2/
   JU0300)`(`MONMSG CPF0000`)を`CRTRPGPGM REPLACE(*YES)`の前に必ず
   実行する**(2026-09-27追加、`verify/part05-13-tickets`の既存の
   慣例と同じ理由、advisor指摘)——`DLTPGM`を挟まずに`REPLACE(*YES)`
   だけに頼ると、この再コンパイルが何らかの理由で失敗した場合、
   古い(`TXMIGR`の`Step 3`が作った、または連結Aで作った)`JU0300`が
   静かに残ってしまい、それが偶然動いてしまった場合に「修正が効いた」
   と誤認する恐れがある。`DLTPGM`を先に行っておけば、`CRTRPGPGM`が
   失敗した場合`JU0300`は**存在しなくなる**ので、次の`RUNJU0300`は
   オブジェクト不在のエラーになるはずで、「コンパイル自体が失敗した」
   ことがすぐ分かる。**`CPJU0300F`が実際に失敗した場合、まず疑うべきは
   `CVTOPT(*NONE)`(既定値、この`CRTRPGPGM`は明示していない)と新項目
   `JUDLV`(L型/DATE)の組み合わせが、この店(GENLVL)でコンパイルを止める
   ような診断メッセージを出していないか**(`manifest.json`のdescription
   のREVISION 2、`QRG4008`の実例参照——このリポジトリーには`CVTOPT(*NONE)`
   でDATE型を無視するケースが実際に severity 00 で通ることを裏付ける
   一次資料が無い)。`TXMIGR`の`Step 3`による`JU0900C`・`RUNPROBE`の
   再コンパイル(どちらも`JUCHUM`を直接参照)も同じ組み合わせを初めて
   踏むので、`RUNTXMIGR`自体が失敗した場合も同様にこの可能性を疑うこと。
9. **`SNAP3JL`(新設)**: 手動修正後の`JUCHUL1`構造。`FDJL2`の行は
   **`FDJL0B`/`FDJL0`とは必ず異なるはず**(`JUDLV`という項目名、または
   レコード長/項目数のいずれか——連結A自身のnotes.md2番と同じ注意)
   ——`TXMIGR`の`Step 2`の成否と無関係に、この接続自身の`CRTLF`が
   `&LIB2/QDDSSRC/JUCHUL1`(現在の`db/v2`相当のDDSソース)から作り直す
   ため。
10. **`CHGDBVER`/`STATUS3`**: `DBVER=0000000002`になるはず(05-09の手順9、
    `TXMIGR`が自分ではやらない分を手作業で仕上げる)。
11. **`RUNJU0300`(最後のステップ、この接続の中で唯一の初回実行)**:
    **`CPJU0300F`が実際に成功していれば**(上記8番の`DLTPGM`先行の
    おかげで、失敗時は`JU0300`がオブジェクト不在になっているはずなので、
    ここに到達する時点で成功は確認できる)、直前の`CRTJUL1`が作った
    **現在の**`JUCHUL1`の様式レベルIDを直前の`CPJU0300F`が必ず焼き込んで
    いるため、**この呼び出しの時点で`JU0300`と`JUCHUL1`の様式レベルIDが
    一致しないという状況は、構造的に起こり得ない**(再コンパイル直後に
    同じ接続内で即座に呼んでいるため)。つまり`RUNJU0300`は「`JUCHUL1`/
    `JU0300`間の`CPF4131`が実際に消えたこと」を新たに実証するものではなく
    (それは`SNAP2JL`/`SNAP3JL`の構造的比較が担う)、「一度も実行した
    ことが無いこの`JU0300`というプログラムが、依存関係を正しい順序で
    揃えた状態で、ハングも予期しないエラーも無く最後まで動くか」を
    確認するものである。`ju0300.rpg`自身のヘッダー・コメントが挙げる
    未検証事項——(a) `LR`欄(7-8桁目)への総合計行の条件付け(design
    deviation 2、`ZA0500`の`MR`とは桁位置が違うので前例にならない)、
    (b) `CT`という実行時配列(E仕様書、要素数指定なしのRUNTIME
    array、design deviation 3)、(c) `UDS`(I仕様書のユーザー・データ域
    データ構造、`*LDA`の11-16桁目、design deviation 4)——のいずれかが
    原因で、コンパイル自体が失敗する(`CPJU0300F`の時点でMONMSGに
    掛かる)可能性も含めて、正直に結果を記録すること(「`RGZPFM`」は
    `ju0300.rpg`自身のヘッダーには登場しない——別マニフェスト
    `part05-mch1202-corrupt`が検討して不採用にしたコマンドであり、
    このリポジトリー内の別の文脈と混同していた誤記だったので訂正した)。

## collect の読み方

- 1本目(`FDJL1`、`SNAP2JL`の`SELECT *`): 上記6参照。
- 2本目(`FDJL2`、`SNAP3JL`の`SELECT *`): 上記9参照。`FDJL0`/`FDJL0B`
  とは必ず異なっているはず。
- 3本目(`OBJECT_STATISTICS`): 連結A自身の最終`collect`(同じクエリー)
  と並べて読む。`JUCHUL1`の`OBJCREATED`はこの接続の`CRTJUL1`の実行
  時刻に更新されているはず(`TXMIGR`自身の`CRTLF`が先に成功していた
  としても、この接続の`CRTJUL1`がその後で再度上書きするため、
  `OBJCREATED`だけからは「`TXMIGR`自身が成功したか」を判定できない
  ——上記の理由により`manifest.json`のdescriptionで既に注記済み)。
  `JU0300`/`JU0900C`/`ZA0500`/`RUNPROBE`の`OBJCREATED`は、いずれも
  この接続(`TXMIGR`の`Step 3`、または`CPJU0300F`)の実行時刻に近い
  はずで、連結Aの同じクエリーの値(`RUNCHGPF`直後、まだ`TXMIGR`を
  呼ぶ前)より新しいはず——古いままなら、その特定のプログラムが
  実際には再コンパイルされていないことを意味する。

## この接続後に &LIB2 へ残る状態

`JUCHUM`/`JUCHUL1`ともに`db/v2`相当の形(`JUDLV`あり)。`JU0900C`/
`ZA0500`/`JU0300`/`RUNPROBE`はいずれも現在の形に対して再コンパイル済み
(`TXMIGR`の`Step 3`経由、`JU0300`のみさらに`CPJU0300F`で二重に)。
`TXSTATE`は`DBVER=2`。以降このライブラリーに接続する他のマニフェストは、
`JUCHUM`/`JUCHUL1`が(05-13検証系のマニフェストが前提とする`&LIB`側の
DBVER=1状態とは違い)既に`DBVER=2`であることを踏まえること——ただし
05-13系マニフェスト(`part05-13-tickets`等)はいずれも`&LIB`(既定の
開発役)を対象にしており、この接続が触るのは`&LIB2`(`*B`)のみなので、
現時点では両者は独立している。
