# Enforcing the comment policy

Linters do most of the work; `scripts/comments.sh` is the cross-language catch-all for what they
can't express (a blanket ban on explanatory comments). Offer the snippet for the repo's stack and
merge it into the existing config; never replace a config wholesale.

## TypeScript / JavaScript (ESLint flat config)

Plugins: `eslint-plugin-jsdoc`, `eslint-plugin-tsdoc` (TS), `@eslint-community/eslint-plugin-eslint-comments`.

```js
rules: {
  "jsdoc/require-jsdoc": ["error", { publicOnly: true, require: { FunctionDeclaration: true, ClassDeclaration: true, MethodDefinition: true } }],
  "jsdoc/require-description": "error",
  "tsdoc/syntax": "warn",
  "@typescript-eslint/ban-ts-comment": ["error", { "ts-expect-error": "allow-with-description", "ts-ignore": true, "ts-nocheck": true }],
  "@eslint-community/eslint-comments/require-description": "error",
  "@eslint-community/eslint-comments/no-unlimited-disable": "error",
  "no-warning-comments": ["error", { terms: ["todo", "fixme", "hack", "xxx"], location: "anywhere" }],
  "no-inline-comments": "error",
}
```

## Python (ruff)

```toml
[tool.ruff.lint]
extend-select = ["D", "ERA", "FIX", "TD", "PGH003", "PGH004", "RUF100"]
[tool.ruff.lint.pydocstyle]
convention = "google"
```

`D` covers docstrings on public modules, classes and functions; `ERA001` commented-out code;
`FIX`/`TD` TODO-style comments; `PGH003/004` blanket `type: ignore` / `noqa`; `RUF100` unused
`noqa`. Ruff has no rule banning all comments: `scripts/comments.sh` covers that.

## Go (golangci-lint)

```yaml
version: "2"   # golangci-lint v2; on v1 move `settings` to a top-level `linters-settings`
linters:
  enable: [revive, godot, godox, gocritic, nolintlint]
  settings:
    revive:
      rules: [{ name: exported }, { name: package-comments }]
    gocritic:
      enabled-checks: [commentedOutCode]
    nolintlint:
      require-explanation: true
      require-specific: true
```

## Java (Checkstyle)

```xml
<module name="MissingJavadocType"><property name="scope" value="public"/></module>
<module name="MissingJavadocMethod"><property name="scope" value="public"/></module>
<module name="JavadocMethod"/>
<module name="TodoComment"><property name="format" value="(TODO|FIXME|HACK|XXX)"/></module>
<module name="TrailingComment"/>
<module name="RegexpSinglelineJava">
  <property name="format" value="^\s*//(?!\s*(SPDX|Copyright))"/>
  <property name="message" value="Explanatory comments belong in docs; use Javadoc for API."/>
</module>
```

## Rust

```rust
#![deny(missing_docs)]
#![deny(rustdoc::broken_intra_doc_links)]
#![warn(clippy::missing_errors_doc, clippy::missing_panics_doc, clippy::undocumented_unsafe_blocks)]
```

CI: `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps`.

## Kotlin (detekt)

```yaml
comments:
  UndocumentedPublicClass: { active: true }
  UndocumentedPublicFunction: { active: true }
  UndocumentedPublicProperty: { active: true }
style:
  ForbiddenComment: { active: true, comments: [{ value: 'TODO' }, { value: 'FIXME' }, { value: 'HACK' }] }
```

## Everywhere

Run `scripts/comments.sh --diff <base>` in a pre-commit hook and in CI so the policy holds
whatever editor or agent wrote the code.
