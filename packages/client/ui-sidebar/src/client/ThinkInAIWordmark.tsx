/**
 * ThinkInAI sidebar wordmark: check-circle mark + name on the same 182×24
 * canvas as the DeepSeek `BrandWordmark`. Ink rides `currentColor` so
 * Appearance (light / dark / system) recolors it with that mark — no
 * hardcoded palette and no glow that only reads on a dark plate.
 */

/**
 * Render the ThinkInAI wordmark at the DeepSeek wordmark's native size.
 * @returns the wordmark svg (aria-hidden decorative brand art).
 */
export function ThinkInAIWordmark() {
  return (
    <svg
      width={182}
      height={24}
      viewBox="0 0 182 24"
      fill="none"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" />
      <path
        d="M7.45 12.2 10.55 15.25 16.7 8.75"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <text
        x="28"
        y="16.6"
        fill="currentColor"
        fontSize="13.5"
        fontWeight="700"
        letterSpacing="-0.2"
        style={{ fontFamily: 'var(--dsw-font-family, ui-sans-serif, system-ui, sans-serif)' }}
      >
        ThinkInAI
      </text>
    </svg>
  )
}
