const assert = require("assert").strict;
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");

const read = (filePath) => fs.readFileSync(path.join(root, filePath), "utf8");

const getCopiedFiles = (text) => {
  const files = new Set();
  for (const line of text.split("\n")) {
    const value = line.trim();
    if (!value.startsWith("COPY ")) continue;
    const parts = value.split(/\s+/);
    if (parts.length < 3) continue;
    for (const item of parts.slice(1, -1)) {
      files.add(item);
    }
  }
  return files;
};

const getLocalModules = (text) =>
  [...text.matchAll(/require\("\.\/([^"]+)"\)/g)].map((m) => `${m[1]}.js`);

const run = () => {
  const dockerfile = read("Dockerfile");
  const server = read("server.js");
  const copied = getCopiedFiles(dockerfile);

  for (const file of getLocalModules(server)) {
    assert.equal(
      copied.has(file),
      true,
      `Dockerfile is missing ${file} in COPY list`,
    );
  }

  console.log("dockerfile copy ok");
};

run();
