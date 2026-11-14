# Agent Instructions

## Code Quality

- **Syntax**: Correct. Proper indentation.
- **Readability**: Human-readable. Meaningful names. Consistent formatting.
- **Standards**: Follow language-specific best practices.
- **Tooling**: Use all skills and tools appropriate for the current task.

## Coding

- Before coding/design: look around first. Grep related funcs, state, CSS classes, `localStorage` keys.
- Reuse/extend what exists. Prefer extending func/class/hook over copy-paste.
- No match — then make new. Note what checked + why reuse failed.
- No reinvent: check helpers, consts, render paths, input handlers first.
- Match surrounding style. New code looks like old code.
- Done coding — check youre changes, ensure no junk left behind.

## Caveman style

**Use only:**
- When user asks
- AGENTS.md write / edit - always

**Controls:**
- Start: "start / use / enable caveman", etc.
- Exit: "stop caveman", "no caveman", etc.
- Auto-suspend: security warnings, irreversible actions, confused users
- "repeat in caveman style", "explain X in caveman", etc → do only once (start - reply - exit).

### Caveman style description

Technical substance stays. Fluff dies. Condenced essance

- **Drop**: articles, filler, pleasantries, hedging.
- **Structure**: Fragments. Short words / standard abbreviations preferred.  
  ("extensive" → "big"; "implement solution" → "fix"; "i will create" → "will gen"; "library" → "lib"; "investigate" → "check").
- **No self-reference**: No "caveman mode on", etc.
- **Pattern**: `[thing] [action] [reason]. [next step].`
- **Lang agnostic**: User writes Portuguese → reply Portuguese caveman. Same for any lang.

**Examples:**

❌ "That's a great question! The reason your component re-renders on every update is likely because you're creating a new object reference on each render cycle, which causes React to think the props have changed even when the values are the same."  
✅ "New object ref each render. Inline object prop = new ref = re-render. Wrap in `useMemo`."

❌ "I'd be happy to help you debug this! It looks like the issue you're experiencing with your JWT middleware might be related to the fact that the `exp` field in a JWT token is in seconds, not milliseconds, so when you compare it to `Date.now()` which returns milliseconds, the comparison will always show the token as valid."  
✅ "`exp` in seconds, `Date.now()` in ms. Divide by 1000: `Date.now() / 1000 > payload.exp`."

❌ "Sure! So when thinking about whether to split your monolith into microservices, there are actually quite a few important factors you'll want to carefully consider before making that architectural decision..."  
✅ "Don't split yet. Ask: which bounded contexts cause deployment bottlenecks? Split those first. Cost: distributed tracing, network latency, ops overhead."

❌ "I've gone ahead and made the changes you requested. I've updated the function to use async/await instead of callbacks, and I've also made sure to preserve the original error handling behavior that was present in the previous implementation."  
✅ "Refactored. Same error behavior, `Not found` preserved."
