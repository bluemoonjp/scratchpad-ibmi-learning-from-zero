// マニフェストの steps から、バッチ用の CL ラッパー・ソースを1本生成する。
// 実機で確認済みの型を踏襲する(tools/qclsrc/txsetup.clp):
//   - プログラム・レベルの MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE)) を先頭に置く
//     (未処理の *ESCAPE が CPF9999 に格上げされ、非対話ジョブが照会メッセージで無期限停止する
//     事故を防ぐため。TXSETUP のハングの真因がこれだった)。
//   - 先頭で CHGJOB INQMSGRPY(*DFT)(RPG1216/RPG0102 のような照会メッセージも自動応答させる)。
//   - 各ステップは個別の MONMSG で囲み、失敗しても次のステップへ進む(1接続で複数の候補を
//     まとめて確かめるため)。

const PGM_NAME_MAX = 10;

function sanitizePgmName(batch) {
  const upper = batch.toUpperCase().replace(/[^A-Z0-9]/g, '');
  const name = upper.startsWith('T') ? upper : `T${upper}`; // TX* 系と紛れないように T 始まりに揃える
  return name.slice(0, PGM_NAME_MAX) || 'TVFYBAT';
}

export function pgmNameForBatch(batch) {
  return sanitizePgmName(batch);
}

// steps のうち type: 'cl' のものだけを対象に、CLラッパー本体を組み立てる。
export function buildClWrapperSource(manifest, cfg) {
  const pgmName = sanitizePgmName(manifest.batch);
  const clSteps = manifest.steps.filter((s) => s.type === 'cl');
  const lib = manifest.library || `${cfg.user.toUpperCase()}2`; // 既定は開発役 <USER>2

  const lines = [];
  lines.push(`             PGM`);
  lines.push(
    `             MONMSG     MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILSAFE))`,
  );
  lines.push(`             CHGJOB     INQMSGRPY(*DFT)`);
  lines.push(`             ADDLIBLE   LIB(${lib})`);
  lines.push(`             MONMSG     MSGID(CPF2103)`); // 既にライブラリー・リストにあれば無視

  // &LIB はCLの実行時変数ではなく、生成時点でこの文字列にそのまま置き換える
  // プレースホルダー(PARM経由で渡す32バイト・パディングの罠を避けるため)。
  const substLib = (text) => text.replaceAll('&LIB', lib);

  clSteps.forEach((step, i) => {
    const label = (step.label || `S${i}`).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10);
    const nextLabel = i + 1 < clSteps.length ? (clSteps[i + 1].label || `S${i + 1}`).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) : 'DONE';
    lines.push(`${label}:`);
    for (const cmdLine of substLib(step.cmd).split('\n')) {
      lines.push(`             ${cmdLine}`);
    }
    const monmsgIds = step.monmsg || ['CPF0000'];
    lines.push(`             MONMSG     MSGID(${monmsgIds.join(' ')}) EXEC(DO)`);
    lines.push(
      `             SNDPGMMSG  MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${label} FAILED') +`,
    );
    lines.push(`                          TOPGMQ(*SAME) MSGTYPE(*INFO)`);
    lines.push(`             GOTO       CMDLBL(${nextLabel})`);
    lines.push(`             ENDDO`);
  });

  lines.push(`DONE:`);
  lines.push(
    `             SNDPGMMSG  MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${manifest.batch} DONE') +`,
  );
  lines.push(`                          TOPGMQ(*SAME) MSGTYPE(*INFO)`);
  lines.push(`             RETURN`);
  lines.push(`FAILSAFE:`);
  lines.push(
    `             SNDPGMMSG  MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('${manifest.batch} FAILSAFE') +`,
  );
  lines.push(`                          TOPGMQ(*SAME) MSGTYPE(*INFO)`);
  lines.push(`             ENDPGM`);

  return { pgmName, lib, source: lines.join('\n') };
}
