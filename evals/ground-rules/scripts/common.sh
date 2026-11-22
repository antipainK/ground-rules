#!/bin/bash
# Shared helpers for the Ground Rules eval scripts. Source this file; do not run it.
# Every script takes plain arguments only and validates them here, so a permission
# rule on a script never grants more than the script itself does.

set -eu

GR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
EVAL_DIR="$GR_ROOT/evals/ground-rules"
RESULTS="$EVAL_DIR/results"
SCENARIOS="$EVAL_DIR/scenarios"
RUBRIC_FILE="$EVAL_DIR/rubric.json"

die() {
  echo "error: $*" >&2
  exit 1
}

# Validation matches the whole argument. grep matches line by line and would accept a
# value with an embedded newline, so newlines are rejected first and bash pattern
# matching, which anchors on the full string, does the rest.
RUN_ID_RE='^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$'
SCENARIO_RE='^[a-z0-9][a-z0-9-]*$'

validate_run_id() {
  case "$1" in *$'\n'*) die "invalid run id: contains a newline" ;; esac
  [[ $1 =~ $RUN_ID_RE ]] || die "invalid run id: $1"
}

validate_scenario() {
  case "$1" in *$'\n'*) die "invalid scenario name: contains a newline" ;; esac
  [[ $1 =~ $SCENARIO_RE ]] || die "invalid scenario name: $1"
  [ -f "$SCENARIOS/$1/scenario.json" ] && [ -d "$SCENARIOS/$1/base" ] || die "unknown scenario: $1"
}

validate_state() {
  case "$1" in
    fresh | foreign | update) ;;
    *) die "invalid state: $1 (expected fresh, foreign or update)" ;;
  esac
}

# The results folder holds run output only and must never be tracked.
require_results_ignored() {
  (cd "$GR_ROOT" && git check-ignore -q evals/ground-rules/results/probe) \
    || die "evals/ground-rules/results/ is not ignored by Git"
}

# Sets RUN_ROOT, CELL, WORKSPACE, GIT_DIR, SCENARIO_DIR, SCENARIO_FILE for a validated run, scenario and state.
cell_paths() {
  validate_run_id "$1"
  validate_scenario "$2"
  validate_state "$3"
  RUN_ROOT="$RESULTS/$1"
  CELL="$RUN_ROOT/$2/$3"
  WORKSPACE="$CELL/workspace"
  GIT_DIR="$CELL/git-data"
  SCENARIO_DIR="$SCENARIOS/$2"
  SCENARIO_FILE="$SCENARIO_DIR/scenario.json"
}

# Fixture Git commands always use the qualified form so the enclosing source
# repository is never discovered. The evaluated agent can write the fixture's git-data
# directory, so the two config entries that run a command on every status call are
# overridden on the command line (partial mitigation: other config-driven commands
# such as filter drivers are checked by verify_git_safety before fgit runs).
fgit() {
  GIT_CEILING_DIRECTORIES="$RUN_ROOT" git --git-dir="$GIT_DIR" --work-tree="$WORKSPACE" \
    --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}

# Verifies that the workspace has no symlinks, irregular files, control-char names, or nested .git
# entries; workspace/.git points to cell git-data; git-data contains no symlinks or external object
# redirections; and Git config/attributes have not been tampered with.
# Must be called before running fgit in post-run scripts.
verify_git_safety() {
  local symlink unsafe_entry nested_git
  symlink=$(find "$WORKSPACE" -type l -print -quit)
  [ -z "$symlink" ] || return 1
  unsafe_entry=$(LC_ALL=C find "$WORKSPACE" \( -name $'*[\n\r]*' -o \( ! -type f ! -type d \) \) -print -quit)
  [ -z "$unsafe_entry" ] || return 1
  nested_git=$(find "$WORKSPACE" -mindepth 2 -iname .git -print -quit)
  [ -z "$nested_git" ] || return 2
  local expected_pointer="gitdir: $GIT_DIR"
  [ -f "$WORKSPACE/.git" ] && [ ! -L "$WORKSPACE/.git" ] \
    && [ "$(cat "$WORKSPACE/.git")" = "$expected_pointer" ] \
    && [ -d "$GIT_DIR" ] && [ ! -L "$GIT_DIR" ] \
    && [ -f "$GIT_DIR/HEAD" ] || return 2
  local git_symlink
  git_symlink=$(find "$GIT_DIR" -type l -print -quit)
  [ -z "$git_symlink" ] || return 3
  cmp -s "$GIT_DIR/config" "$CELL/pre-git-config" || return 4
  if [ -f "$CELL/pre-git-config-worktree.absent" ]; then
    [ ! -e "$GIT_DIR/config.worktree" ] || return 4
  else
    cmp -s "$GIT_DIR/config.worktree" "$CELL/pre-git-config-worktree" || return 4
  fi
  if [ -f "$CELL/pre-git-info-attributes.absent" ]; then
    [ ! -e "$GIT_DIR/info/attributes" ] || return 4
  else
    cmp -s "$GIT_DIR/info/attributes" "$CELL/pre-git-info-attributes" || return 4
  fi
  if find "$WORKSPACE" -iname .gitattributes -print -quit | grep -q .; then
    return 4
  fi
  if [ -e "$GIT_DIR/commondir" ] \
    || [ -e "$GIT_DIR/objects/info/alternates" ] \
    || [ -e "$GIT_DIR/objects/info/http-alternates" ] \
    || [ -e "$GIT_DIR/info/grafts" ] \
    || [ -e "$GIT_DIR/shallow" ] \
    || { [ -d "$GIT_DIR/refs/replace" ] && find "$GIT_DIR/refs/replace" -mindepth 1 -print -quit | grep -q .; } \
    || find "$GIT_DIR" -maxdepth 1 -name 'sharedindex.*' -print -quit | grep -q .; then
    return 5
  fi
  local expected_top expected_git actual_top actual_git actual_common
  expected_top=$(cd "$WORKSPACE" && pwd -P)
  expected_git=$(cd "$GIT_DIR" && pwd -P)
  actual_top=$(fgit rev-parse --show-toplevel)
  actual_git=$(fgit rev-parse --absolute-git-dir)
  actual_common=$(fgit rev-parse --git-common-dir)
  [ "$actual_top" = "$expected_top" ] && [ "$actual_git" = "$expected_git" ] \
    && [ "$actual_common" = "$expected_git" ] && [ "$expected_git" = "$GIT_DIR" ] || return 6
  return 0
}

