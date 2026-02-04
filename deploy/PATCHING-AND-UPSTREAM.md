# Patching and Upstream Guide

**Goal:** Maintain our custom features while pulling in upstream fixes.

> [!WARNING]
> Expect **significant conflicts** every time. Our UI changes are invasive.
> This guide documents the exact process that worked last time.

---

## The Process That Works

We use a **rebase workflow on a separate branch** to keep history clean and make conflicts manageable.

### Step 1: Create a Working Branch

Don't touch `deploy` directly. Work on a throwaway branch.

```powershell
cd openclaw-src
git fetch upstream
git checkout deploy
git checkout -b merge-upstream-updates
```

### Step 2: Rebase Onto Upstream

```powershell
git rebase upstream/main
```

**This WILL stop with conflicts.** That's expected.

### Step 3: Fix Each Conflict (One Commit at a Time)

Git will pause at each conflicting commit. For each one:

1. **See what's broken:**
   ```powershell
   git status
   ```

2. **For files WE heavily modified** (see list below): Open in editor, keep our logic, integrate any new upstream stuff we want.

3. **For files WE DON'T care about:** Just take theirs:
   ```powershell
   git checkout --theirs path/to/file
   ```

4. **Mark resolved and continue:**
   ```powershell
   git add .
   git rebase --continue
   ```

5. **Repeat** until rebase completes.

### Step 4: Build and Test

```powershell
cd ui
npm run build
```

If build fails, you missed something. Fix it, amend the commit.

### Step 5: Merge Into Deploy

Once rebase is clean and builds work:

```powershell
git checkout deploy
git merge merge-upstream-updates
git push origin deploy
```

### Step 6: Deploy

```powershell
cd ../deploy
.\deploy.ps1
```

---

## Our Patch Files (The Conflict Zones)

These are the files we've heavily modified. **Keep our logic in these:**

### 🛑 Critical (We Rewrote These)
| File | Our Change |
|------|------------|
| `ui/src/ui/app-render.helpers.ts` | **Session Panel** - entire `renderChatControls` function is ours |
| `ui/src/ui/app-chat.ts` | Removed `activeMinutes` filter in `refreshChat()` |
| `ui/src/ui/storage.ts` | Added `chatSessionsExpanded` setting |
| `ui/src/ui/navigation.ts` | Changed Chat tab subtitle |
| `ui/src/styles/chat/layout.css` | Session panel CSS, `overflow: visible` on content-header |
| `ui/src/styles/layout.css` | `overflow: visible` on `.content-header` |

### ⚠️ Medium (We Added To These)
| File | Our Change |
|------|------------|
| `ui/src/ui/app-view-state.ts` | Added session panel state |
| `ui/src/ui/controllers/models.ts` | Model dropdown logic |
| `ui/src/ui/controllers/sessions.ts` | Session management |

---

## If It All Goes Wrong

Abort and start fresh:

```powershell
git rebase --abort
git checkout deploy
git branch -D merge-upstream-updates
```

Then try again, or ask for help.

---

## Post-Merge Verification

After deploying, check:
- [ ] Session panel expands when clicked
- [ ] Old sessions (>2 hours) are visible
- [ ] New Session [+] button works
- [ ] Dropdown not clipped (overflow issue)
- [ ] Model selector works
