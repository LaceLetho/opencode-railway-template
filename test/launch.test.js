const assert = require("assert").strict;
const fs = require("fs");
const os = require("os");
const path = require("path");

const { resolveOpencodeLaunch } = require("../launch");

const run = () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "opencode-launch-"));
  const dist = path.join(dir, "packages", "opencode", "dist", "linux-x64");
  const bin = path.join(dist, "bin");
  fs.mkdirSync(bin, { recursive: true });
  const compiledFile = path.join(bin, "opencode");
  fs.writeFileSync(compiledFile, "#!/bin/sh\nexit 0\n");
  fs.chmodSync(compiledFile, 0o755);

  const compiled = resolveOpencodeLaunch({
    env: {
      SOURCE_MODE: "true",
      OPENCODE_SOURCE_DIR: dir,
    },
    internalPort: "18080",
    logLevel: "INFO",
  });
  assert.equal(compiled.mode, "compiled");
  assert.equal(compiled.cmd, compiledFile);

  const missing = resolveOpencodeLaunch({
    env: {
      SOURCE_MODE: "true",
      OPENCODE_SOURCE_DIR: "/definitely-missing",
    },
    internalPort: "18080",
    logLevel: "INFO",
  });
  assert.match(missing.error, /No compiled OpenCode launcher found/);

  const publishedBin = path.join(dir, "published-bin");
  fs.mkdirSync(publishedBin, { recursive: true });
  const publishedFile = path.join(publishedBin, "opencode");
  fs.writeFileSync(publishedFile, "#!/bin/sh\nexit 0\n");
  fs.chmodSync(publishedFile, 0o755);

  const published = resolveOpencodeLaunch({
    env: {
      SOURCE_MODE: "false",
      PATH: publishedBin,
    },
    internalPort: "18080",
    logLevel: "INFO",
  });
  assert.equal(published.mode, "published");
  assert.equal(published.cmd, publishedFile);

  const missingPublished = resolveOpencodeLaunch({
    env: {
      SOURCE_MODE: "false",
      PATH: "",
    },
    internalPort: "18080",
    logLevel: "INFO",
  });
  assert.match(missingPublished.error, /No opencode executable found in PATH/);

  fs.rmSync(dir, { recursive: true, force: true });
  console.log("launch resolution ok");
};

run();