# Writes a deterministic, content-sensitive manifest without following symbolic links.
# Paths are hex-encoded so arbitrary file names remain one record per line.
write_tree_manifest() {
  python3 -I -c 'import hashlib,os,stat,sys
root, out = sys.argv[1:3]
rows = []
for base, dirs, files in os.walk(root, topdown=True, followlinks=False):
    dirs.sort()
    files.sort()
    for name in dirs + files:
        full = os.path.join(base, name)
        rel = os.path.relpath(full, root)
        info = os.lstat(full)
        if stat.S_ISLNK(info.st_mode):
            kind = "link"
            data = os.readlink(full).encode("utf-8", "surrogateescape")
        elif stat.S_ISREG(info.st_mode):
            kind = "file"
            with open(full, "rb") as f:
                data = f.read()
        elif stat.S_ISDIR(info.st_mode):
            kind = "dir"
            data = b""
        else:
            kind = "other"
            data = b""
        rows.append((os.fsencode(rel).hex(), kind, stat.S_IFMT(info.st_mode), stat.S_IMODE(info.st_mode), info.st_size, hashlib.sha256(data).hexdigest()))
with open(out, "w", encoding="utf-8") as f:
    for row in sorted(rows):
        f.write("%s %s %o %o %d %s\n" % row)' "$1" "$2"
}

# Fingerprints paths listed as NUL-separated repo-relative bytes. A path that Git
# reports as deleted is a normal worktree state only when lstat confirms it is
# absent. Failures after lstat remain unreadable warnings.
write_source_content_manifest() {
  python3 -I -c 'import hashlib,os,stat,sys
root = sys.argv[1]
paths = open(sys.argv[2], "rb").read().split(b"\0")
deleted = set(open(sys.argv[3], "rb").read().split(b"\0"))
for raw in sorted(p for p in paths if p):
    path = os.fsdecode(raw)
    full = os.path.join(root, path)
    try:
        info = os.lstat(full)
    except FileNotFoundError as e:
        if raw in deleted:
            print(raw.hex(), "missing")
            continue
        print(f"warning: unreadable source path: {path}: {e}", file=sys.stderr)
        print(raw.hex(), f"unreadable {e.errno}")
        continue
    except OSError as e:
        print(f"warning: unreadable source path: {path}: {e}", file=sys.stderr)
        print(raw.hex(), f"unreadable {e.errno}")
        continue
    try:
        type_mode = stat.S_IFMT(info.st_mode)
        permissions = stat.S_IMODE(info.st_mode)
        if stat.S_ISLNK(info.st_mode):
            data = os.readlink(full).encode("utf-8", "surrogateescape")
            kind = "link"
        elif stat.S_ISREG(info.st_mode):
            with open(full, "rb") as f:
                data = f.read()
            kind = "file"
        else:
            data = b""
            kind = "other"
        digest = hashlib.sha256(data).hexdigest()
        detail = f"{kind} {type_mode:o} {permissions:o} {info.st_size} {digest}"
    except OSError as e:
        print(f"warning: unreadable source path: {path}: {e}", file=sys.stderr)
        detail = f"unreadable {e.errno}"
    print(raw.hex(), detail)' "$1" "$2" "$3"
}

