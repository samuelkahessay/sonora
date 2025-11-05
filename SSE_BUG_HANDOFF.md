# SSE Streaming Bug Handoff - iOS 500 Error

**Status**: UNRESOLVED - Fix attempted but issue persists
**Date**: 2025-11-05
**Priority**: HIGH - Blocking Pro feature on iOS

## Problem Summary

iOS client shows **"stream parsing failed: Server error (500)"** when receiving SSE (Server-Sent Events) streaming responses from the `/analyze` endpoint for Pro distill mode. The error occurs even though:

- ✅ Server logs show all SSE events being sent successfully
- ✅ Curl requests receive all events correctly with exit code 0
- ✅ Server-side streaming completes without errors

## What's Broken

**Endpoint**: `POST https://sonora.fly.dev/analyze`
**Conditions**: `mode=distill`, `isPro=true`, SSE streaming enabled
**Error**: iOS shows "Server error (500)" after stream completes
**Expected**: Progressive SSE updates without errors

## Fix Attempted (Did Not Resolve Issue)

**File**: `server/src/server.ts`
**Line**: 590
**Change**: Added explicit `res.status(200);` before SSE headers

```typescript
// BEFORE:
res.setHeader('Content-Type', 'text/event-stream');

// AFTER:
res.status(200);
res.setHeader('Content-Type', 'text/event-stream');
```

**Rationale**: Match the working `/title` SSE endpoint pattern (line 188)
**Result**: Fix deployed but iOS still shows 500 error

## Evidence Collected

### 1. Server Logs (Working)
```
📡 Starting SSE streaming for Pro distill
📡 [SSE] Sent base distill interim event (1/4)
📡 [SSE] Sent thinking patterns interim event (2/4)
📡 [SSE] Sent philosophical echoes interim event (3/4)
📡 [SSE] Sent values insights interim event (4/4)
📡 [SSE] Sent final event, closing stream
```

### 2. Curl Test (Working)
All three test curls completed successfully (exit code 0):
- Non-Pro: Plain JSON response ✅
- Pro with SSE: All interim + final events received ✅
- Pro with keepalive: Keepalive comments + all events ✅

### 3. iOS Client Error (Failing)
- Initial status check passes (200) at `AnalysisService.swift:234-237`
- Stream parsing begins successfully
- Error occurs during or after stream completion
- Error message: "stream parsing failed: Server error (500)"

## Key Files

### Server Side
- **`server/src/server.ts`**
  - Line 585-815: SSE streaming implementation for Pro distill
  - Line 188: Working `/title` SSE endpoint (reference pattern)
  - Line 590: Current status code setting (after attempted fix)

### Client Side (iOS)
- **`Sonora/Data/Services/Analysis/AnalysisService.swift`**
  - Line 234-237: Initial HTTP status check
  - Line 261-339: SSE event parsing loop
  - Line 336-338: Error handling that catches and reports 500 error

## What We Know

1. **Server is working correctly**: Curl confirms all events are sent properly
2. **Initial handshake succeeds**: iOS passes the 200 status check
3. **Parsing begins successfully**: Stream starts processing
4. **Error occurs at stream end**: Likely during or after final event
5. **Status code fix didn't help**: Explicit 200 status still shows error

## Possible Root Causes (Unexplored)

### 1. Response Headers Issue
- Missing or incorrect headers specific to iOS URLSession requirements
- Check header order (status, then Content-Type, then others)
- Verify all required SSE headers are present

### 2. Event Format Problem
- iOS may be stricter about SSE event format than curl
- Check event/data line formatting
- Verify newline characters (`\n\n` after each event)
- Ensure no trailing whitespace or malformed JSON in `data:` fields

### 3. Stream Termination Issue
- How `res.end()` is called (line 815)
- Missing final `\n\n` after last event
- Connection closed before client finishes reading

