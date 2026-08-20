# Agent Note: History group start uses a linear scan

Status: implemented

[English](2026-08-18-history-group-start-linear-scan.md) | 中文

## Problem

打开一段较长的 ThinkInAI 对话时，`session.history` 以 `RangeError: Maximum call stack size exceeded` 失败。会话日志本身有效：一条流式 `assistant/message` 在 `sourceEventSeqs` 中引用了 255,989 个更早的 `assistant/chunk` seq，而这正是 surface 与持久化契约所要求的。

`paginate` 把该消息的连续页起点算成 `Math.min(event.seq, ...sources)`。把如此长的列表展开到调用栈上会超过 V8 的参数个数上限，因此历史 RPC 在发出任何页之前就失败了。

## Decision

`historyGroupStart` 抽出[大历史分页笔记](2026-08-04-large-history-pagination-call-stack.md)所要求的线性扫描：用循环遍历 `sourceEventSeqs`，返回该消息及其引用中的最小 seq。`session.history` 与 `subagent.history` 仍使用同一段连续原始事件页：压缩替换仍会把它引用的摘要拉到同一页，流式 assistant 消息仍会拉入每一个被引用的分片。只有最小值的计算不再使用展开。

该辅助函数是唯一实现。单元测试构造 200,000 个引用 seq，证明在此引擎上 `Math.min(...sources)` 会抛出 `RangeError`，并断言循环返回最小 seq。

## Alternatives considered

**计算页起点时忽略被引用的分片 seq。** 否决，因为每一页历史都必须是一段连续的原始事件区间。[网关 README](../../../../packages/host/apiproxy/README.md) 通过回退到最低被引用 seq，把压缩的 `compaction/summary` 留在引用它的替换同一页。跳过 `assistant/chunk` 引用会缩小部分页面，但会改变这条区间规则。

**在 loop 追加 `assistant/message` 时截断 `sourceEventSeqs`。** 否决，因为该持久字段是完整的被引用分片集合：回放、token 计量和取消证据都依赖这些精确 seq（[打包分片行](../architecture/2026-07-26-packed-chunk-rows-by-default.md)，[会话 surface](../architecture/2026-06-18-session-surface.md)）。历史分页必须能承受日志里已经存下的列表。

**在 history 处理函数中捕获 `RangeError` 并返回截断页。** 否决，因为这次失败是可避免的调用栈用法，不是损坏数据。捕获会掩盖下一次溢出，并且仍会丢掉页契约要求包含的引用前缀。

## Consequences

最长流式消息引用数十万分片的对话可以加载历史，而不再让 RPC 失败。第一页仍可能很大，因为连续区间包含从最低被引用 seq 到窗口尾的每一个事件。这份载荷成本是既有分页规则，不是新规则。

覆盖范围是辅助函数单元测试，以及 `api-proxy-view.spec.ts` 中现有的压缩历史页：它仍然要求被引用的摘要与其替换位于同一页。
