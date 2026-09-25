# 第3部 CL プログラミング

## この部の目標

CL プログラムを自分で書けるようになります。変数・分岐・繰り返し・エラー処理・コマンド呼び出し・バッチ投入まで、実務でよく使う範囲を一通り身につけます。

## 道具

5250(PDM/SEU)。

## 観測方法

`DSPJOBLOG`。

## この部で自分たちが作る道具

`EXPSRC`(ソースを IFS に書き出す)、`SETENV`(開発/本番の切り替え)、`BACKUP`(週次バックアップ)、`JUMSGF`(自分のメッセージ・ファイル)。

## この部で扱わないこと

`SNDRCVF` を自分で書くこと(読むのは第5部)、`OPNQRYF` を書くこと(読むのは第5部)、ILE CL(第7部で扱います)。

## レッスン一覧

- [03-01 CL の骨格とコンパイル・リスト](03-01-cl-skeleton.md)
- [03-02 変数(1): *CHAR だけで書く](03-02-variables-char.md)
- [03-03 変数(2): 数値・論理と文字列操作](03-03-variables-numeric-string.md)
- [03-04 IF・ELSE・DO](03-04-if-else-do.md)
- [03-05 繰り返しと SELECT](03-05-loops.md)
- [03-06 MONMSG(1): コマンド・レベルと存在チェック](03-06-monmsg-1.md)
- [03-07 MONMSG(2): エラー処理の骨格と自分のメッセージ・ファイル](03-07-monmsg-2.md)
- [03-08 パラメーターと CALL の罠](03-08-parameters-and-call.md)
- [03-09 DCLF/RCVF: 受注照会の CL 版](03-09-dclf-rcvf.md)
- [03-10 *OUTFILE・QTEMP・OVRDBF: EXPSRC を作り、TXSETUP を読む](03-10-outfile-qtemp-ovrdbf.md)
- [03-11 自作コマンド: JUCINQ・EXPSRC・SETENV](03-11-custom-commands.md)
- [03-12 バッチ・ジョブ: 投入・監視・停止とジョブ日付](03-12-batch-jobs.md)
- [03-13 CL 実践: 夜間ジョブストリーム JUYAKC](03-13-batch-practice-juyakc.md)
- [03-14 チェックポイント: BACKUP コマンドを作る](03-14-checkpoint-backup.md)
