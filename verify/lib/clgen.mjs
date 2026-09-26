// マニフェストの steps から、バッチ用の CL ラッパー・ソースを1本生成する。
// 実機で確認済みの型を踏襲する(tools/qclsrc/txsetup.clp):
//   - プログラム・レベルの MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE)) を先頭に置く
//     (未処理の *ESCAPE が CPF9999 に格上げされ、非対話ジョブが照会メッセージで無期限停止する
//     事故を防ぐため。TXSETUP のハングの真因がこれだった)。
//   - 先頭で CHGJOB INQMSGRPY(*DFT)(RPG1216/RPG0102 のような照会メッセージも自動応答させる)。
//   - 各ステップは個別の MONMSG で囲み、失敗しても次のステップへ進む(1接続で複数の候補を
//     まとめて確かめるため)。
//
// 結果の回収は、qsh の system() 呼び出しが同一ジョブ内で連続するかどうか(未検証)に
// 依存しない設計にしてある: DONE/FAILSAFE の両方の経路で、このラッパー自身のジョブ
// ログを、ライブラリー内の永続表(QTEMP ではない。QTEMPは同一ジョブでなければ消える)
// へ INSERT してから終わる。collect ステップは、接続が終わったあとにこの表を SELECT
// するだけでよい。

const PGM_NAME_MAX = 10;
const CL_MAX_COL = 80;
const CL_INDENT = 13; // 既存の tools/qclsrc/*.clp に合わせた、命令コード開始桁の見た目

function sanitizePgmName(batch) {
  const upper = batch.toUpperCase().replace(/[^A-Z0-9]/g, '');
  const name = upper.startsWith('T') ? upper : `T${upper}`; // TX* 系と紛れないように T 始まりに揃える
  return name.slice(0, PGM_NAME_MAX) || 'TVFYBAT';
}

export function pgmNameForBatch(batch) {
  return sanitizePgmName(batch);
}

// 1つの論理的な CL ステートメントを、80桁以内の物理行に分割する。空白の位置でだけ
// 折り返す(識別子や引用符付き文字列の途中では折り返さない)。継続には `-` を使う
// (IBM i CL の規則: `+` は行間に何も挿入しない連結、`-` は行間に空白を1つ挿入する
// 連結。ここでは元の文字列の空白の位置で切っているので、`-` を使えば元どおりの
// 空白が復元される。SQL('SELECT A, B FROM ...') のように引用符の中に空白を含む
// 文字列パラメーターを折り返すときに、`+` だと単語同士がくっついて壊れるため)。
function wrapClStatement(text, { indent = CL_INDENT, maxCol = CL_MAX_COL } = {}) {
  const contWidth = maxCol - indent - 2; // 行末の ' -' の分を引く
  const words = text.split(' ');
  const rows = [];
  let cur = '';
  for (const w of words) {
    if (w.length > contWidth) {
      throw new Error(`CL の1トークンが長すぎて${maxCol}桁に収まりません: "${w}"`);
    }
    const candidate = cur ? `${cur} ${w}` : w;
    if (candidate.length > contWidth && cur) {
      rows.push(cur);
      cur = w;
    } else {
      cur = candidate;
    }
  }
  if (cur) rows.push(cur);

  return rows.map((row, i) => {
    const isLast = i === rows.length - 1;
    const line = `${' '.repeat(indent)}${row}${isLast ? '' : ' -'}`;
    if (line.length > maxCol) {
      throw new Error(`CL の折り返し後も${maxCol}桁を超えています(${line.length}桁): ${line}`);
    }
    return line;
  });
}

function sqlLit(sql) {
  // CL文字リテラルの中に SQL 文字列を埋め込む。CL リテラル中の ' は '' に
  // エスケープする(標準の CL 文字列リテラルの規則)。
  return `SQL('${sql.replaceAll("'", "''")}')`;
}

