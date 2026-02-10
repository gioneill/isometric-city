import fs from 'node:fs/promises';
import path from 'node:path';

const repoRoot = process.cwd();
const outDir = path.join(repoRoot, 'out');
// Use a wrapper directory so Xcode copies it as a single resource and preserves hierarchy.
// A plain folder of resources gets flattened into the app bundle root, which causes filename collisions
// (e.g. multiple `index.html`, `industrial.png`, etc.).
const destDir = path.join(repoRoot, 'ios', 'iso-city-ios', 'iso-city-ios', 'web.bundle');

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function main() {
  if (!(await pathExists(outDir))) {
    throw new Error('Missing `out/`. Run `npm run ios:web:export` first.');
  }

  // Clean up the old layout if it exists (it breaks Xcode builds due to flattened resources).
  await fs.rm(path.join(repoRoot, 'ios', 'iso-city-ios', 'iso-city-ios', 'web'), {
    recursive: true,
    force: true,
  });

  await fs.rm(destDir, { recursive: true, force: true });
  await fs.mkdir(destDir, { recursive: true });

  const entries = await fs.readdir(outDir);
  if (entries.length === 0) {
    throw new Error('`out/` is empty. Static export failed or produced no files.');
  }

  await Promise.all(
    entries.map(async (entry) => {
      await fs.cp(path.join(outDir, entry), path.join(destDir, entry), {
        recursive: true,
        force: true,
      });
    })
  );

  // Sanity check for the host app.
  const indexHtml = path.join(destDir, 'index.html');
  if (!(await pathExists(indexHtml))) {
    throw new Error('Bundled output missing `index.html`.');
  }
}

main().catch((err) => {
  console.error(err?.message ?? err);
  process.exit(1);
});
