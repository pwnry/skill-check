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