// steps のうち type: 'cl' のものだけを対象に、CLラッパー本体を組み立てる。
export function buildClWrapperSource(manifest, cfg) {
  const pgmName = sanitizePgmName(manifest.batch);
  const clSteps = manifest.steps.filter((s) => s.type === 'cl');
  const lib = manifest.library || `${cfg.user.toUpperCase()}2`; // 既定は開発役 <USER>2
  const logTable = `${lib}/VFYLOG`;

  const lines = [];
  const emit = (stmt) => {
    for (const l of wrapClStatement(stmt)) lines.push(l);
  };

  lines.push(`             PGM`);
  emit(`MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))`);
  emit(`CHGJOB INQMSGRPY(*DFT)`);
  emit(`ADDLIBLE LIB(${lib})`);
  lines.push(`             MONMSG     MSGID(CPF2103)`); // 既にライブラリー・リストにあれば無視
  // 前回のバッチの行が残っていると collect で混ざるため、毎回クリアする。
  // 表そのものは qsh 側(system の外)で、接続のたびに CREATE TABLE 済み(なければ作る)。
  emit(`RUNSQL ${sqlLit(`DELETE FROM ${logTable}`)} COMMIT(*NONE)`);
  lines.push(`             MONMSG     MSGID(CPF0000)`); // 表が空でも削除0件でもエラーにしない

  // &LIB はCLの実行時変数ではなく、生成時点でこの文字列にそのまま置き換える
  // プレースホルダー(PARM経由で渡す32バイト・パディングの罠を避けるため)。
  const substLib = (text) => text.replaceAll('&LIB', lib);

  clSteps.forEach((step, i) => {
    const label = (step.label || `S${i}`).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10);
    const nextLabel = i + 1 < clSteps.length ? (clSteps[i + 1].label || `S${i + 1}`).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) : 'DONE';
    lines.push(`${label}:`);
    for (const cmdLine of substLib(step.cmd).split('\n')) {
      emit(cmdLine.trim());
    }
    const monmsgIds = step.monmsg || ['CPF0000'];
    lines.push(`             MONMSG     MSGID(${monmsgIds.join(' ')}) EXEC(DO)`);
    emit(`SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${label} FAILED') TOPGMQ(*SAME) MSGTYPE(*INFO)`);
    emit(`GOTO CMDLBL(${nextLabel})`);
    lines.push(`             ENDDO`);
  });

  // このラッパー自身のジョブ・ログを、終了する直前に永続表へ書き出す。
  // DONE(正常終了)・FAILSAFE(プログラム・レベルのMONMSGで捕まえた異常終了)の
  // どちらの経路でも実行する(collect 側は接続が終わったあとの別のSQL呼び出しに
  // なるため、同一ジョブでなければ意味を持つのはこの中でのINSERTだけ)。
  //
  // 順序が重要: 終端マーカー(DONE/FAILSAFE)を告げる SNDPGMMSG を、ジョブ・ログを
  // 読み取る RUNSQL より必ず先に実行すること。逆順だと、INSERT の時点ではまだ
  // その SNDPGMMSG 自身のメッセージがジョブ・ログに乗っていないため、VFYLOG に
  // マーカーが一生載らず、「FAILSAFE で残りのステップが飛ばされた」のか「全ステップが
  // 実際に成功した」のかを VFYLOG だけから区別できなくなる(2026-09-26 advisor 指摘)。
  const insertLog = `INSERT INTO ${logTable} SELECT ORDINAL_POSITION, SUBSTR(MESSAGE_TEXT,1,200) FROM TABLE(QSYS2.JOBLOG_INFO('*')) X`;

  lines.push(`DONE:`);
  emit(`SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${manifest.batch} DONE') TOPGMQ(*SAME) MSGTYPE(*INFO)`);
  emit(`RUNSQL ${sqlLit(insertLog)} COMMIT(*NONE)`);
  lines.push(`             MONMSG     MSGID(CPF0000)`);
  lines.push(`             RETURN`);
  lines.push(`FAILSAFE:`);
  emit(`SNDPGMMSG MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${manifest.batch} FAILSAFE') TOPGMQ(*SAME) MSGTYPE(*INFO)`);
  emit(`RUNSQL ${sqlLit(insertLog)} COMMIT(*NONE)`);
  lines.push(`             MONMSG     MSGID(CPF0000)`);
  lines.push(`             ENDPGM`);

  return { pgmName, lib, logTable, source: lines.join('\n') };
}
