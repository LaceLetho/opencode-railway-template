const assert = require("assert").strict;
const http = require("http");

const { waitForOpencode } = require("../startup-probe");

const listen = (server) => new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const close = (server) => new Promise((resolve) => server.close(resolve));

const run = async () => {
  const healthy = http.createServer((req, res) => {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ healthy: true }));
  });
  await listen(healthy);
  const ok = await waitForOpencode({ port: healthy.address().port, timeoutMs: 5000, probeTimeoutMs: 500 });
  assert.equal(ok.ready, true);
  assert.equal(ok.attempts, 1);
  await close(healthy);

  // OpenCode accepts the first connection while it is still wiring up its HTTP
  // layer and never answers it. Those requests must not stall the whole probe.
  let seen = 0;
  const stalled = http.createServer((req, res) => {
    seen += 1;
    if (seen > 1) {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ healthy: true }));
    }
  });
  await listen(stalled);
  const started = Date.now();
  const recovered = await waitForOpencode({ port: stalled.address().port, timeoutMs: 10000, probeTimeoutMs: 500 });
  assert.equal(recovered.ready, true);
  assert.ok(recovered.attempts >= 2, `expected retries, got ${recovered.attempts}`);
  assert.ok(Date.now() - started < 5000, "probe should recover instead of blocking on the stalled request");
  await close(stalled);
  stalled.closeAllConnections();

  const dead = http.createServer();
  await listen(dead);
  const port = dead.address().port;
  await close(dead);
  const failed = await waitForOpencode({ port, timeoutMs: 1000, probeTimeoutMs: 300 });
  assert.equal(failed.ready, false);
  assert.match(failed.reason, /ECONNREFUSED|connect/i);

  console.log("startup probe ok");
};

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
