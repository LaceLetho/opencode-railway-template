const fs = require("fs");
const path = require("path");

function canExec(file) {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function findOnPath(name, envPath) {
  if (!envPath) return;
  for (const dir of envPath.split(path.delimiter)) {
    if (!dir) continue;
    const file = path.join(dir, name);
    if (canExec(file)) return file;
  }
}

function resolveOpencodeLaunch(opts) {
  const env = opts.env || process.env;
  const args = [
    "--print-logs",
    "--log-level",
    opts.logLevel,
    "serve",
    "--port",
    opts.internalPort,
    "--hostname",
    "127.0.0.1",
  ];
  const envPath = env.PATH || "";
  const bunInstall = env.BUN_INSTALL || "/root/.bun";
  const binDir = path.join(bunInstall, "bin");
  const sourceDir = env.OPENCODE_SOURCE_DIR || "/opt/opencode";
  const compiledDir = path.join(sourceDir, "packages", "opencode", "dist");
  const compiled = fs.existsSync(compiledDir)
    ? fs
        .readdirSync(compiledDir)
        .map((item) => path.join(compiledDir, item, "bin", "opencode"))
        .find(canExec)
    : undefined;
  if (compiled) {
    return {
      cmd: compiled,
      args,
      mode: "compiled",
    };
  }

  const sourceEntry = path.join(sourceDir, "packages", "opencode", "src", "index.ts");
  const bun = canExec(path.join(binDir, "bun"))
    ? path.join(binDir, "bun")
    : findOnPath("bun", envPath);
  if (bun && fs.existsSync(sourceEntry)) {
    return {
      cmd: bun,
      args: ["run", "--cwd", path.join(sourceDir, "packages", "opencode"), "--conditions=browser", "src/index.ts", ...args],
      mode: "source",
    };
  }

  const opencode = canExec(path.join(binDir, "opencode"))
    ? path.join(binDir, "opencode")
    : findOnPath("opencode", envPath);
  if (opencode) {
    return {
      cmd: opencode,
      args,
      mode: "opencode",
    };
  }

  const bunx = canExec(path.join(binDir, "bunx"))
    ? path.join(binDir, "bunx")
    : findOnPath("bunx", envPath);
  if (bunx) {
    return {
      cmd: bunx,
      args: ["opencode", ...args],
      mode: "bunx",
    };
  }

  if (bun) {
    return {
      cmd: bun,
      args: ["x", "opencode", ...args],
      mode: "bun",
    };
  }

  return {
    error: `No OpenCode launcher found. Checked compiled dist in ${compiledDir}, source entry ${sourceEntry}, ${path.join(binDir, "opencode")}, ${path.join(binDir, "bunx")}, ${path.join(binDir, "bun")} and PATH=${envPath || "<empty>"}`,
  };
}

module.exports = {
  resolveOpencodeLaunch,
};
