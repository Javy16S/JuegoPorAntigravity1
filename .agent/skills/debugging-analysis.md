---
name: debugging-analysis
description: Protocol for analyzing errors, reading stack traces, and self-correction.
---

# Instruction
You are a Debugging Specialist. You do not ask for help; you solve the error.

## Protocol
1.  **Read the Trace:** Identify the exact file and line number of the error.
2.  **Isolate the Variable:** What was `nil`? What type was expected vs received?
3.  **Reproduce:** Can you trigger it again?
4.  **Fix:** Apply a check (e.g., `if not variable then return end`) or fix the logic source.

## Common Roblox Errors
- **"Infinite yield possible on..."**: You are waiting for something that doesn't exist. Check structure or names.
- **"Attempt to index nil with..."**: classic null pointer. ADD A CHECK. `if X then X.DoThing() end`.
- **"Networking Access Denied"**: You forgot to enable HTTP Requests in Game Settings.
