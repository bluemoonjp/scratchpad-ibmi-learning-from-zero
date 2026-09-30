# IBM i / RPG III → RPG IV 学習カリキュラム

IBM i を全く触ったことがない方が、[PUB400.com](https://pub400.com/)(無料の公開 IBM i)を練習台にして、基礎コマンドから CL プログラミング、RPG III の作成・保守、RPG IV(完全自由形式)を主力言語として使えるようになり、現代的な開発手法と、環境が許す範囲での API 化まで進むための独学用の教科書です。

## 現在の状態

**第0部〜第10部(全 11 部)の本文を書き終えています。** 第10部(総合演習)は、10-01〜10-04の主要な手順を非対話の SSH で実機確認しました(V2)。5250 の画面操作、学習者の手元の PC での rpglint、10-02の `TXSNAP`・`EXCEPT`、`TXLOAD`、実通信の `HTTP_GET` は未確認(V3)です。部ごとに実機で検証しながら書きましたが、5250 の対話操作など実機で確かめきれていない箇所は、各レッスンの「実機メモ」に未検証と明記しています。`main` ブランチへの公開は部ごとに進めています。進捗は [Issue 一覧](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で追えます(部ごとに 1 つの Issue があり、その部が書き終わると close されます)。

## 対象読者

- IBM i を触ったことがない
- 情報系の基礎知識がある(ファイル、プロセス、ジョブ、コンパイルといった概念を知っている)
- 何らかの言語でのプログラミング経験がある

他のオープン系言語(Node.js、Python、Java、PHP 等)そのものは扱いません。git や VS Code といった道具として使う範囲にとどめます。

## 学び方

- **[第0部 はじめに](docs/part00/index.md) から始めてください。**
- 練習環境は [PUB400.com](https://pub400.com/) の無料アカウントを使います。登録方法は第0部で説明します。
- 各レッスンは「説明 → 実演 → 同じ手順を対象を変えて繰り返す」の順で進みます。自分で答えを探させる形式の課題はありません。
- 進め方の全体像(依存関係・早回しルート・つまずいたときの代替)は [`docs/roadmap.md`](docs/roadmap.md) にまとめています。

## 構成

| 部 | 内容 |
|---|---|
| [第0部](docs/part00/index.md) | 準備(PUB400 登録、5250 エミュレーター) |
| [第1部](docs/part01/index.md) | 5250 と基本コマンド |
| [第2部](docs/part02/index.md) | データベースと教材の取り込み |
| [第3部](docs/part03/index.md) | CL プログラミング |
| [第4部](docs/part04/index.md) | RPG III を書く |
| [第5部](docs/part05/index.md) | RPG III を読む・直す(保守) |
| [第6部](docs/part06/index.md) | RPG IV 完全自由形式 |
| [第7部](docs/part07/index.md) | ILE とモジュール化 |
| [第8部](docs/part08/index.md) | モダン開発(git・VS Code・テスト) |
| [第9部](docs/part09/index.md) | API 化と外部連携(環境が許す範囲で) |
| [第10部](docs/part10/index.md) | 総合演習 |

詳しいレッスン一覧は [`docs/syllabus.md`](docs/syllabus.md) にあります。

## ライセンス

- 文章(`docs/` および本 README の本文)は [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE-DOCS) です。
- コード・スクリプト・サンプル・テンプレート・設定は [MIT License](LICENSE) です。

## 貢献

誤りの指摘や改善提案は [`CONTRIBUTING.md`](CONTRIBUTING.md) を参照してください。

## セキュリティ

[`SECURITY.md`](SECURITY.md) を参照してください。
