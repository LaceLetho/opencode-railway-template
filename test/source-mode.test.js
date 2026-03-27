const assert = require("assert").strict;

const { isSourceMode } = require("../source-mode");

const run = () => {
  assert.equal(isSourceMode({}), true);
  assert.equal(isSourceMode({ SOURCE_MODE: "true" }), true);
  assert.equal(isSourceMode({ SOURCE_MODE: "TRUE" }), true);
  assert.equal(isSourceMode({ SOURCE_MODE: "false" }), false);
  assert.equal(isSourceMode({ SOURCE_MODE: "FALSE" }), false);
  assert.equal(isSourceMode({ SOURCE_MODE: "0" }), true);
  console.log("source mode ok");
};

run();
