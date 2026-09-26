// SSH接続の台帳(回数・時刻・結果)を読み書きし、接続してよいかどうかを機械的に判定する。
// 台帳の実体は work/verify/ledger.json(.gitignore 済み、実名を書いてもコミットされない場所)。
// このファイル自体はコミットされるため、実名・実パスは絶対に書かない。

import fs from 'node:fs';
import path from 'node:path';
import { repoRoot } from './paths.mjs';

const LEDGER_PATH = path.join(repoRoot(), 'work', 'verify', 'ledger.json');
const LOCK_PATH = `${LEDGER_PATH}.lock`;
const LOCK_STALE_MS = 60_000; // ロック取得者がクラッシュした場合に無期限で詰まらないための猶予

const INTERVAL_MS = 15 * 60 * 1000; // 接続の間隔は15分以上
const REFUSED_HALT_MS = 3 * 60 * 60 * 1000; // 拒否/タイムアウトで3時間停止

// 2026-09-26、台帳174件(実測)の分析に基づき8→24へ緩和(P0-1)。
// 2026-09-26夜、台帳198件(その後の実測)を再分析した結果、24時間の累計上限
// そのものを撤廃(ユーザー承認済み)。根拠:
//   - 拒否/タイムアウトが起きた6件は、いずれも「直前30分に9〜21回・直前10分に
//     4〜13回」という短時間の集中の直後に起きている。
//   - 24時間の累計回数が148回・174回に達した時点でも、拒否は一度も起きて
//     いない(174回/24時間は無事故)。つまり24時間の累計回数そのものは、
//     PUB400側が実際に見ている制限ではないと判断できる。
//   - 15分間隔を厳守すれば、どの1時間を切り取っても最大4回にしかならず、
//     観測された最小の集中閾値(30分に9回=1時間に18回相当)の4分の1以下に
//     常に収まる。つまり15分間隔の遵守自体が、実質的な「時間あたりの上限」
//     として十分に機能している。
// この根拠に基づき、24時間の累計上限は完全に撤廃し、15分間隔(=事実上の
// 時間あたり上限)・拒否後3時間停止・認証失敗時の全停止の3つだけで歯止めを
// かける。この3つは集中や認証失敗そのものへの直接の歯止めであり、今回の
// 根拠では緩める理由がないため変更しない。

function emptyLedger() {
  return {
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    authFailedEver: false,
    connections: [],
  };
}

function acquireLock() {
  const deadline = Date.now() + 10_000;
  for (;;) {
    try {
      const fd = fs.openSync(LOCK_PATH, 'wx');
      fs.writeSync(fd, String(process.pid));
      fs.closeSync(fd);
      return;
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      // 古いロックファイルは、前回の実行がクラッシュした痕跡とみなして奪い取る。
      try {
        const stat = fs.statSync(LOCK_PATH);
        if (Date.now() - stat.mtimeMs > LOCK_STALE_MS) {
          fs.unlinkSync(LOCK_PATH);
          continue;
        }
      } catch {
        continue; // 他プロセスが解放した直後などで stat が失敗した場合は取り直す
      }
      if (Date.now() > deadline) {
        throw new Error(`台帳のロック(${LOCK_PATH})を取得できません。他に実行中の verify/run.mjs がないか確認してください。`);
      }
    }
  }
}

function releaseLock() {
  try {
    fs.unlinkSync(LOCK_PATH);
  } catch {
    // 既に無ければ何もしない
  }
}

export function loadLedger() {
  fs.mkdirSync(path.dirname(LEDGER_PATH), { recursive: true });
  if (!fs.existsSync(LEDGER_PATH)) return emptyLedger();
  const raw = fs.readFileSync(LEDGER_PATH, 'utf8');
  if (!raw.trim()) return emptyLedger();
  return JSON.parse(raw);
}

