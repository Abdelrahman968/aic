# Keyboard reference

## Review prompt (after a message is generated)

| Key | Action |
|---|---|
| Enter | commit |
| e | edit the message in the git editor, then commit |
| r | retry (regenerate) |
| v | generate variants and pick one |
| h | retry with a hint for the model |
| m | pick another installed model |
| t | pick the commit type |
| s | set the scope (picks from `scopes` when configured) |
| b | toggle the breaking-change `!` |
| x | toggle gitmoji |
| a | stage changed AI-related files |
| f | re-pick files with the checklist |
| w | AI review of the staged diff (advisory) |
| c | copy the message |
| p | commit and push |
| d | view the staged diff |
| q or Esc | quit (nothing is committed, your index is untouched) |

Without raw key input (redirected input, ISE) aic asks for the same letters on a typed line.

## Pickers and the file checklist

| Key | Action |
|---|---|
| Up / Down, k / j | move |
| Home / End | first / last |
| Enter | select / confirm |
| Esc or q | cancel |
| Space | toggle a file (checklist) |
| a / n | tick all / none (checklist) |
| i | tick the AI-related files (checklist) |

In the checklist a partially staged file is marked "(partially staged)"; ticking it does **not** stage its remaining changes (use `git add <file>`). Conflicted files are not listed.

## While generating

| Key | Action |
|---|---|
| Esc | cancel generation |

## Text prompts (hint, scope)

Enter accepts, Esc cancels, Backspace deletes, Ctrl+U clears the line.
