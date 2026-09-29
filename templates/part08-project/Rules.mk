# makeiが実際に何をビルドするかを宣言するファイル(必須)。iproj.jsonと
# 同じディレクトリー(または各サブディレクトリー)に置くとmakeiが自動的に
# 読み込む。TOBi自身のドキュメント(PUB400上の
# /QOpenSys/pkgs/lib/tobi/docs/prepare-the-project/rules.mk.md、
# work/design/refs/にはミラーされていない一次資料)によれば、
# 「オブジェクト名.オブジェクト型: ソース・ファイル」という形の行(ルール)
# を1つも書かなければ、makeiは「ビルドするものが無い」と判断する
# (このリポジトリでの実機確認: `docs/probes.md`のpart08-02-makei-probe2、
# コメントのみのRules.mkでは`make: Nothing to be done for 'all'`になった)。
#
# オブジェクト名は大文字、`.MODULE`/`.SRVPGM`のようなIFS拡張子を付けて
# 書く(TOBi自身の規約)。ソース・ファイル名は実際のファイル名をそのまま
# 小文字で書いてよい(`$(d)/`のような接頭辞は現在のTOBiでは不要)。

ZAISRV.MODULE: zaisrv.rpgle
ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd
