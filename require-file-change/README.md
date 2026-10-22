# require-file-change GitHub Action

This is a GitHub Action that fails unless a PR has changed a specific file, changed a file whose path matches a regular expression, or (optionally) has a specific label. Exactly one of `path` or `path-regex` must be set.

## Usage

### Exact path

To check that PRs either update `docs/release-notes.md` or set the `skip-notes` label:

```yaml
name: Release notes

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, labeled, unlabeled]

permissions:
  contents: read

jobs:
  require-notes:
    name: Require release note
    runs-on: ubuntu-latest
    steps:
      - name: Require release-notes.md update
        uses: coreos/actions-lib/require-file-change@main
        with:
          # Optional: if the PR has this label, skip the check
          override-label: skip-notes
          # Exact path to the file we're interested in
          path: docs/release-notes.md
          # Optional: use this Personal Access Token to query GitHub
          # Default: ${{ github.token }}
          token: ${{ github.token }}
```

### Path regular expression

To accept any newly added Markdown file directly under `docs/release-notes/`:

```yaml
- name: Require a release note
  uses: coreos/actions-lib/require-file-change@main
  with:
    path-regex: '^docs/release-notes/[^/]+\.md$'
    status: added
```

`path-regex` uses jq regular expression syntax. Set either `path` or `path-regex`, but not both.
The optional `status` input also requires the matching file to have that GitHub pull-files API status, such as `added`, `modified`, or `removed`. If `status` is omitted, files of any status match as before.
