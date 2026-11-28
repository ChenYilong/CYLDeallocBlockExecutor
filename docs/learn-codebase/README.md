# learn-codebase: setup, ingestion and publishing

Read this before running `/claude-mem:learn-codebase` in this repository.

It records what we learned on 2026-11-29 with **claude-mem 17.0.2** on Windows. Plugin behavior can change between versions, so recheck it on a newer one. Statements marked *(code reading)* come from reading the plugin's bundled code and were not tested.

This repository is **public**. Treat everything in `docs/learn-codebase/` as published once committed.

## Placeholders

| Placeholder | Meaning |
|---|---|
| `<repo path>` | Absolute path of this repository on the current computer |
| `<port>` | `CLAUDE_MEM_WORKER_PORT` in the claude-mem settings |
| `<YYYY-MM-DD>` | Date of the run |
| `<OS user name>`, `<full name>`, `<cloud folder>` | Your own values. Never write them into this repository |

## Quick checklist on a new computer

1. Clone the repository and check out a branch that contains `docs/learn-codebase/`. On 2026-11-29 the first notes were pushed on `docs/learn-codebase-notes`.
2. Install claude-mem and confirm that its worker is running.
3. Add the watch root (section 2) and restart the worker.
4. Verify ingestion (section 3).
5. Start the session **in the repository folder**, then run learn-codebase with an explicit output path (section 1).
6. Before any commit, follow the publishing steps (section 4).

The claude-mem database does not travel with git. On a new computer, the watch root imports the committed `.md` notes again. Other memory records are not recreated this way.

## 1. Choosing where the notes go

- The learn-codebase skill has **no output path option**. It only asks the agent to read every source file in full. If you want files, say so in your prompt.
- We found no setting that moves only the claude-mem deliverables folder *(code reading)*. It is `deliverables/` inside the data directory. `CLAUDE_MEM_DATA_DIR` moves the **whole** data directory, database included. Do not change it for this purpose.
- So write the notes into the repository.

Prompt to use:

```text
/claude-mem:learn-codebase
Then write what you learned to docs/learn-codebase/learn-codebase-<YYYY-MM-DD>/.
Start with a README.md and put unverified findings in a separate file.
Label each finding as reproduced, read only, or unverified.
Do not write local paths, user names, e-mail addresses or credentials into these files.
Do not register these files as work_product. Do not commit.
```

Notes:

- **Start the session in the repository folder.** Our session started in the parent folder, and its own memory records went under the parent folder's name, not this repository's. We expect a session started here to use `CYLDeallocBlockExecutor`, which matches the watch root; we did not test that.
- **Writing straight into `~/.claude-mem/deliverables/` does not register a deliverable.** The files we wrote there were only ordinary files. For another repository's notes in the same folder, the hook log said the path was outside the checkout and the temp folders and was not copied.
- **Do not register notes inside the repository as `work_product`.** That copies them back into the deliverables folder *(code reading)*, leaving two copies that do not sync.
- **Avoid hiding the notes with `.gitignore` as a way to keep them private.** Ignored files that a session writes inside its checkout are treated as deliverables and copied *(code reading)*.
- **Write each run into a new dated folder.** Old snapshots then stay unchanged, and every note should state the commit it describes.

## 2. Reconfiguring CLAUDE_MEM_MEMORY_WATCH_ROOTS

This setting makes claude-mem import Markdown files from a folder as memory records. It is stored **per computer** and is not part of the repository.

**File:** `settings.json` in the claude-mem data directory, by default `~/.claude-mem/settings.json`.

> **Warning:** this file can hold a cloud sync token in plain text, and so can every backup copy of it. Never commit it, paste it into a chat or an issue, or print the whole file.

**Format.** The value is a JSON array **stored as a string**, so it is escaped twice. Before escaping, it looks like this:

```json
[{"path": "<repo path>/docs/learn-codebase", "project": "CYLDeallocBlockExecutor"}]
```

