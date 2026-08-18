// @vitest-environment jsdom
import { cleanup, render } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { ThinkInAIWordmark } from '../src/client/ThinkInAIWordmark.tsx'

afterEach(cleanup)

describe('ThinkInAIWordmark', () => {
  it('matches the DeepSeek wordmark canvas and follows currentColor', () => {
    const { container } = render(<ThinkInAIWordmark />)
    const svg = container.querySelector('svg')!
    expect(svg.getAttribute('width')).toBe('182')
    expect(svg.getAttribute('height')).toBe('24')
    expect(svg.getAttribute('viewBox')).toBe('0 0 182 24')
    expect(svg.getAttribute('aria-hidden')).toBe('true')
    expect(container.innerHTML).toContain('currentColor')
    expect(container.innerHTML).not.toMatch(/#[0-9a-fA-F]{3,8}"/)
    expect(container.textContent).toBe('ThinkInAI')
  })
})
