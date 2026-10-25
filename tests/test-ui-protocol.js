const assert = require("assert");
const fs = require("fs");
const path = require("path");

// Load Protocol.js with .pragma library stripped
const protoPath = path.join(__dirname, "../lib/Protocol.js");
const protoSrc = fs.readFileSync(protoPath, "utf8").replace(/^\.pragma library\s*/m, "");

const context = { module: { exports: {} } };
const fn = new Function("module", "exports", protoSrc);
fn(context.module, context.module.exports);
const Protocol = context.module.exports;

console.log("=== Testing Protocol.js ===");

// 1. Request ID Generation and Validation
{
  const id1 = Protocol.generateRequestId("req");
  assert(typeof id1 === "string", "Request ID must be string");
  assert(Protocol.isValidRequestId(id1), "Generated ID must match ID_PATTERN: " + id1);
  assert(id1.length <= 64, "Request ID must not exceed 64 chars");

  assert.strictEqual(Protocol.isValidRequestId(""), false);
  assert.strictEqual(Protocol.isValidRequestId("invalid_with_underscores!"), false);
  assert.strictEqual(Protocol.isValidRequestId("valid-id-12345"), true);
  console.log("✓ Request ID validation passed");
}

// 2. Request formatting
{
  const res = Protocol.formatRequest("snapshot", {});
  assert.strictEqual(res.ok, true);
  assert(res.text.endsWith("\n"), "Frame must be newline-terminated");
  const parsed = JSON.parse(res.text.trim());
  assert.strictEqual(parsed.v, 1);
  assert.strictEqual(parsed.method, "snapshot");
  assert.deepStrictEqual(parsed.params, {});

  // Invalid method
  const errRes = Protocol.formatRequest("", {});
  assert.strictEqual(errRes.ok, false);
  console.log("✓ Request formatting passed");
}

// 3. Response Frame Parsing
{
  const okResp = Protocol.parseFrame('{"v":1,"id":"req-1","result":{"state":"connected"}}\n');
  assert.strictEqual(okResp.type, "response");
  assert.strictEqual(okResp.id, "req-1");
  assert.strictEqual(okResp.isError, false);
  assert.strictEqual(okResp.result.state, "connected");

  const errResp = Protocol.parseFrame('{"v":1,"id":"req-2","error":{"code":"invalid_request","message":"bad param"}}\n');
  assert.strictEqual(errResp.type, "response");
  assert.strictEqual(errResp.id, "req-2");
  assert.strictEqual(errResp.isError, true);
  assert.strictEqual(errResp.error.code, "invalid_request");

  // Invalid version
  const badVer = Protocol.parseFrame('{"v":2,"id":"req-3","result":{}}\n');
  assert.strictEqual(badVer.error, "unsupported_version");

  // Malformed JSON
  const malformed = Protocol.parseFrame('{"v":1, bad}\n');
  assert.strictEqual(malformed.error, "malformed_json");

  // Event Frame
  const stateEvent = Protocol.parseFrame('{"v":1,"event":"state","data":{"state":"disconnected"}}\n');
  assert.strictEqual(stateEvent.type, "event");
  assert.strictEqual(stateEvent.event, "state");
  assert.strictEqual(stateEvent.data.state, "disconnected");

  // Progress Event
  const progEvent = Protocol.parseFrame('{"v":1,"event":"progress","data":{"id":"req-1","stage":"test","completed":5,"total":10}}\n');
  assert.strictEqual(progEvent.type, "event");
  assert.strictEqual(progEvent.event, "progress");
  assert.strictEqual(progEvent.data.completed, 5);
  console.log("✓ Response and event parsing passed");
}

// 4. JSON Depth Check
{
  let deepObj = { v: 1, id: "req-depth", result: {} };
  let cur = deepObj.result;
  for (let i = 0; i < 35; i++) {
    cur.child = {};
    cur = cur.child;
  }
  const serialized = JSON.stringify(deepObj);
  const depthRes = Protocol.parseFrame(serialized);
  assert.strictEqual(depthRes.error, "max_depth_exceeded");
  console.log("✓ Max JSON depth enforcement passed");
}

// 5. 256 KiB Frame Boundary Enforcement
{
  // Oversized frame line
  const hugePayload = "x".repeat(Protocol.MAX_FRAME_BYTES + 100);
  const hugeFrame = `{"v":1,"id":"req-huge","result":"${hugePayload}"}\n`;
  const parsedHuge = Protocol.parseFrame(hugeFrame);
  assert.strictEqual(parsedHuge.error, "frame_too_large");
  console.log("✓ Max frame size 256 KiB limit passed");
}