| Rule | Detail |
|---|---|
| Entries | At most 8 *(code reading)*. Several repositories can share the list, so **add to it; do not overwrite it** |
| `path` | Absolute, or starting with `~/`, which is expanded to the home directory *(code reading)* |
| `project` | The name the records are stored and searched under. Use `CYLDeallocBlockExecutor` |
| Scope | Point at `docs/learn-codebase`, not the whole `docs/` folder |

**Use a script instead of escaping by hand.** Save this outside the repository as `add_watch_root.py`:

```python
import json, os, shutil, sys, time

settings_path, repo_path, project = sys.argv[1:4]
notes = os.path.join(os.path.abspath(repo_path), "docs", "learn-codebase")
if not os.path.isdir(notes):
    sys.exit("Folder not found: " + notes)

with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

key = "CLAUDE_MEM_MEMORY_WATCH_ROOTS"
if key not in settings:
    sys.exit(key + " is not a top-level key; check the file layout of this claude-mem version")

roots = json.loads(settings[key] or "[]")
# Keep the other repositories; replace only the entry for this project.
roots = [r for r in roots if r["project"] != project]
roots.append({"path": notes, "project": project})
if len(roots) > 8:
    sys.exit("claude-mem accepts at most 8 watch roots; remove one first")

backup = settings_path + ".bak-watchroots-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(settings_path, backup)
settings[key] = json.dumps(roots)  # the value is a JSON string inside a JSON file
with open(settings_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("Watch roots now:", ", ".join(r["project"] for r in roots))
print("Backup:", os.path.basename(backup))
```

Run it with Python 3:

```sh
python -I add_watch_root.py ~/.claude-mem/settings.json "<repo path>" CYLDeallocBlockExecutor
```

The script replaces an existing entry with the same project name, keeps the others, and makes a backup first. It rewrites the whole file with two-space indentation.

**Restart the worker.** The watcher is created only when the worker starts. All open sessions share this worker, so restart it when a short interruption is acceptable.

```sh
curl -s http://127.0.0.1:<port>/api/health                  # note the pid
curl -s -X POST http://127.0.0.1:<port>/api/admin/restart
curl -s http://127.0.0.1:<port>/api/health                  # after a few seconds: new pid, "initialized":true
```

## 3. Verifying ingestion

Count the imported records and distinct files. This uses only the Python standard library:

```sh
python -I -c "import sqlite3,os,pathlib; u=pathlib.Path(os.path.expanduser('~/.claude-mem/claude-mem.db')).as_uri()+'?mode=ro'; print(sqlite3.connect(u,uri=True).execute(\"select count(*), count(distinct json_extract(metadata,'$.sourcePath')) from observations where project='CYLDeallocBlockExecutor' and json_valid(metadata) and json_extract(metadata,'$.source')='memory-file'\").fetchone())"
```

The second number should equal the number of `.md` files under `docs/learn-codebase/`. The first is larger after edits.

Then search with the project name:

```sh
curl -s -G http://127.0.0.1:<port>/api/search --data-urlencode "query=lifecycle findings" --data-urlencode "project=CYLDeallocBlockExecutor"
```

What the watcher does *(code reading, apart from the import and revisions we observed)*:

- Reads `.md` files only. `.tsv` lists, scripts and text output are not imported.
- Skips files larger than **64 KB**. The largest note so far, `api-index.md`, is about 55 KB. Split a note before it reaches the limit.
- Stops at 500 files per root and a folder depth of 8.
- Skips symbolic links and names that start with a dot.
- Stores **each changed version as a new record**. Old versions stay.
- A different repository path produces new records, because the path is part of each record's fingerprint.

Records under this project are not part of the start-up timeline of a session that uses another project name (with `CLAUDE_MEM_CONTEXT_PROJECTS=current`). Search with the project name, or work from the repository folder.

The notes exist on disk only while the checked-out branch contains them. On other branches the watcher finds nothing new; records already stored remain.

**Ingestion happens before review.** The watcher imports a file shortly after it is written. Redacting it later does not remove the earlier version from the local database. So keep secrets out of this folder from the start.

## 4. Removing private information and committing

