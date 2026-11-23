# @belay/rules

Built-in danger rules for "catch a fall" (A3): `rm -rf`, force-push, `reset --hard`, `DROP`/`TRUNCATE`, prod-looking
hosts/env, `curl … | sh`, writes outside the repo, secrets paths, `chmod 777`. Each rule has a severity, a
human-readable line, and at least two positive and two negative test cases (≥ 50 cases total for v0.1).