// 6. Chunk Accumulator
{
  let receivedFrames = [];
  let receivedErrors = [];
  const acc = Protocol.createChunkAccumulator(
    f => receivedFrames.push(f),
    e => receivedErrors.push(e)
  );

  // Split one frame across 3 chunks
  acc.feed('{"v":1,"id":"ch');
  acc.feed('unk-1","result":');
  acc.feed('{"ok":true}}\n');

  assert.strictEqual(receivedFrames.length, 1);
  assert.strictEqual(receivedFrames[0].id, "chunk-1");
  assert.strictEqual(receivedFrames[0].result.ok, true);

  // Multiple frames in one chunk
  acc.feed('{"v":1,"event":"state","data":{"busy":false}}\n{"v":1,"id":"chunk-2","result":123}\n');
  assert.strictEqual(receivedFrames.length, 3);
  assert.strictEqual(receivedFrames[1].type, "event");
  assert.strictEqual(receivedFrames[2].id, "chunk-2");

  // Buffer overflow prevention (unbounded feed without newline, strict 256 KiB)
  acc.reset();
  receivedErrors = [];
  const bigChunk = "a".repeat(Protocol.MAX_FRAME_BYTES + 10);
  acc.feed(bigChunk);
  assert(receivedErrors.length > 0, "Must report buffer overflow");
  assert.strictEqual(receivedErrors[0].code, "buffer_overflow");
  assert.strictEqual(acc.getBufferLength(), 0, "Buffer must be reset on overflow");

  // Multi-byte UTF-8 buffer overflow test (Cyrillic string takes 2 bytes per char)
  acc.reset();
  receivedErrors = [];
  const multiByteChunk = "я".repeat((Protocol.MAX_FRAME_BYTES / 2) + 10);
  acc.feed(multiByteChunk);
  assert(receivedErrors.length > 0, "Multi-byte UTF-8 input must trigger buffer overflow at 256 KiB");
  assert.strictEqual(receivedErrors[0].code, "buffer_overflow");
  console.log("✓ Chunk accumulator and buffer bounds passed");
}

// 7. Request Queue
{
  const queue = Protocol.createRequestQueue(3);
  assert.strictEqual(queue.enqueue({ id: "1" }).ok, true);
  assert.strictEqual(queue.enqueue({ id: "2" }).ok, true);
  assert.strictEqual(queue.enqueue({ id: "3" }).ok, true);
  // Max depth 3
  const overflow = queue.enqueue({ id: "4" });
  assert.strictEqual(overflow.ok, false);
  assert.strictEqual(overflow.error, "queue_full");

  // Dequeue
  const item1 = queue.dequeueNext();
  assert.strictEqual(item1.id, "1");
  assert.strictEqual(queue.getActive().id, "1");

  // While in flight, dequeueNext returns null (1 operation in flight rule)
  assert.strictEqual(queue.dequeueNext(), null);

  // Complete item 1
  queue.clearActive();
  const item2 = queue.dequeueNext();
  assert.strictEqual(item2.id, "2");

  // Cancellation
  assert.strictEqual(queue.size(), 1);
  const cancelled = queue.cancel("3");
  assert.strictEqual(cancelled.id, "3");
  assert.strictEqual(queue.size(), 0);

  console.log("✓ Request queue management passed");
}

console.log("ALL PROTOCOL TESTS PASSED!\n");

// UTF-8 bytes, rather than UTF-16 characters, define the wire size limit.
{
  const text = 'я'.repeat(140000);
  assert.strictEqual(Protocol.formatRequest('servers.import', {text}, 'utf8').ok, false);
  const frame = JSON.stringify({v: 1, id: 'utf8', result: {text}});
  assert.strictEqual(Protocol.parseFrame(frame).error, 'frame_too_large');
  assert.strictEqual(Protocol.formatRequest('servers.import', {text: 'я'.repeat(1000)}, 'utf8').ok, true);
  console.log('✓ Direct request/response UTF-8 byte ceilings passed');
}

// Backend emits uncorrelated errors and can flush multiple legal frames at once.
{
  assert.strictEqual(Protocol.isValidRequestId('req_backend-1'), false, 'Transport IDs allow alphanumeric and hyphen only');
  const uncorrelated = Protocol.parseFrame('{"v":1,"id":null,"error":{"code":"invalid_request","message":"The request is malformed or invalid."}}');
  assert.strictEqual(uncorrelated.id, null);
  assert.strictEqual(uncorrelated.isError, true);
  assert.strictEqual(uncorrelated.error.code, 'invalid_request');
  const frames = [], errors = [];
  const acc = Protocol.createChunkAccumulator(f => frames.push(f), e => errors.push(e));
  const frame = JSON.stringify({v: 1, id: 'burst', result: {text: 'x'.repeat(180000)}}) + '\n';
  acc.feed(frame + frame);
  assert.strictEqual(frames.length, 2, 'Each frame, not the combined read, has a 256 KiB limit');
  assert.strictEqual(errors.length, 0);
  acc.feed('x'.repeat(Protocol.MAX_FRAME_BYTES + 1));
  acc.feed('discard this suffix\n' + '{"v":1,"id":"recovered","result":{}}\n');
  assert.strictEqual(errors.length, 1, 'Oversized frame suffix must be discarded through its delimiter');
  assert.strictEqual(frames.at(-1).id, 'recovered');
  assert.strictEqual(acc.getBufferLength(), 0);
  console.log('✓ Backend uncorrelated errors, burst frame limits and oversized-frame resynchronization passed');
}

{
  const frames=[],errors=[];
  const acc=Protocol.createChunkAccumulator(f=>frames.push(f),e=>errors.push(e));
  for(const id of ['request',null])
    acc.feed(JSON.stringify({v:1,id,error:{code:'busy',message:'Fixture'}})+'\n');
  assert.strictEqual(errors.length,0,'Valid error responses are not framing errors');
  assert.strictEqual(frames.length,2);
  assert.strictEqual(frames[0].error.code,'busy');
  assert.strictEqual(frames[1].id,null);
  console.log('PASS: correlated and uncorrelated error responses traverse the real chunk accumulator');
}
