# Debugging SSE Endpoint Issues in OpenCode Railway Template

## Problem Summary

After deploying OpenCode to Railway using the template, browser console showed errors related to SSE (Server-Sent Events) connections failing. The `/events` endpoint was returning HTML instead of the expected `text/event-stream` content type.

## Root Cause

The OpenCode backend changed the events endpoint from `/events` to `/global/event` in a recent version, but:
1. The proxy code had `/events` listed in `OPENCODE_API_PREFIXES`
2. The frontend was still requesting `/events`
3. When the proxy forwarded `/events` to the backend, it returned HTML (404 page) instead of SSE stream

## Debugging Process

### Step 1: Verify the Issue
```bash
curl -s -u "username:password" "https://opencode.tradao.xyz/events?sessionID=test" -I
# Response showed: content-type: text/html;charset=UTF-8 (WRONG)
```

### Step 2: Check Proxy Logs
Added debug logging to trace request routing:
```javascript
console.log(`[proxy] ${req.method} ${req.url} -> ... (API:${isApiReq}, SSE:${isSSE})`);
```

Discovered that `/events` WAS being correctly routed as an API endpoint, but the backend returned HTML.

### Step 3: Find the Correct Endpoint
Searched the OpenCode source code and found:
```typescript
// In packages/opencode/src/server/routes/global.ts
.get("/global/event", ...)  // Correct endpoint
```

The correct endpoint is `/global/event` (singular), not `/events` (plural).

### Step 4: Verify the Fix
```bash
curl -s -u "username:password" "https://opencode.tradao.xyz/global/event?directory=/data/workspace" -I
# Response showed: content-type: text/event-stream (CORRECT!)
```

## Solution

Added URL rewriting in the proxy to maintain backwards compatibility:

```javascript
// Rewrite /events to /global/event for backwards compatibility
// OpenCode changed the endpoint from /events to /global/event
let proxyPath = req.url;
if (proxyPath === '/events' || proxyPath.startsWith('/events?')) {
  proxyPath = proxyPath.replace('/events', '/global/event');
  console.log(`[proxy] Rewriting ${req.url} to ${proxyPath}`);
}

const options = {
  hostname: "127.0.0.1",
  port: targetPort,
  path: proxyPath,  // Use rewritten path
  method: req.method,
  headers: forwardHeaders,
};
```

## Key Learnings

### 1. API Endpoint Discovery
When debugging API issues, always check the actual backend routes:
- Look at the source code (`packages/opencode/src/server/routes/`)
- Or check OpenAPI documentation at `/doc`
- Don't rely on assumptions about endpoint names

### 2. Query String Handling
When matching URL paths, always strip query strings first:
```javascript
const pathname = url.split('?')[0].split('#')[0];
```

### 3. Debug Logging Strategy
Add comprehensive logging at multiple levels:
- Request routing decisions (isApiReq, isSSE, targetPort)
- Backend responses (status code, content-type)
- URL rewrites

### 4. Backwards Compatibility
When APIs change, consider adding rewrite rules to maintain compatibility with existing clients instead of breaking them.

### 5. Railway Deployment Debugging
Useful commands for debugging Railway deployments:
```bash
# Get recent deployments
curl -s -X POST https://backboard.railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "query deployments($input: DeploymentListInput!) { deployments(input: $input) { edges { node { id status } } } }", "variables": {"input": {"projectId": "...", "serviceId": "...", "environmentId": "..."}}}'

# Get deployment logs
curl -s -X POST https://backboard.railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { deploymentLogs(deploymentId: \"...\", limit: 100) { message severity timestamp } }"}'
```

## Prevention

To prevent similar issues:
1. Keep the API prefix list synchronized with OpenCode's actual routes
2. Add endpoint discovery/validation tests
3. Document API changes in the template when upgrading OpenCode versions
4. Consider using OpenAPI specs to auto-generate route configurations

## Related Files

- `server.js` - Proxy server with URL rewriting logic
- `packages/opencode/src/server/routes/global.ts` - OpenCode event endpoint definition

## References

- OpenCode version: 1.2.27
- Railway project: opencode-railway-template
- Fix PR: https://github.com/LaceLetho/opencode-railway-template/pull/5
- Date: 2026-03-22
