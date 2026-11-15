"""Deterministic doc-drift report for the docs skill (run through drift.sh)."""
import os
import re
import subprocess
import sys

SRC = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".py", ".go", ".rs", ".java", ".kt", ".kts", ".sh"}
SKIP = {".git", "node_modules", "vendor", "dist", "build", "target", ".venv", "__pycache__"}
EXPORT = [
    re.compile(r"^\s*export\s+(?:default\s+)?(?:async\s+)?(?:function\*?|class|const|let|var|interface|type|enum)\s+([A-Za-z_]\w*)"),
    re.compile(r"^(?:async\s+)?def\s+([A-Za-z]\w*)\s*\("),
    re.compile(r"^class\s+([A-Za-z]\w*)"),
    re.compile(r"^func\s+(?:\([^)]*\)\s*)?([A-Z]\w*)"),
    re.compile(r"^type\s+([A-Z]\w*)"),
    re.compile(r"^\s*pub\s+(?:async\s+)?(?:fn|struct|enum|trait|type|const|mod)\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*public\s+(?:static\s+|final\s+|abstract\s+)*(?:class|interface|enum|record|[\w<>\[\],\s]+?)\s+([A-Za-z_]\w*)\s*[({<]"),
    re.compile(r"^\s*(?:fun|class|object|interface)\s+([A-Za-z_]\w*)"),
]


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout


def default_base():
    head = git("symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD").strip()
    for ref in [head, "origin/main", "main", "origin/master", "master"]:
        if ref and git("rev-parse", "--verify", "-q", ref).strip():
            mb = git("merge-base", "HEAD", ref).strip()
            if mb and mb != git("rev-parse", "HEAD").strip():
                return mb
    return "HEAD~1" if git("rev-parse", "--verify", "-q", "HEAD~1").strip() else "HEAD"


def doc_files():
    out = []
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for f in files:
            p = os.path.relpath(os.path.join(root, f))
            if f.endswith(".md") and (p.startswith("docs/") or f in {"README.md", "AGENTS.md", "CLAUDE.md"}):
                out.append(p)
    return sorted(out)


def read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def symbols(text):
    found = set()
    for line in text.splitlines():
        for rx in EXPORT:
            m = rx.match(line)
            if m:
                found.add(m.group(1))
                break
    return found


def main(argv):
    base = argv[0] if argv else default_base()
    changed = sorted(set(git("diff", "--name-only", base).split()))
    changed_src = [f for f in changed if os.path.splitext(f)[1] in SRC]
    changed_docs = [f for f in changed if f.endswith(".md")]
    docs = {p: read(p) for p in doc_files()}
    print(f"base: {base}")

    print("\n## Changed code and the docs that mention it")
    any_pair = False
    for f in changed_src:
        names = {f, os.path.basename(f), os.path.splitext(os.path.basename(f))[0]}
        syms = symbols(read(f)) if os.path.exists(f) else set()
        hits = []
        for p, text in docs.items():
            why = [n for n in names if len(n) > 3 and n in text]
            why += [s for s in syms if len(s) > 3 and re.search(rf"\b{re.escape(s)}\b", text)]
            if why:
                hits.append(f"{p} ({', '.join(sorted(set(why))[:4])})")
        if hits:
            any_pair = True
            print(f"- {f}\n  " + "\n  ".join(hits))
    if not any_pair:
        print("- none")

    print("\n## Missing references (named in docs, not found in the repo)")
    code_files = git("ls-files").split()
    corpus = None
    missing = []
    for p, text in docs.items():
        for tok in sorted(set(re.findall(r"`([^`\s]+)`", text))):
            t = tok.rstrip("()").rstrip(",.:;")
            if "/" in t and re.search(r"\.[A-Za-z]{1,5}$", t) and not t.startswith(("http", "~", "$", "<")) and "*" not in t:
                if not os.path.exists(t) and not os.path.exists(os.path.join(os.path.dirname(p), t)):
                    missing.append(f"{p}: path `{tok}`")
            elif tok.endswith("()") and re.fullmatch(r"[A-Za-z_]\w*", t):
                if corpus is None:
                    corpus = "\n".join(read(f) for f in code_files if os.path.splitext(f)[1] in SRC)
                if not re.search(rf"\b{re.escape(t)}\b", corpus):
                    missing.append(f"{p}: symbol `{tok}`")
    print("\n".join(f"- {m}" for m in missing) or "- none")

    print("\n## Public API changed without a doc change")
    added = git("diff", "-U0", base, "--", *changed_src) if changed_src else ""
    current, flagged = None, []
    for line in added.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
        elif line.startswith("+") and not line.startswith("+++"):
            for rx in EXPORT:
                m = rx.match(line[1:])
                if m:
                    flagged.append(f"{current}: {m.group(1)}")
                    break
    if flagged and not changed_docs:
        print("\n".join(f"- {x}" for x in flagged))
    else:
        print("- none" if not flagged else f"- docs changed in this diff ({', '.join(changed_docs)}); re-read them against: " + ", ".join(flagged))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
