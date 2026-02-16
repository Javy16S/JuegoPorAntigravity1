# Luau Syntax Debugging Guide

Common syntax errors and how to fix them instantly.

## Error Messages Decoder

### "expected eof, got end"

**Meaning:** You have an EXTRA `end` somewhere.

**Diagnosis:**
```lua
-- Count your blocks
function test()      -- 1 function
    if x then        -- 1 if
        print("hi")
    end              -- closes if (total: 1)
end                  -- closes function (total: 2)
end                  -- EXTRA! (total: 3) ❌
```

**Fix:** Remove the extra `end`.

**Mental checklist:**
1. Count `function` keywords → should equal number of function-closing `end`s
2. Count `if`/`while`/`for` → should equal their `end`s
3. Total opens = Total closes

---

### "expected 'end' (to close 'function' at line X), got <eof>"

**Meaning:** You're MISSING an `end`.

**Diagnosis:**
```lua
function broken()
    if condition then
        for i = 1, 5 do
            work()
        end  -- closes for
    end      -- closes if
-- ❌ Missing end for function!
```

**Fix:** Add the missing `end`.

**Strategy:**
1. Find the line number in error message
2. Start from that line, indent down through nested blocks
3. For each open (`function`, `if`, `for`, `while`), mark where it closes
4. Find which one doesn't have a closing `end`

---

### "expected 'end' (to close 'if' at line X), got 'else'"

**Meaning:** You put `else` without closing the previous `if` block.

**Wrong:**
```lua
if x > 5 then
    big()
else  -- ❌ ERROR: 'if' block not closed
    small()
end
```

**Correct:**
```lua
if x > 5 then
    big()
-- No explicit 'end' needed before 'else' when it's part of the same if-else chain
else
    small()
end
```

**But if nested:**
```lua
if outer then
    if inner then
        work()
    end  -- ✓ MUST close inner 'if' before outer continues
else
    other()
end
```

---

### "expected ')' (to close '(' at line X), got ..."

**Meaning:** Unclosed parenthesis.

**Diagnosis:**
```lua
local result = calculate(x, y, getValue(z)  -- ❌ Missing closing ')'
```

**Fix:**
```lua
local result = calculate(x, y, getValue(z))  -- ✓
```

**Prevention:** Match every `(` with a `)` before moving on.

---

### "expected '}' (to close '{' at line X), got ..."

**Meaning:** Unclosed table.

**Diagnosis:**
```lua
local data = {
    name = "Test",
    values = {1, 2, 3,  -- ❌ Missing '}'
    items = {}
}
```

**Fix:**
```lua
local data = {
    name = "Test",
    values = {1, 2, 3},  -- ✓ Closed
    items = {}
}
```

---

### "expected <string>, got ..."

**Meaning:** String literal not closed.

**Diagnosis:**
```lua
local text = "Hello World
local other = 42  -- ❌ Previous string not closed
```

**Fix:**
```lua
local text = "Hello World"  -- ✓
local other = 42
```

**Multi-line strings:**
```lua
-- Use [[ ]] for multi-line
local long = [[
This is a
multi-line string
]]  -- ✓

-- Or [=[ ]=] if you need to nest [[ ]]
local nested = [=[
Contains [[brackets]] inside
]=]  -- ✓
```

---

## Block Counting Strategy

### The Manual Method

1. **Write your code**
2. **Go through line by line**
3. **Mark depth changes:**

```lua
function manager()           -- depth 0→1
    local x = 5              -- depth 1
    if x > 3 then            -- depth 1→2
        for i = 1, x do      -- depth 2→3
            print(i)         -- depth 3
        end                  -- depth 3→2
    end                      -- depth 2→1
end                          -- depth 1→0 ✓ Valid!
```

If you don't end at depth 0, something is wrong.

---

### The Bracket Method

Add comments to track closes:

```lua
function complex()                    -- [1]
    if condition then                 -- [2]
        for i = 1, 10 do              -- [3]
            while running do          -- [4]
                work()
            end                       -- closes [4]
        end                           -- closes [3]
    end                               -- closes [2]
end                                   -- closes [1] ✓
```

---

### The Diff Method

Before generating code, write a "skeleton":

```lua
-- Skeleton
function name()
    if x then
        for i = 1, 5 do
        end
    end
end
-- Count: 3 opens, 3 closes ✓

-- Then fill in logic:
function name()
    if x then
        print("starting")
        for i = 1, 5 do
            process(i)
        end
        print("done")
    end
end
-- Still 3 opens, 3 closes ✓
```

