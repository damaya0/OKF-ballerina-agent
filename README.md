# SupportOKF

A customer-support knowledge system built on the [Open Knowledge Format
(OKF)](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md):
a directory of markdown files with YAML frontmatter, cross-linked by id. Two
Ballerina programs do the work:

- **`okf_bundle_builder`** converts a folder of raw support docs into an OKF
  bundle -- one concept document per source file, plus a generated
  `index.md` at every directory level.
- **`okf_ballerina_agent`** answers a question by handing Claude the
  bundle's root index and letting it open one concept at a time (by concept
  id, resolved through a flat lookup map) until it has enough to answer.

```
docs/  --[okf_bundle_builder]-->  docs_bundle/  --[okf_ballerina_agent]-->  answer
(your raw docs,                   (the OKF bundle,
 not committed)                    not committed)
```

`docs/` and `docs_bundle/` contain real customer support content and are
never committed -- both are excluded via the root `.gitignore`. You supply
`docs/` yourself after cloning; `docs_bundle/` is generated.

## Prerequisites

- [Ballerina](https://ballerina.io/downloads/) (Swan Lake 2201.13 or later)
- An [Anthropic API key](https://console.anthropic.com/)

## 1. Clone

```
git clone <this-repo-url>
cd SupportOKF
```

## 2. Add your docs

Create a `docs/` folder at the repo root and put your own markdown
documentation in it, in whatever structure fits your content --
subdirectories are fine, any nesting depth. `okf_bundle_builder` only cares
that files end in `.md`.

## 3. Build the OKF bundle

```
cd okf_bundle_builder
cp Config.toml.example Config.toml
```

Edit `Config.toml`:

| Key                  | Value                                              |
|----------------------|-----------------------------------------------------|
| `anthropicApiKey`    | your Anthropic API key                             |
| `anthropicModelName` | an id from `anthropic:ANTHROPIC_MODEL_NAMES`, e.g. `claude-sonnet-4-5` |
| `sourceDirPath`      | path to your `docs/` folder (default: `../docs`)   |
| `bundleRootPath`     | where to write the bundle (default: `../docs_bundle`) |

Then run it:

```
bal run
```

This classifies each file's frontmatter (type/title/description/tags) via
one model call per file, carries the body through **verbatim** (never
rewritten, so nothing is lost regardless of file size), and regenerates
every `index.md` bottom-up. Rerunning it later regenerates the whole bundle
from scratch -- it's not incremental.

## 4. Ask questions

```
cd ../okf_ballerina_agent
cp Config.toml.example Config.toml
```

Edit `Config.toml`: same `anthropicApiKey`/`anthropicModelName` as above,
plus `bundleRootPath` pointing at the bundle you just built (default:
`../docs_bundle`).

Then run it, either with the question inline:

```
bal run -- "How do I investigate a customer's free play issues?"
```

or interactively (it'll prompt for the question):

```
bal run
```

