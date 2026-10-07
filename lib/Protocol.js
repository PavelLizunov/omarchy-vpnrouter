.pragma library

/**
 * Protocol.js - Omarchy Headless Protocol v1 implementation
 *
 * Implements newline-delimited JSON framing, incremental chunk accumulation
 * with strict 256 KiB frame ceiling, schema validation, and request management.
 */

var PROTOCOL_VERSION = 1;
var MAX_FRAME_BYTES = 262144; // 256 KiB
var MAX_QUEUE_DEPTH = 8;
var MAX_JSON_DEPTH = 32;
var ID_PATTERN = /^[A-Za-z0-9\-]{1,64}$/;

function getUtf8ByteLength(str) {
  if (!str) return 0;
  var bytes = 0;
  for (var i = 0; i < str.length; i++) {
    var code = str.charCodeAt(i);
    if (code <= 0x7f) {
      bytes += 1;
    } else if (code <= 0x7ff) {
      bytes += 2;
    } else if (code >= 0xd800 && code <= 0xdbff) {
      bytes += 4;
      i++; // Skip low surrogate
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

function checkJsonDepth(obj, currentDepth) {
  if (!currentDepth) currentDepth = 1;
  if (currentDepth > MAX_JSON_DEPTH) return false;
  if (obj && typeof obj === "object") {
    if (Array.isArray(obj)) {
      for (var i = 0; i < obj.length; i++) {
        if (!checkJsonDepth(obj[i], currentDepth + 1)) return false;
      }
    } else {
      for (var k in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, k)) {
          if (!checkJsonDepth(obj[k], currentDepth + 1)) return false;
        }
      }
    }
  }
  return true;
}

function generateRequestId(prefix) {
  var p = (prefix || "req") + "-" + Date.now().toString(36) + "-";
  var rand = Math.floor(Math.random() * 1679616).toString(36);
  var id = p + rand;
  if (id.length > 64) id = id.slice(0, 64);
  return id;
}

function isValidRequestId(id) {
  return typeof id === "string" && ID_PATTERN.test(id);
}

function formatRequest(method, params, id) {
  if (!method || typeof method !== "string") {
    return { ok: false, error: "Method must be a non-empty string" };
  }
  var reqId = id || generateRequestId("req");
  if (!isValidRequestId(reqId)) {
    return { ok: false, error: "Invalid request id format: " + reqId };
  }
  var frameObj = {
    v: PROTOCOL_VERSION,
    id: reqId,
    method: method,
    params: (params && typeof params === "object") ? params : {}
  };
  var serialized;
  try {
    serialized = JSON.stringify(frameObj);
  } catch (e) {
    return { ok: false, error: "JSON serialization failed: " + e.message };
  }
  if (serialized.length + 1 > MAX_FRAME_BYTES) {
    return { ok: false, error: "Request exceeds maximum frame size 256 KiB" };
  }
  return {
    ok: true,
    id: reqId,
    text: serialized + "\n"
  };
}

function parseFrame(line) {
  if (!line || typeof line !== "string") return null;
  var trimmed = line.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > MAX_FRAME_BYTES) {
    return { error: "frame_too_large", message: "Frame exceeds 256 KiB limit" };
  }
  var parsed;
  try {
    parsed = JSON.parse(trimmed);
  } catch (e) {
    return { error: "malformed_json", message: "Invalid JSON syntax" };
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { error: "invalid_frame", message: "Frame must be a JSON object" };
  }
  if (!checkJsonDepth(parsed, 1)) {
    return { error: "max_depth_exceeded", message: "JSON depth exceeds 32" };
  }
  if (parsed.v !== PROTOCOL_VERSION) {
    return { error: "unsupported_version", message: "Protocol version must be 1" };
  }

  // Event frame: { v: 1, event: "...", data: { ... } }
  if (typeof parsed.event === "string") {
    if (parsed.event !== "state" && parsed.event !== "progress") {
      return { error: "unknown_event", message: "Unknown event type: " + parsed.event };
    }
    if (!parsed.data || typeof parsed.data !== "object") {
      return { error: "invalid_event_data", message: "Event data must be an object" };
    }
    return {
      type: "event",
      event: parsed.event,
      data: parsed.data
    };
  }

  // Response frame: { v: 1, id: "...", result: { ... } } OR { v: 1, id: "...", error: { ... } }
  if (typeof parsed.id === "string") {
    if (!isValidRequestId(parsed.id)) {
      return { error: "invalid_id", message: "Response id violates format" };
    }
    if (parsed.error && typeof parsed.error === "object") {
      return {
        type: "response",
        id: parsed.id,
        isError: true,
        error: {
          code: String(parsed.error.code || "unknown_error"),
          message: String(parsed.error.message || "An error occurred")
        }
      };
    }
    if (parsed.result !== undefined) {
      return {
        type: "response",
        id: parsed.id,
        isError: false,
        result: parsed.result
      };
    }
    return { error: "invalid_response", message: "Response must contain either result or error" };
  }

  return { error: "unrecognized_frame", message: "Frame is neither a response nor an event" };
}

