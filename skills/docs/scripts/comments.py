"""Heuristic checker for the docs skill's comment policy (run through comments.sh)."""
import os
import re
import subprocess
import sys

SLASH = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".go", ".rs", ".java", ".kt", ".kts"}
HASH = {".py", ".sh", ".bash"}
SKIP_DIRS = {".git", "node_modules", "vendor", "dist", "build", "target", ".venv", "__pycache__"}
TASK = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b")
HEADER = re.compile(r"(SPDX-License-Identifier|Copyright|Licensed under|License)", re.I)
CODEISH = re.compile(r"(;\s*$|[{}]\s*$|^\s*(return|if|for|while|const|let|var|def|func|import|from)\b|\w+\(.*\)\s*;?\s*$|=)")


def strip_strings(line):
    out, quote, i = [], None, 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            out.append(" ")
        elif c in "\"'`":
            quote = c
            out.append(" ")
        else:
            out.append(c)
        i += 1
    return "".join(out)


def kind(text):
    return "commented-out code" if CODEISH.search(text) else "explanatory comment"


def go_exported_decl(lines, i):
    j = i + 1
    while j < len(lines) and lines[j].strip().startswith("//"):
        j += 1
    if j >= len(lines):
        return False
    decl = lines[j]
    return bool(re.match(r"^(func(\s*\([^)]*\))?|type|var|const)\s+[A-Z]", decl) or re.match(r"^package\s", decl)
                or re.match(r"^\s+[A-Z]\w*(\s|$|\()", decl))


def slash_directive(body, ext):
    b = body.strip()
    if re.match(r"^(eslint-disable|eslint-enable)", b):
        return "ok" if "--" in b else "directive without a reason"
    if b.startswith("@ts-ignore") or b.startswith("@ts-nocheck"):
        return "@ts-ignore is not allowed; use @ts-expect-error with a reason"
    if b.startswith("@ts-expect-error"):
        return "ok" if len(b) > len("@ts-expect-error") + 2 else "directive without a reason"
    if ext == ".go" and b.startswith("nolint"):
        return "ok" if "//" in b else "directive without a reason"
    if ext == ".go" and re.match(r"^(go:|export\s|line\s)", b):
        return "ok"
    if b.startswith("prettier-ignore") or b.startswith("biome-ignore") or b.startswith("istanbul ignore") or b.startswith("c8 ignore"):
        return "ok"
    return None


def check_slash(path, lines, ext):
    out, in_block, block_ok, block_start = [], False, False, 0
    for i, raw in enumerate(lines):
        n = i + 1
        line = raw.rstrip("\n")
        if in_block:
            if TASK.search(line):
                out.append((n, "TODO/FIXME in a comment; open an issue instead"))
            if "*/" in line:
                in_block = False
            continue
        code = strip_strings(line)
        s = code.lstrip()
        if s.startswith("/*"):
            doc = s.startswith("/**") and not s.startswith("/**/")
            header = i < 5 and HEADER.search(line)
            if TASK.search(line):
                out.append((n, "TODO/FIXME in a comment; open an issue instead"))
            elif not (doc and ext in {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".java", ".kt", ".kts"}) and not header:
                out.append((n, "block comment; move it to docs or a doc comment"))
            if "*/" not in s[2:]:
                in_block = True
            continue
        idx = code.find("//")
        if idx < 0:
            continue
        before, body = code[:idx], line[idx + 2:]
        if TASK.search(body):
            out.append((n, "TODO/FIXME in a comment; open an issue instead"))
            continue
        if i < 5 and HEADER.search(body):
            continue
        d = slash_directive(body, ext)
        if d == "ok":
            continue
        if d:
            out.append((n, d))
            continue
        if before.strip():
            out.append((n, "trailing " + kind(body)))
            continue
        if ext == ".rs" and (body.startswith("/") or body.startswith("!") or body.strip().startswith("SAFETY:")):
            continue
        if ext == ".go" and go_exported_decl(lines, i):
            continue
        out.append((n, kind(body)))
    return out


def check_hash(path, lines, ext):
    out, header = [], True
    for i, raw in enumerate(lines):
        n = i + 1
        line = raw.rstrip("\n")
        if i == 0 and line.startswith("#!"):
            continue
        code = strip_strings(line)
        s = code.lstrip()
        if ext == ".py" and i < 2 and re.match(r"#.*coding[:=]", s):
            continue
        idx = code.find("#")
        if idx < 0:
            if s:
                header = False
            continue
        before, body = code[:idx], line[idx + 1:]
        if TASK.search(body):
            out.append((n, "TODO/FIXME in a comment; open an issue instead"))
            continue
        if ext in {".sh", ".bash"} and before and not before.endswith((" ", "\t")):
            continue
        b = body.strip()
        if ext in {".sh", ".bash"} and header and not before.strip():
            continue
        if i < 5 and HEADER.search(b):
            continue
        if ext == ".py":
            if re.match(r"noqa\b", b):
                if not re.match(r"noqa:\s*[A-Z]+\d+", b):
                    out.append((n, "bare noqa; name the rule"))
                continue
            if re.match(r"type:\s*ignore", b):
                if not re.match(r"type:\s*ignore\[[\w-]+", b):
                    out.append((n, "bare type: ignore; name the error code"))
                continue
            if re.match(r"(pragma: no cover|fmt: (on|off|skip)|isort: |pyright: |mypy: )", b):
                continue
        if ext in {".sh", ".bash"} and re.match(r"shellcheck\s", b):
            continue
        if before.strip():
            out.append((n, "trailing " + kind(b)))
        else:
            header = False
            out.append((n, kind(b)))
    return out


def files_from(args):
    if args and args[0] == "--diff":
        base = args[1] if len(args) > 1 else "HEAD"
        names = subprocess.run(["git", "diff", "--name-only", "--diff-filter=ACMR", base], capture_output=True, text=True).stdout.split()
        names += subprocess.run(["git", "diff", "--name-only", "--diff-filter=ACMR", "--cached"], capture_output=True, text=True).stdout.split()
        return sorted(set(f for f in names if os.path.isfile(f)))
    found = []
    for p in args or ["."]:
        if os.path.isfile(p):
            found.append(p)
            continue
        for root, dirs, fs in os.walk(p):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            found += [os.path.join(root, f) for f in fs]
    return sorted(found)


def main(argv):
    findings = 0
    for f in files_from(argv):
        ext = os.path.splitext(f)[1]
        if ext not in SLASH | HASH:
            continue
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                lines = fh.readlines()
        except OSError:
            continue
        res = check_slash(f, lines, ext) if ext in SLASH else check_hash(f, lines, ext)
        for n, why in res:
            print(f"{f}:{n}: {why}")
            findings += 1
    if findings:
        print(f"{findings} comment(s) break the policy: move the why to the module README or an ADR, or delete them", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