function saveLedger(ledger) {
  ledger.updatedAt = new Date().toISOString();
  fs.mkdirSync(path.dirname(LEDGER_PATH), { recursive: true });
  fs.writeFileSync(LEDGER_PATH, `${JSON.stringify(ledger, null, 2)}\n`, 'utf8');
}

// lockを取ってledgerを読み、fnの戻り値(更新後のledger、またはundefinedで変更なし)を書き戻す。
export function withLedgerLock(fn) {
  acquireLock();
  try {
    const ledger = loadLedger();
    const result = fn(ledger);
    if (result !== undefined) saveLedger(result);
    return result === undefined ? ledger : result;
  } finally {
    releaseLock();
  }
}

// 接続してよいか(接続の間隔・拒否後の停止・認証失敗後の全停止)を判定する。
// 3つの歯止めはすべて独立に評価し、最も遅い nextAllowedAt を採用する(いずれか1つでも
// 満たされていなければ接続不可、という意図)。24時間の回数上限は2026-09-26に撤廃した
// (台帳198件の実測に基づく、下記参照)。
export function computeGate(ledger, now = new Date()) {
  if (ledger.authFailedEver) {
    return {
      allowed: false,
      nextAllowedAt: null,
      reasons: [
        '認証に1回でも失敗した記録があるため、この状態のままでは SSH を完全に停止しています。' +
          '台帳(work/verify/ledger.json)の authFailedEver を確認し、ユーザーに報告してから対応してください。',
      ],
    };
  }

  const nowMs = now.getTime();
  const reasons = [];
  let gateAt = 0; // 接続してよい最も早い時刻(epoch ms)。0 なら制約なし。

  const recentBadTimes = ledger.connections
    .filter((c) => c.status === 'refused_or_timeout' || c.status === 'blocked')
    .map((c) => new Date(c.endedAt || c.startedAt).getTime())
    .filter((t) => !Number.isNaN(t));
  if (recentBadTimes.length) {
    const lastBad = Math.max(...recentBadTimes);
    const until = lastBad + REFUSED_HALT_MS;
    if (until > gateAt) gateAt = until;
    // 理由は「今もまだ効いている歯止め」だけを表示する(until が既に過去なら、
    // gateAt の計算には反映済みでも reasons には出さない - でないと解除済みの
    // 古い歯止めが --status に紛れ込み、紛らわしい)。
    if (until > nowMs) {
      reasons.push(`直近の拒否/タイムアウト(${new Date(lastBad).toISOString()})から3時間は停止`);
    }
  }

  const allStartTimes = ledger.connections
    .map((c) => new Date(c.startedAt).getTime())
    .filter((t) => !Number.isNaN(t));
  if (allStartTimes.length) {
    const lastStart = Math.max(...allStartTimes);
    const until = lastStart + INTERVAL_MS;
    if (until > gateAt) gateAt = until;
    if (until > nowMs) {
      reasons.push(`前回接続(${new Date(lastStart).toISOString()})から15分の間隔が必要`);
    }
  }

  const allowed = gateAt <= nowMs;
  return {
    allowed,
    nextAllowedAt: allowed ? now : new Date(gateAt),
    reasons,
  };
}

// 接続開始を台帳に記録する(接続の「前」に呼ぶ。クラッシュしても1回とカウントされるように)。
// 戻り値は connections 配列内のインデックス。recordEnd に渡す。
export function recordStart(batch, note = '') {
  return withLedgerLock((ledger) => {
    ledger.connections.push({
      startedAt: new Date().toISOString(),
      endedAt: null,
      status: 'started',
      batch,
      note,
    });
    return ledger;
  }).connections.length - 1;
}

export function recordEnd(index, status, note = '') {
  withLedgerLock((ledger) => {
    const entry = ledger.connections[index];
    if (!entry) throw new Error(`台帳に接続記録 index=${index} が見つかりません。`);
    entry.endedAt = new Date().toISOString();
    entry.status = status;
    if (note) entry.note = note;
    if (status === 'auth_failed') ledger.authFailedEver = true;
    return ledger;
  });
}

export { LEDGER_PATH };
