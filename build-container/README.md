# build-container GitHub Action

This is a GitHub Action for building and optionally pushing a multi-arch container image using Podman.

If `push` is specified, and the action is not running from a PR, the container image is pushed to a registry.  The image is tagged with the name of the Git branch or tag.  If the branch name matches the `latest-branch` parameter (`main` by default), the container image is also tagged with `latest`.  If the `tags` parameter is specified, PR detection is skipped and the container image is pushed exclusively to the specified tags.

## Usage

```yaml
- uses: coreos/actions-lib/build-container@main
  with:
    # Space-separated list of Go-style architecture names
    # Default: amd64 arm64
    arches: ''

    # Build context directory
    # Default: .
    context: ''

    # Contents of ~/.docker/config.json for pushing
    credentials: ''

    # Path to Dockerfile
    # Default: Dockerfile
    file: ''

    # Branch to tag with "latest"
    # Default: main
    latest-branch: ''

    # Space-separated list of architectures to build for PRs
    # Default: <value of arches setting>
    pr-arches: ''

    # Optional space-separated list of repositories to push to
    # (ignored for PR builds)
    push: ''

    # Optional space-separated list of tags to push to
    # (overrides PR detection)
    tags: ''
```