Do these in order. Commit and push only when the repository owner asks for it.

### 4.1 Prepare

1. Check whether the repository is public: `gh repo view --json visibility`.
2. Use a separate branch for the notes. Do not add them to the branch of an unrelated open pull request. Check which commits the new branch carries compared with `master` before you open a pull request.
3. Follow the repository rules in [`instructions.md`](../../instructions.md): add a TODO entry with the verbatim prompt to the task log in [`docs/Lifecycle-Callbacks.md`](../Lifecycle-Callbacks.md), and use the commit format and author line given there.
4. **A verbatim prompt can contain local paths.** Shorten them to `~/...` and add a visible note saying so. Do this **before the first `git add`**, so that git history never needs rewriting.

### 4.2 Scan for personal data

Put the patterns in a file **outside the repository**. A pattern file avoids shell quoting mistakes, which broke our inline searches. Replace the placeholders with your real values there, never here.

```text
(^|[^A-Za-z])[A-Za-z]:[\\/]
[\\/]Users[\\/]
[\\/]home[\\/][a-z]
<OS user name>
<full name>
<cloud folder>
App[D]ata
One[D]rive
scratch[p]ad
\.claude[\\/](projects|plugins)
[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
```

Also add any local worktree folders and lock-file paths you used.

```sh
grep -rniE -f <pattern file> docs/learn-codebase
git diff docs/ | grep '^+' | grep -niE -f <pattern file>
```

Review every match. In our run:

- Image names such as `name@2x.png` matched the e-mail pattern and are harmless.
- The first pattern asks for a non-letter before the drive letter, so that `http://` does not match.
- Identifiers that are already public in the repository were kept: the GitHub account in URLs, bundle identifiers, and tracked `xcuserdata` paths in the file inventory. Removing the last would make the inventory disagree with `git ls-files`.
- A local lock-file path was removed from one note.

### 4.3 Scan for credentials

First, a keyword search. Read each matching line:

```sh
grep -rniE "secret|token|passw|api[_-]?key|private[_ -]?key|credential|keystore|bearer|signing" docs/learn-codebase
```

These commands also match their own lines in this guide.

Most matches in code notes are identifiers. Ours were `signingConfigs`, `scrollToken`, `windowToken` and two mentions of `keystore`. Do not copy the contents of any key or keystore file into the notes.

Second, a search for common credential formats. A clean result does not prove that there is no secret.

```sh
grep -rnE "ghp_[A-Za-z0-9]{20}|github_pat_|sk-[A-Za-z0-9_-]{20}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{20,}\." docs/learn-codebase
```

### 4.4 Mark what nobody has reviewed

Put this at the top of every note, with the correct commit:

```markdown
> **Not reviewed.** AI-generated notes on commit `<commit>`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.
```

In findings tables, spell out the evidence for each row, for example "read only, not reproduced". If something was reproduced on only one platform, say which. Check line numbers and quoted claims against the repository before publishing. In our run, reading more files changed several earlier findings.

### 4.5 Stage, check, commit and push

1. Stage exact paths only, for example `git add docs/learn-codebase docs/Lifecycle-Callbacks.md`. Do not use `git add .`.
2. Check the list with `git diff --cached --name-status`. It must not contain `._*` files, settings files or backups.
3. Run the scans of 4.2 and 4.3 again on the staged additions: `git diff --cached | grep '^+' | grep -niE -f <pattern file>`.
4. Run `git diff --cached --check`.
5. Confirm that `git config user.email` is the address the repository rules require.
6. Mark the task log entry DONE, commit, then push. Confirm with `git ls-remote --heads origin <branch>` that the remote commit equals `git rev-parse HEAD`.

Cleaning the committed files does not change old records in the local claude-mem database. If you use claude-mem cloud sync, check what it uploads; we did not verify that.

## Snapshots

| Folder | Commit described | Start here |
|---|---|---|
| [`learn-codebase-2026-11-29/`](learn-codebase-2026-11-29/README.md) | `505d187` | Its `README.md`, then `09-findings.md` |
