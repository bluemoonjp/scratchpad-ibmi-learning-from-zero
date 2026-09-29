# part10-00-probe の期待値(手計算、実機未確認)

第10部の前提確認(H0、`work/design/part10-design-v3.md` 6節H0)の安全側。
`<USER>2`のDBVER(サンプルDBの版)は変えない。DBVER 2に上げる手順は
`verify/part10-00b-dbver2`に分けてある。**この接続を先に実行する。**

前提: `<USER>2`にDBVER 1のサンプルDBとレガシー・プログラムがある
(第5部のTXSETUP/TXLEGACY済み)。

## 読む順序(ゲート)

1. `VFYLOG`の`TXSTATUS: DBVER=`行(ST0LIB, ST0LIB2)。`<USER>2`が`0000000001`で
   なければ、以降の期待値は成立しない。
2. `VFY10CNT`の`P0-PRE`行: `JUCHUM cols`=4、`JUDLV col`=0(v1)。
3. `VFYLOG`に`FAILED`で終わる行が無いこと(ステップ単位のMONMSGで握りつぶされる)。

## ステップごとの合格基準

| ステップ | 何を試すか | 合格基準 | 実際の結果を記録するもの |
|---|---|---|---|
| 1 RESTOBJ探索 | `RESTOBJ`を**呼ばず**に存在を調べる(引数名はDSPCMDの印字に出れば読む。**出る保証は未確認**で、設計H0.1の「引数名が印字される」合格条件は、この接続では存在確認までしか保証しない) | `P1-QSYS-CMD`行と`OBJECT_STATISTICS('QSYS','*CMD')`のcollectで、`RSTOBJ`が見つかる | `RESTOBJ`が存在するか(存在しなければ第10部はRESTOBJを使わない)。sh-afterの`DSPCMD`/`DSPOBJD`の出力(runセクション)。DSPCMDの印字が引数を含まなければ、引数の確認は未解決のまま(SYSPARMSはSQLルーチンの引数表でありCLコマンドは載らないため、collectは置かない) |
| 2 TXLEGACY FORCE(*YES) 2回目 | ロード済みライブラリーの再構築。**前提: `P2-BEFORE`に`TXLEGST`が載っていること**(無ければ初回ビルド扱いでSAVFは作られない) | `P2-AFTER`の`OBJCREATED`が`P2-BEFORE`より新しい(ZA0500/JU0900C/JU0300/TK0100/MN0000C)。`TX10SAV`が`SAVF exists: <USER>B/LG...`を出す | SAVF名(`LG`+QDATEの実際の形)。DSPSAVFの内容にJU0900Cが無いこと(S17)。`TXLEGST`の作成日時が変わるか |
| 3 TXRESET | データだけ初期化 | `P3-RESET`: JUCHUM=8, JUCHUD=12, ZAIKOM=6, `ZAIKOM sum ZASU`=392, J00000/C05119=0 | JUCHUM/JUCHUD/ZAIKOMの実際の行数(=設計の「12行8受注」の裏付け) |
| 5(DBVER 1) 列指定INSERT | `INSERT INTO JUCHUM (JUNO, JUTOK, JUDATE, JUTAN) ...` | `P5-V1`: INSERT後の`J00000`行=1、DELETE後=0 | v1で通ること(TXCAPSTの土台) |
| 6 TESTKIT前提 | 既存オブジェクトの有無だけ確認 | `P6-LIB`/`P6-LIB2`行(TSTJUCSRV, TSTZAISRV, TESTKIT, TESTKITBD, JUCSRV, ZAISRV, ZAISRVBD, JUCSRVBD, TESTRES) | どのライブラリーにあるか。**存在確認のみ(ビルドは10-03のH3)** |
| 追加 RTVMSG | `RTVMSG`の実演(10-01読解用ボックス) | `VFYLOG`に`TX10MSG CPF9898 first level:`/`second level:`行。CPF4174, CPC1221も同様 | CPF9898の実文(`&1`のみのはず)。CPF4174の実文 |
| 追加 TXCHECK | 同一ジョブ2回目はCPF4174、別ジョブなら通る | wrapper内`TXCHK1`(TXCHKRUN)で`0000000004 passed,`/`0000000000 failed.`。sh-afterの`CHKJOB2`/`CHKJOB3`(別ジョブ)も同じ2行 | CHKJOB2/3が通らない場合はライブラリー・リスト等の別原因(TX10CHKはADDLIBLE済み) |
| 4 チケット1修正 | `JU09T1`から直接JU0900Cをコンパイル(メンバーJU0900Cへの`CPYSRCF`は`FIXMBR`。失敗すると`VFYLOG`に`FIXMBR FAILED`)し`*TEST`で実行 | **wrapperの最後のclステップ**`RUNFIXED`が12行(OK 10、SHORT 2)を印字し、RPG0907が出ない。最終collectの`ZAIKOM`が`P3`時点と同じ(`*TEST`は更新しない。`P4-BEFORE`の`ZAIKOM sum ZASU`と同値) | 印字行はrunセクションにある(SBMJOBではなく直接CALL。SBMJOB経路は10-01のH1) |

## 読み方の注意

- SAVF(`LG<QDATE>`)の確認は、その日の1回目の実行でだけ意味を持つ(同じ日に再実行すると既存のSAVFへのSAVOBJが取り消され、以前の内容が見えるだけになりうる)。

- 各`VFY10CNT`値は`RUNSQL`が成功して初めて行になる。行が無い=そのステップが失敗
  (`VFYLOG`の`FAILED`行を見る)。
- `RUNFIXED`が失敗またはハングした場合、それより前の結果はすべて
  `VFY10CNT`/`VFY10OBJ`に残っているので、collectだけ読めば足りる。
- `S1`(改修前のJU0900CがRPG0907 stmt 8100で必ず落ちる)はこの接続では再実行しない
  (`part05-ju0900c-baseline`で確認済み)。
- `TXLEGACY FORCE`は`<USER>B`に`LG<QDATE>`というSAVFを(無ければ)作り、既存の
  `TXLEGST`がある場合だけ退避する。`TXPRSAVF`は触らない。
- 実接続の前に`work/verify/handoff-10-00.md`の前提条件を読むこと。
