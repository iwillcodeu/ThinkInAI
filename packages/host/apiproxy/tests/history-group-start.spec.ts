import { describe, expect, it } from 'vitest'
import { historyGroupStart } from '@deepseek-ai/dsh-host-apiproxy/src/history-group-start.ts'

/** Long enough that `Math.min(...sources)` exceeds V8's argument-count limit. */
const STREAMED_SOURCE_COUNT = 200_000

describe('historyGroupStart', () => {
  it('returns the message seq when no sources are cited', () => {
    expect(historyGroupStart(12, undefined)).toBe(12)
    expect(historyGroupStart(12, [])).toBe(12)
  })

  it('returns the lowest cited seq when the list is small', () => {
    expect(historyGroupStart(20, [18, 9, 15])).toBe(9)
    expect(historyGroupStart(4, [4, 7])).toBe(4)
  })

  it('finds the group start of a streamed assistant message without overflowing the call stack', () => {
    const sources = Array.from({ length: STREAMED_SOURCE_COUNT }, (_, i) => i)
    expect(() => Math.min(STREAMED_SOURCE_COUNT, ...sources)).toThrow(RangeError)
    expect(historyGroupStart(STREAMED_SOURCE_COUNT, sources)).toBe(0)
  })
})
