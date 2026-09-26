# IBM i プロジェクト・テンプレート

この教材([scratchpad-ibmi-learning-from-zero](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero))を最後まで終えた人が、自分自身の IBM i プロジェクトを新しく始めるときの最小構成です。教材そのものではないので、PUB400 固有の制約(共有機の作法、SSH 接続回数の上限等)は前提にしていません。自分の環境に合わせて自由に書き換えてください。

## 使い方

1. このディレクトリーを丸ごと自分の新しいリポジトリーにコピーします。
2. `docs/naming.md` を自分のプロジェクトの命名規則に合わせて書き換えます(そのまま使ってもかまいません)。
3. `git init` 後、最初のコミットの前に `node scripts/check.mjs` を一度動かして、空のリポジトリーに対して正常終了することを確認してください。
4. ソースを `src/` 以下の該当ディレクトリーに追加していきます。

## ディレクトリー構成

```
.
├── docs/
│   └── naming.md       命名規則(この教材の付録Eを土台にした短縮版)
├── scripts/
│   └── check.mjs       ASCII / LF / 桁数の静的検査(依存パッケージなし)
├── src/
│   ├── qclsrc/         CL プログラムのソース
│   ├── qddssrc/        DDS(物理・論理ファイル、表示装置ファイル、印刷装置ファイル)
│   ├── qrpgsrc/        RPG(固定形式・完全自由形式)
│   ├── qcmdsrc/        独自コマンドの定義ソース
│   └── sql/            SQL スクリプト(IFS に置く前提)
├── .gitattributes      改行を LF に固定
└── README.md           このファイル
```

## この教材から引き継いでいる規約

- **配布ソースの文字・書式**: ASCII のみ、コメントは英語、改行は LF、1行80桁以内(固定形式ソース)。詳しくは[この教材のスタイル・ガイド](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/blob/main/docs/style-guide.md)を参照してください。`scripts/check.mjs` がこれを機械的に検査します。
- **オブジェクトの命名**: `docs/naming.md`(この教材の[付録E](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/blob/main/docs/appendix/e-naming.md)を土台にした短縮版)。

## この教材から引き継いでいないもの

- PUB400 固有の制約(共有ライブラリー3つの役割分担、SSH 接続回数の上限、パスワード認証の作法等)はここには含めません。自分の環境の権限・規約に合わせて設計してください。
- `verify/` のような実機接続の検証ハーネスは含めません。自分のプロジェクトの CI・検証方法に合わせて別途用意してください。