---

## Common Pitfalls

### Pitfall 1: Callback Functions

```lua
-- Easy to forget the callback's 'end'
button.Activated:Connect(function()
    print("clicked")
    if verified then
        activate()
    end
-- ❌ Forgot to close callback function!
```

**Fix:**
```lua
button.Activated:Connect(function()
    print("clicked")
    if verified then
        activate()
    end
end)  -- ✓ Close callback before closing Connect()
```

---

### Pitfall 2: Table Functions

```lua
-- Defining functions inside tables
local Module = {
    init = function()
        setup()
    -- ❌ Missing 'end' for function
    
    run = function()
        process()
    end
}
```

**Fix:**
```lua
local Module = {
    init = function()
        setup()
    end,  -- ✓ Close function
    
    run = function()
        process()
    end   -- ✓ Close function
}
```

---

### Pitfall 3: Early Returns

```lua
function check(value)
    if value == nil then
        return false
    -- ❌ 'if' not closed before 'end'
    return true
end
```

**Fix:**
```lua
function check(value)
    if value == nil then
        return false
    end  -- ✓ Close 'if'
    return true
end
```

---

## Pre-Flight Checklist

Before saving ANY Luau file:

```
[ ] Count `function` keywords
[ ] Count function-closing `end`s
[ ] Verify: function count == function end count

[ ] Count `if`/`elseif` keywords  
[ ] Count their corresponding `end`s
[ ] Verify: if count == if end count

[ ] Count `for` keywords
[ ] Count their corresponding `end`s
[ ] Verify: for count == for end count

[ ] Count `while` keywords
[ ] Count their corresponding `end`s  
[ ] Verify: while count == while end count

[ ] Count `repeat` keywords
[ ] Count their corresponding `until`s
[ ] Verify: repeat count == until count

[ ] Check all strings have matching quotes
[ ] Check all tables have matching braces
[ ] Check all parentheses are balanced

[ ] Final depth check: Start at 0, end at 0
```

If ALL boxes checked → Safe to save ✓

---

## Emergency Fix Procedure

If you get a syntax error AFTER saving:

**Step 1: Identify the error**
```
Error: "expected 'end' (to close 'function' at line 15), got <eof>"
```

**Step 2: Go to that line**
```lua
15: function spawnUnit()
```

**Step 3: Trace forward to find where it should close**
```lua
15: function spawnUnit()          -- Opens at 15
16:     local unit = create()
17:     if unit then               -- Opens at 17
18:         unit.Parent = workspace
19:     end                         -- Closes 17
20: -- ❌ Line 20 is end of file, no 'end' for line 15!
```

**Step 4: Add the missing `end`**
```lua
15: function spawnUnit()
16:     local unit = create()
17:     if unit then
18:         unit.Parent = workspace
19:     end
20: end  -- ✓ Now closes line 15
```

**Step 5: Save and re-sync**

---

## Quick Reference

| Opens | Closes | Notes |
|-------|--------|-------|
| `function` | `end` | Always needs `end` |
| `if ... then` | `end` | Can have `elseif`/`else` before `end` |
| `for ... do` | `end` | Both numeric and generic for-loops |
| `while ... do` | `end` | Loop continues until condition false |
| `repeat` | `until` | Loop at least once, NO `end` needed |
| `do` | `end` | Explicit block scope |
| `(` | `)` | Parentheses for calls, math, grouping |
| `{` | `}` | Table constructor |
| `[` | `]` | Table index or multi-line string delimiter |
| `"` or `'` | `"` or `'` | String literal (must match) |
| `[[` | `]]` | Multi-line string |
| `--[[` | `]]` | Multi-line comment |

---

## Practice Validation

**Exercise:** Find the error

```lua
function gameLoop()
    while running do
        if playerAlive then
            for _, enemy in enemies do
                enemy:update()
            end
        end
    end
```

**Answer:** Missing `end` to close `function gameLoop()`

**Corrected:**
```lua
function gameLoop()
    while running do
        if playerAlive then
            for _, enemy in enemies do
                enemy:update()
            end
        end
    end
end  -- ✓
```

---

## Remember

> "Every open must have a close. Count before you code."

**Golden Rule:** If you can't count the blocks mentally, your code is too complex. Break it into smaller functions.
