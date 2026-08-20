# Agent Note: History group start uses a linear scan

Status: implemented

English | [中文](2026-08-18-history-group-start-linear-scan.zh.md)

## Problem

Opening a long ThinkInAI conversation failed at `session.history` with `RangeError: Maximum call stack size exceeded`. The session log was valid: one streamed `assistant/message` cited 255,989 earlier `assistant/chunk` seqs in `sourceEventSeqs`, which the surface and persistence contracts require.

`paginate` computed that message's contiguous page start as `Math.min(event.seq, ...sources)`. Spreading a list that long onto the call stack exceeds V8's argument-count limit, so the history RPC failed before any page was served.

## Decision

`historyGroupStart` extracts the linear scan required by the [large-history pagination note](2026-08-04-large-history-pagination-call-stack.md): it walks `sourceEventSeqs` in a loop and returns the lowest seq among the message and its citations. `session.history` and `subagent.history` keep the same contiguous raw-event page: a compaction replacement still pulls its cited summary onto the same page, and a streamed assistant message still pulls every cited chunk. Only the minimum is computed without spreading.

The helper is the single implementation. A unit test builds a 200,000-element citation list, proves `Math.min(...sources)` throws `RangeError` on this engine, and asserts the loop returns the lowest seq.

## Alternatives considered

**Omit cited chunk seqs from the page start.** Rejected because each history page is one contiguous raw event range. The [gateway README](../../../../packages/host/apiproxy/README.md) keeps a compaction `compaction/summary` on the same page as the replacement that cites it by rewinding to the lowest cited seq. Skipping `assistant/chunk` citations would shrink some pages but would change that range rule.

**Cap `sourceEventSeqs` when the loop appends an `assistant/message`.** Rejected because the durable field is the complete cited chunk set: replay, token metering, and cancellation evidence depend on the exact seqs ([packed chunk rows](../architecture/2026-07-26-packed-chunk-rows-by-default.md), [session surface](../architecture/2026-06-18-session-surface.md)). History paging must tolerate the list the log already stores.

**Catch `RangeError` in the history handler and serve a truncated page.** Rejected because the failure is an avoidable call-stack use, not corrupt data. A catch would hide the next overflow and still drop the cited prefix the page contract includes.

## Consequences

A conversation whose longest streamed message cites hundreds of thousands of chunks loads history instead of failing the RPC. The first page can still be large, because the contiguous range includes every event from the lowest cited seq through the window tail. That payload cost is the existing paging rule, not a new one.

Coverage is the helper unit test plus the existing compaction history page in `api-proxy-view.spec.ts`, which still requires the cited summary to share the page with its replacement.
