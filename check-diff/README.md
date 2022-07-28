# check-diff GitHub Action

This is a GitHub Action for comparing the diff of a PR against an expected diff, and adding annotations in GitHub's diff view for any discrepancies.

This is useful as an aid to reviewing automatically-generated PRs that contain a lot of tedious changes.  If a workflow can generate base and patch directories that abstract away the tedious changes, this Action will compare them and flag any remaining changes for manual review.

If any such changes are found, the Action will fail. This isn't necessarily cause for concern, since the changes may be benign; they just require manual review. Consider running the Action in a non-required workflow.  You can also set `continue-on-error` on the job step, which will ignore the failure and report green.

## Example

Suppose your repo has a frequently-updated configuration file, `config/details.yml`, that includes a bunch of URLs embedding the current release version of your software.  For simplicity, assume that the version is specified in the `version` key of `details.yml`.

```yaml
name: Check details.yml
on:
  pull_request:
    branches: [main]
    paths: ["config/details.yml"]
permissions:
  contents: read

jobs:
  check-diff:
    name: Check stream diffs
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v2
        with:
          # ensure we also fetch the base commit
          fetch-depth: 0
      # Make a copy of details.yml that filters out version numbers
      - name: Genericize new details.yml
        run: |
          ver=$(yq -r .version < config/details.yml)
          mkdir -p new/config
          sed -e "s/${ver}/VERSION/" config/details.yml > new/config/details.yml
      # Make a copy of the base details.yml that filters out version numbers
      - name: Genericize old details.yml
        run: |
          git checkout "${GITHUB_BASE_REF}"
          ver=$(yq -r .version < config/details.yml)
          mkdir -p old/config
          sed -e "s/${ver}/VERSION/" config/details.yml > old/config/details.yml
      # Compare them
      - name: Check details.yml
        uses: coreos/check-diff@main
        with:
          basedir: old
          patchdir: new
```

Note that the relevant part of the repo's directory structure must be replicated in `old` and `new`, or the Action won't be able to attach annotations to the correct files.  Also note that the process of genericizing files (the `sed` commands above) must not add or remove lines, or the resulting annotations won't appear on the correct lines of the diff.

## Arguments

- `basedir`: genericized original source tree (left side of comparison).  Required.
- `patchdir`: genericized modified source tree (right side of comparison).  Optional; defaults to the current directory.
- `path`: subdirectory or file to compare within `basedir` and `patchdir`.  Optional; defaults to the entire directory tree.
- `severity`: severity of annotations to add to the GitHub diff (`notice`, `warning`, `error`).  Defaults to `warning`.
