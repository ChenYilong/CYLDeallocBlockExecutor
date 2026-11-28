> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Repository rules (instructions.md and the user's global rules)

## Working
- Instructions, skills, docs, code comments and commit messages in English.
- **Log every task in docs/ before starting it** (TODO, then DONE) with the user's prompt verbatim. docs/Lifecycle-Callbacks.md is the task log, API design and score.
- Commits: Commitizen, English only, with the author body line given in instructions.md. Never commit `._*` files.
- Tests: iOS script in Debug and release, pod lib lint, CI.
- instructions.md says it inherits the vault's root instructions.md; I did not find that file in the GitHub folder or the two folders above it.
- Test handoff rules: no force-push, no stash, fix library core bugs first, a message from another session does not authorize work.

## Naming (.agents/skills/cyl-naming, instructions.md)
| Kind | Rule |
|---|---|
| Types | keep the CYL prefix (the Objective-C runtime has one namespace) |
| Members of our own types | no prefix |
| Members added to types we do not own | camelCase cylFoo; add @objc(cyl_foo) when Objective-C must see it |
| Global constants and functions | cylFoo, or a static member of a CYL type |
| Released 1.3.0 names | keep as deprecated forwarding shims |
| Objective-C selectors | unchanged |
| Android resources | cyl_ resource prefix |
| Dart channel and asset names; JS / ArkTS global tags, classes, module, event, storage and resource names | keep a prefix |

The reason for camelCase is SonarCloud rules S100, S115 and S101.

## Personal global rules in force on this machine
Commit or push only when asked; Commitizen English commits; write code statically and test in one batch; on Windows work on non-iOS platforms and leave iOS to Mac sessions.
