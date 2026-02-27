# Contributing

This guide is being expanded carefully rather than rewritten all at once. The goal is to make it more useful without losing clinically relevant wording that is already present.

## Core Editing Rules

- Preserve information. Reorganize and clarify freely, but do not remove detail just to make a section shorter.
- Include both Devanagari and transliteration for every term or phrase when possible.
- Add a back-translation when the literal meaning or idiomatic force would not be obvious to an English-speaking reader.
- Prefer example usage for high-yield terms, especially when the phrase is colloquial, culturally specific, or easy to misread.
- Label register clearly. If a term is respectful, blunt, euphemistic, stigmatizing, literary, or regionally variable, say so.
- Keep related duplicates when they help clinical use. If a term belongs in more than one section, cross-linking or selective repetition is acceptable.

## Style Notes

- Keep original section numbering and titles inside the files for traceability.
- Prefer short meaning notes over broad summaries.
- Use respectful imperative forms for commands unless there is a reason to document a blunter or more colloquial form.
- When adding psychiatric, reproductive, or culturally sensitive language, include stigma or usage notes where relevant.
- If left/right pairs are added, consider whether both the written and spoken/common variants should be documented.

## Repository Layout

- `README.md` is the main entry point for GitHub readers.
- Section groups live at the repository root:
  - `01-foundations/`
  - `02-body-systems/`
  - `03-special-populations/`
  - `04-diseases-and-conditions/`
  - `05-clinical-workflow-and-care/`
  - `06-context-lifestyle-and-end-of-life/`

## Local-Only Files

- `.local-tools/` is for local helper scripts and is intentionally ignored.
- `tools/` is also ignored to avoid republishing converter scripts or scratch utilities by accident.
- Editor swap files and other transient local artifacts should stay out of version control.
