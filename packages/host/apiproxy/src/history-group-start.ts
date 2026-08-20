/**
 * Lowest seq that belongs to one history-page group.
 * @module @deepseek-ai/dsh-host-apiproxy/history-group-start
 */

/**
 * Inclusive start of the contiguous history page that must keep one surface
 * message with the events it cites. A streamed `assistant/message` records
 * every `assistant/chunk` seq in `sourceEventSeqs`; spreading that list into
 * `Math.min` overflows the JavaScript call stack once the run is long enough.
 * @param seq - the surface message's own seq.
 * @param sources - `sourceEventSeqs` cited by that message, when present.
 * @returns `seq` when nothing is cited, otherwise the lowest value among `seq` and `sources`.
 */
export function historyGroupStart(seq: number, sources: readonly number[] | undefined): number {
  if (sources === undefined || sources.length === 0) return seq
  let start = seq
  for (const source of sources) {
    if (source < start) start = source
  }
  return start
}