function createChunkAccumulator(onFrame, onError) {
  var buffer = "";
  var bufferBytes = 0;

  return {
    feed: function(chunk) {
      if (typeof chunk !== "string" || chunk.length === 0) return;
      var chunkBytes = getUtf8ByteLength(chunk);
      if (bufferBytes + chunkBytes > MAX_FRAME_BYTES) {
        // Buffer overflow before finding newline (strict 256 KiB limit)
        buffer = "";
        bufferBytes = 0;
        if (onError) onError({ code: "buffer_overflow", message: "Input buffer exceeded 256 KiB before delimiter" });
        return;
      }
      buffer += chunk;
      bufferBytes += chunkBytes;
      var newlineIdx;
      while ((newlineIdx = buffer.indexOf("\n")) !== -1) {
        var line = buffer.slice(0, newlineIdx);
        buffer = buffer.slice(newlineIdx + 1);
        bufferBytes = getUtf8ByteLength(buffer);
        if (getUtf8ByteLength(line) > MAX_FRAME_BYTES) {
          if (onError) onError({ code: "frame_too_large", message: "Frame length exceeds 256 KiB" });
          continue;
        }
        var trimmed = line.trim();
        if (trimmed.length === 0) continue;
        var frame = parseFrame(trimmed);
        if (!frame) continue;
        if (frame.error) {
          if (onError) onError(frame);
        } else if (onFrame) {
          onFrame(frame);
        }
      }
    },
    reset: function() {
      buffer = "";
      bufferBytes = 0;
    },
    getBufferLength: function() {
      return buffer.length;
    },
    getBufferBytes: function() {
      return bufferBytes;
    }
  };
}

function createRequestQueue(maxDepth) {
  var cap = maxDepth || MAX_QUEUE_DEPTH;
  var queue = [];
  var inFlight = null;

  return {
    enqueue: function(req) {
      if (queue.length >= cap) {
        return { ok: false, error: "queue_full", message: "Request queue is full (max " + cap + ")" };
      }
      queue.push(req);
      return { ok: true };
    },
    dequeueNext: function() {
      if (inFlight !== null) return null;
      if (queue.length === 0) return null;
      inFlight = queue.shift();
      return inFlight;
    },
    getActive: function() {
      return inFlight;
    },
    clearActive: function() {
      var prev = inFlight;
      inFlight = null;
      return prev;
    },
    cancel: function(id) {
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].id === id) {
          return queue.splice(i, 1)[0];
        }
      }
      return null;
    },
    size: function() {
      return queue.length;
    },
    clearAll: function() {
      var remaining = queue;
      queue = [];
      inFlight = null;
      return remaining;
    },
    flushQueued: function(predicate) {
      if (!predicate) {
        var all = queue;
        queue = [];
        return all;
      }
      var flushed = [];
      var kept = [];
      for (var i = 0; i < queue.length; i++) {
        if (predicate(queue[i])) {
          flushed.push(queue[i]);
        } else {
          kept.push(queue[i]);
        }
      }
      queue = kept;
      return flushed;
    }
  };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PROTOCOL_VERSION: PROTOCOL_VERSION,
    MAX_FRAME_BYTES: MAX_FRAME_BYTES,
    MAX_QUEUE_DEPTH: MAX_QUEUE_DEPTH,
    MAX_JSON_DEPTH: MAX_JSON_DEPTH,
    getUtf8ByteLength: getUtf8ByteLength,
    checkJsonDepth: checkJsonDepth,
    generateRequestId: generateRequestId,
    isValidRequestId: isValidRequestId,
    formatRequest: formatRequest,
    parseFrame: parseFrame,
    createChunkAccumulator: createChunkAccumulator,
    createRequestQueue: createRequestQueue
  };
}
