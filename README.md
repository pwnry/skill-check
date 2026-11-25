# Pwnry Skill Check

Checks agent skills (Claude Code, Codex, Gemini and other `SKILL.md` directories) against the public [Pwnry Skill Registry](https://pwnry.ai/en/skill-registry).

The action hashes each skill directory locally and looks the hash up in the registry. Only the hash is sent. The registry holds automated analyses of popular skills, bound to a commit and content hash; see the [methodology](https://pwnry.ai/en/skill-registry/methodology).

## Usage

```yaml
- uses: actions/checkout@v4
- uses: pwnry/skill-check@v1
  with:
    fail-on: findings   # or "unknown" to allow only skills with a published result
```

| Input | Default | Meaning |
| --- | --- | --- |
| `paths` | all directories with a `SKILL.md` | Skill directories, separated by whitespace |
| `fail-on` | `findings` | `findings`, `unknown`, or empty to only report |
| `api` | `https://pwnry.ai` | Registry origin |

`fail-on: unknown` works as an installation gate: only skills whose exact content has a published registry result pass.

## Full Skill Checks

With `check: true` the action uploads each skill directory and runs a full Skill Check: deterministic rules, static reverse engineering of included binaries and selected execution in an isolated VM. It waits for the result and fails according to `fail-on`.

```yaml
permissions:
  contents: read
  id-token: write   # proves to Pwnry which repository is asking; no secret needed
steps:
  - uses: actions/checkout@v4
  - uses: pwnry/skill-check@v1
    with:
      check: true
      publish: false   # true: publish to the Skill Registry (findings are reviewed first)
```

- **Public repositories:** 4 checks per repository per calendar month, free. Failed checks do not count.
- **Private repositories:** need a Pwnry subscription (coming soon). Until then the action falls back to a registry lookup.
- **Visibility:** results are unlisted. The log shows a report link with a secret; in public repositories, workflow logs are public, so anyone can follow that link.

| Input | Default | Meaning |
| --- | --- | --- |
| `check` | `false` | Run a full Skill Check instead of a lookup |
| `publish` | `false` | Publish the result to the Skill Registry |
| `timeout-seconds` | `1200` | Maximum wait per check |

## Without GitHub Actions

```sh
curl -fsSLO https://pwnry.ai/skill-check.sh
sh skill-check.sh --fail-on findings path/to/skill
```

The content hash is reproducible with:

```sh
cd path/to/skill && find . -type f ! -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort | while read -r f; do sha256sum "$f"; done | sha256sum
```

A result without findings is not a certification, and an indicator is not proof of malicious intent. Skills that are not listed can be checked at [pwnry.ai/skill-checks](https://pwnry.ai/en/skill-checks).
