import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';

const repoRoot = process.cwd();
const excludedRoot = path.join(repoRoot, '.ios-bundle-excluded');

const excludes = [
  { rel: path.join('src', 'app', 'coop'), name: 'coop' },
  // Bundle only the main IsoCity app route for iOS; exclude optional routes.
  { rel: path.join('src', 'app', 'coaster'), name: 'coaster' },
  { rel: path.join('src', 'app', 'thumbnail'), name: 'thumbnail' },
];

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function moveOut() {
  await fs.rm(excludedRoot, { recursive: true, force: true });
  await fs.mkdir(excludedRoot, { recursive: true });

  const moved = [];
  for (const item of excludes) {
    const src = path.join(repoRoot, item.rel);
    const dst = path.join(excludedRoot, item.name);
    if (await pathExists(src)) {
      await fs.rename(src, dst);
      moved.push({ src, dst });
    }
  }
  return moved;
}

async function restore(moved) {
  for (const item of moved.slice().reverse()) {
    if (await pathExists(item.dst)) {
      await fs.rename(item.dst, item.src);
    }
  }
  await fs.rm(excludedRoot, { recursive: true, force: true });
}

function runNextBuild() {
  return new Promise((resolve, reject) => {
    const child = spawn('npx', ['next', 'build', '--webpack'], {
      cwd: repoRoot,
      stdio: 'inherit',
      env: {
        ...process.env,
        ISOCITY_IOS_BUNDLE: '1',
      },
    });

    child.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`next build failed with exit code ${code}`));
    });
  });
}

let moved = [];
try {
  moved = await moveOut();
  await runNextBuild();
} finally {
  await restore(moved);
}
