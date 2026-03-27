const fs = require("fs");
const path = require("path");
const { isSourceMode } = require("./source-mode");

function canExec(file) {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function resolvePath(name, env) {
  const paths = (env.PATH ?? process.env.PATH ?? "").split(path.delimiter).filter(Boolean);
  return paths
    .map((dir) => path.join(dir, name))
    .find(canExec);
}

function resolveCompiledLaunch(opts) {
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
  const sourceDir = env.OPENCODE_SOURCE_DIR || "/opt/opencode";
  const compiledDir = path.join(sourceDir, "packages", "opencode", "dist");
  const compiled = fs.existsSync(compiledDir)
    ? fs
        .readdirSync(compiledDir)
        .map((item) => path.join(compiledDir, item, "bin", "opencode"))
        .find(canExec)
    : undefined;
  if (!compiled) {
    return {
      error: `No compiled OpenCode launcher found in ${compiledDir}. SOURCE_MODE=true requires a prebuilt standalone binary.`,
    };
  }

  return {
    cmd: compiled,
    args,
    mode: "compiled",
  };
}

function resolvePublishedLaunch(opts) {
  const env = opts.env || process.env;
  const cmd = resolvePath("opencode", env);
  if (!cmd) {
    return {
      error: "No opencode executable found in PATH. SOURCE_MODE=false requires the published opencode-ai package to be installed.",
    };
  }

  return {
    cmd,
    args: [
      "--print-logs",
      "--log-level",
      opts.logLevel,
      "serve",
      "--port",
      opts.internalPort,
      "--hostname",
      "127.0.0.1",
    ],
    mode: "published",
  };
}

function resolveOpencodeLaunch(opts) {
  return isSourceMode(opts.env) ? resolveCompiledLaunch(opts) : resolvePublishedLaunch(opts);
}

module.exports = {
  resolveOpencodeLaunch,
};
