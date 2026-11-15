# Glossary format

`docs/GLOSSARY.md`, one line per term, alphabetical, in domain language:

```markdown
# Glossary

**<Term>** — <one-sentence meaning a domain expert would agree with>. _Not:_ <synonyms we avoid>.
```

Rules:
- No implementation detail (no class names, tables, endpoints).
- One term, one meaning. If the code uses two names for one concept, pick one here and list the
  other under _Not_.
- Add or fix a term the moment it is settled in a conversation, not at the end.
- When code names disagree with the glossary, flag it; renaming is a separate decision.
