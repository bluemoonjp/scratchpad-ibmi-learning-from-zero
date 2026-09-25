import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// verify/lib/ から見てリポジトリー・ルートは2階層上。
export function repoRoot() {
  return path.resolve(__dirname, '..', '..');
}
