# require-file-change GitHub Action

This is a GitHub Action that fails unless a PR has changed a specific file or (optionally) has a specific label.

## Usage

For example, to check that PRs either update `docs/release-notes.md` or set the `skip-notes` label:

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
          # Required: path to the file we're interested in
          path: docs/release-notes.md
          # Optional: use this Personal Access Token to query GitHub
          # Default: ${{ github.token }}
          token: ${{ github.token }}
```
