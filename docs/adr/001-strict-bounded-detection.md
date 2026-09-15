# ADR 001: Keep detection bounded and transcoding strict

- Status: Accepted
- Date: 2026-09-15

## Context

Editors need a useful encoding guess for large files, but a guess must not
silently corrupt source bytes. File reading, overwrite confirmation, and save
policy belong to the editor rather than this encoding library.

## Decision

Detection examines a bounded prefix and reports confidence plus structural
facts. BOM evidence is decisive; otherwise standard Ruby encoders validate
candidates before small language-specific scores rank them. Decode and encode
use strict conversion, preserve detected BOMs and newlines, and expose an exact
round-trip check. The caller owns every overwrite or conversion decision.

## Consequences

Very short or statistically unusual input can remain ambiguous, while hints
can improve its ranking. Unsupported or damaged text fails explicitly instead
of inserting replacement characters. Adding an encoding requires corpus
coverage rather than changing a caller's save path.
