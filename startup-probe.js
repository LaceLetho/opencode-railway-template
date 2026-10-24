const PROBE_TIMEOUT_MS = 2000;
const PROBE_INTERVAL_MS = 200;

const quiet = () => {};

// A single request can be accepted by OpenCode while it is still wiring up its
// HTTP layer and then never answered. Without a per-attempt deadline the loop
// blocks on that one socket until the runtime's own request timeout (~5 min).
const probe = async (port, timeoutMs) => {
  const signal = AbortSignal.timeout(timeoutMs);
  const request = fetch(`http://127.0.0.1:${port}/global/health`, { signal })
    .then((res) => (res.ok ? undefined : `status=${res.status}`))
    .catch((err) => {
      if (err?.name === "TimeoutError") return `no response within ${timeoutMs}ms`;
      const cause = err?.cause?.code || err?.cause?.message;
      return [err?.message || String(err), cause].filter(Boolean).join(": ");
    });
  const guard = new Promise((resolve) => setTimeout(() => resolve(`no response within ${timeoutMs}ms`), timeoutMs + 1000).unref?.());
  return await Promise.race([request, guard]);
};

const waitForOpencode = async (opts) => {
  const port = opts.port;
  const timeoutMs = opts.timeoutMs ?? 120000;
  const probeTimeoutMs = opts.probeTimeoutMs ?? PROBE_TIMEOUT_MS;
  const log = opts.log ?? quiet;
  const start = Date.now();
  let attempts = 0;
  let reason = "no probe attempts";

  while (Date.now() - start < timeoutMs) {
    attempts += 1;
    reason = await probe(port, probeTimeoutMs);
    if (!reason) return { ready: true, attempts, elapsedMs: Date.now() - start, reason };
    if (attempts === 1 || attempts % 10 === 0) log(`[wrapper] Health probe ${attempts} failed: ${reason}`);
    await new Promise((resolve) => setTimeout(resolve, PROBE_INTERVAL_MS));
  }

  return { ready: false, attempts, elapsedMs: Date.now() - start, reason };
};

module.exports = {
  waitForOpencode,
};