# Compares file type, permission bits and regular-file bytes without following
# symbolic links.
same_file_state() {
  python3 -I -c 'import os,stat,sys
a,b=sys.argv[1:3]
try:
    sa,sb=os.lstat(a),os.lstat(b)
    if stat.S_IFMT(sa.st_mode) != stat.S_IFMT(sb.st_mode) or stat.S_IMODE(sa.st_mode) != stat.S_IMODE(sb.st_mode):
        raise SystemExit(1)
    if stat.S_ISREG(sa.st_mode):
        with open(a,"rb") as fa, open(b,"rb") as fb:
            raise SystemExit(0 if fa.read() == fb.read() else 1)
    if stat.S_ISLNK(sa.st_mode):
        raise SystemExit(0 if os.readlink(a) == os.readlink(b) else 1)
    raise SystemExit(0)
except OSError:
    raise SystemExit(1)' "$1" "$2"
}

# Lists paths that exist in both trees with changed file type or permission bits.
write_mode_changes() {
  python3 -I -c 'import os,stat,sys
before,after,out=sys.argv[1:4]
changed=[]
for base,dirs,files in os.walk(before,topdown=True,followlinks=False):
    dirs.sort()
    files.sort()
    for name in dirs+files:
        old=os.path.join(base,name)
        rel=os.path.relpath(old,before)
        if rel == ".git":
            continue
        new=os.path.join(after,rel)
        try:
            a,b=os.lstat(old),os.lstat(new)
        except OSError:
            continue
        if stat.S_IFMT(a.st_mode) != stat.S_IFMT(b.st_mode) or stat.S_IMODE(a.st_mode) != stat.S_IMODE(b.st_mode):
            changed.append(rel)
with open(out, "w", encoding="utf-8") as f:
    for rel in changed:
        f.write(rel+"\n")' "$1" "$2" "$3"
}

# Writes created.txt, deleted.txt, modified.txt and changed.txt (one repo-relative path per
# line) into the existing directory $1, for the cell set up by cell_paths.
# Compares current WORKSPACE directly against CELL/initial-workspace in one Python pass
# so deleted tracked files are never misclassified as modified and lockfiles do not spawn
# one subprocess per file.
write_changed_lists() {
  local out="$1"
  python3 -I -c 'import os,stat,sys
ws, cell, out = sys.argv[1:4]
init_ws = os.path.join(cell, "initial-workspace")
init_list_path = os.path.join(cell, "initial-files.txt")

def same_state(a, b):
    try:
        sa, sb = os.lstat(a), os.lstat(b)
        if stat.S_IFMT(sa.st_mode) != stat.S_IFMT(sb.st_mode) or stat.S_IMODE(sa.st_mode) != stat.S_IMODE(sb.st_mode):
            return False
        if stat.S_ISREG(sa.st_mode):
            if sa.st_size != sb.st_size:
                return False
            with open(a, "rb") as fa, open(b, "rb") as fb:
                return fa.read() == fb.read()
        if stat.S_ISLNK(sa.st_mode):
            return os.readlink(a) == os.readlink(b)
        return True
    except OSError:
        return False

current = set()
for base, dirs, files in os.walk(ws, topdown=True, followlinks=False):
    if base == ws and ".git" in dirs:
        dirs.remove(".git")
    for name in files:
        full = os.path.join(base, name)
        if full == os.path.join(ws, ".git"):
            continue
        try:
            st = os.lstat(full)
        except OSError:
            continue
        if stat.S_ISREG(st.st_mode):
            current.add(os.path.relpath(full, ws))

initial = set()
with open(init_list_path, "r", encoding="utf-8", errors="surrogateescape") as f:
    for line in f:
        rel = line.rstrip("\n")
        if rel.startswith("./"):
            rel = rel[2:]
        if rel:
            initial.add(rel)

created = sorted(current - initial)
deleted = sorted(initial - current)
common = sorted(initial & current)
modified = []
for rel in common:
    ia = os.path.join(init_ws, rel)
    wa = os.path.join(ws, rel)
    if os.path.isfile(ia) and os.path.isfile(wa) and not same_state(ia, wa):
        modified.append(rel)
changed = sorted(set(created) | set(deleted) | set(modified))

def dump_lines(name, items):
    with open(os.path.join(out, name), "w", encoding="utf-8", errors="surrogateescape") as f:
        for item in items:
            f.write(item + "\n")

dump_lines("current.txt", sorted(current))
dump_lines("initial.txt", sorted(initial))
dump_lines("created.txt", created)
dump_lines("deleted.txt", deleted)
dump_lines("common.txt", common)
dump_lines("modified.txt", modified)
dump_lines("changed.txt", changed)' "$WORKSPACE" "$CELL" "$out"
}
