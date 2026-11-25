# 0020: A steer is the user's own words, attributed and verbatim

- **Status:** accepted (2026-11-25)
- **Context:**
  - Spike A0 (`docs/spikes/a0-hooks.md`): a `PermissionRequest` deny message phrased as an instruction ("instead run X")
    was refused by Claude as possible prompt injection.
  - The same request, attributed to the user verbatim ("The user reviewed this request in Belay … Their reply,
    verbatim: …"), was followed.
- **Decision:**
  - Every deny message Belay sends is either a plain denial or the user's own typed or spoken reply.
  - The reply is quoted verbatim and attributed to the user, and it says how it reached Claude (Belay, the approval app the
    user configured).
  - Belay never writes instructions of its own into a decision. Rules, crew members and web content never author steers (ADR 0011).
- **Consequences:**
  - Voice steer (A4) sends the transcript, after the user confirms it, not a paraphrase.
  - Automatic catches (A3) deny with a factual reason ("Belay's danger rule `rm -rf` matched") and no instructions.