### 4. Error in iOS Parsing Logic
- Bug in `AnalysisService.swift` SSE parser (lines 261-339)
- Incorrect handling of stream completion
- Error thrown by `URLSession.AsyncBytes` on normal termination

### 5. Network Layer Issue
- Fly.io proxy/nginx modifying responses for iOS user-agents
- Content-Encoding or Transfer-Encoding conflicts
- Connection timeout despite keepalive

## Debugging Steps for Next Agent

### Step 1: Compare Raw HTTP Responses
```bash
# Get raw HTTP response from curl
curl -i -N -H "Accept: text/event-stream" -H "Content-Type: application/json" \
  -X POST https://sonora.fly.dev/analyze \
  -d '{"mode":"distill","transcript":"Test","isPro":true}' > server_response.txt

# Compare with working /title endpoint
curl -i -N -H "Accept: text/event-stream" -X GET \
  "https://sonora.fly.dev/title?transcript=Test" > title_response.txt
```

### Step 2: Add Detailed iOS Logging
In `AnalysisService.swift`, add logging:
- Log HTTP headers received
- Log each SSE event as parsed
- Log exact error when stream fails
- Log URLResponse status at error time

### Step 3: Test with Simpler SSE Response
Modify server to send minimal SSE:
```typescript
res.status(200);
res.setHeader('Content-Type', 'text/event-stream');
res.write('data: {"test":"minimal"}\n\n');
res.end();
```

### Step 4: Verify SSE Format Compliance
Check server output against SSE spec:
- Each event must end with `\n\n`
- `event:` lines must be followed by `data:` lines
- No extra whitespace
- Proper JSON escaping in data fields

### Step 5: Test Network Middleware
- Check Fly.io proxy logs
- Test directly against local server (bypass Fly.io)
- Compare iOS simulator vs physical device

## Code References

**Server SSE Implementation**: `server/src/server.ts:585-815`
**iOS SSE Parser**: `Sonora/Data/Services/Analysis/AnalysisService.swift:261-339`
**Working SSE Endpoint**: `server/src/server.ts:188` (title generation)

## Test Commands

```bash
# Test Pro SSE streaming
curl -s -N -H "Accept: text/event-stream" -H "Content-Type: application/json" \
  -X POST https://sonora.fly.dev/analyze \
  -d '{"mode":"distill","transcript":"Test transcript","isPro":true}'

# Check server logs
fly logs --app sonora

# Test on iOS simulator (after building)
# Open Sonora app → Create memo → Record → Analyze (Pro)
```

## Questions to Answer

1. **What exact HTTP response does iOS URLSession receive?** (Use network debugger)
2. **Does the error occur on ALL iOS requests or intermittently?**
3. **Is the 500 status in the actual HTTP response or generated by client?**
4. **Does a minimal SSE response (one event) work on iOS?**
5. **Does the working `/title` SSE endpoint work on iOS?**

## Previous Investigation

An agent used the Task tool with `subagent_type=Plan` and found:
- Server doesn't set explicit status before headers (FIX APPLIED - didn't work)
- Client checks status correctly on initial response
- Parsing error occurs during stream reading loop

## Next Steps (Recommended Priority)

1. **HIGHEST**: Capture actual HTTP response iOS receives (use Proxyman/Charles)
2. **HIGH**: Test if `/title` SSE endpoint works on iOS (proves client works)
3. **HIGH**: Add verbose logging to iOS SSE parser to see exact failure point
4. **MEDIUM**: Compare event format between working curl and what iOS expects
5. **MEDIUM**: Test minimal SSE response to isolate format vs content issue
6. **LOW**: Check Fly.io proxy behavior for iOS user-agents

## Contact Points

- Server deployed at: https://sonora.fly.dev/
- Main branch has attempted fix: `res.status(200)` at line 590
- iOS app repo: Same repository, `Sonora/` directory

---

**Good luck!** This is a challenging SSE/iOS networking issue. The discrepancy between curl working and iOS failing suggests a protocol-level subtlety rather than a logic bug.
