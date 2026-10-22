#!/usr/bin/env bash

set -euo pipefail

action_dir=$(dirname "$(readlink -f "$0")")
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

cat > "${tmpdir}/curl" <<'EOF'
#!/usr/bin/env bash

url="${!#}"
case "${url}" in
    https://api.example.test/pulls/1)
        jq -n --arg label "${MOCK_LABEL:-}" \
            '{labels: (if $label == "" then [] else [{name: $label}] end)}'
        ;;
    'https://api.example.test/pulls/1/files?per_page=100&page=1')
        jq -n '[
            {filename: "docs/release-notes.md", status: "modified"},
            {filename: "docs/release-notes/modified-note.md", status: "modified"},
            {filename: "docs/\" | error(\"injected\") | \".md", status: "modified"}
        ] + [range(97) | {filename: ("filler/" + tostring), status: "modified"}]'
        ;;
    'https://api.example.test/pulls/1/files?per_page=100&page=2')
        jq -n '[
            {filename: "docs/page-two.md", status: "added"},
            {filename: "docs/release-notes/added-note.md", status: "added"},
            {filename: "notes/v1.2.3.md", status: "modified"}
        ]'
        ;;
    *)
        echo "Unexpected URL: ${url}" >&2
        exit 22
        ;;
esac
EOF
chmod +x "${tmpdir}/curl"

run_check() {
    env \
        PATH="${tmpdir}:${PATH}" \
        FILE_PATH="${FILE_PATH:-}" \
        PATH_REGEX="${PATH_REGEX:-}" \
        FILE_STATUS="${FILE_STATUS:-}" \
        OVERRIDE_LABEL="${OVERRIDE_LABEL:-}" \
        TOKEN=test-token \
        PR_URL=https://api.example.test/pulls/1 \
        MOCK_LABEL="${MOCK_LABEL:-}" \
        "${action_dir}/check.sh"
}

expect_success() {
    if ! "$@"; then
        echo "Expected success: $*" >&2
        exit 1
    fi
}

expect_failure() {
    if "$@"; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
}

expect_failure_message() {
    expected=$1
    shift
    if output=$("$@" 2>&1); then
        echo "Expected failure: $*" >&2
        exit 1
    fi
    if [[ "${output}" != *"${expected}"* ]]; then
        echo "Expected failure output to contain: ${expected}" >&2
        echo "Actual output: ${output}" >&2
        exit 1
    fi
}

FILE_PATH=docs/release-notes.md PATH_REGEX= expect_success run_check
FILE_PATH='docs/" | error("injected") | ".md' PATH_REGEX= expect_success run_check
FILE_PATH=docs/page-two.md PATH_REGEX= expect_success run_check
FILE_PATH= PATH_REGEX='^notes/v[0-9]+\.[0-9]+\.[0-9]+\.md$' expect_success run_check
FILE_PATH=docs/page-two.md PATH_REGEX= FILE_STATUS=added expect_success run_check
FILE_PATH=docs/release-notes.md PATH_REGEX= FILE_STATUS=added \
    expect_failure_message \
        'Found no changes to docs/release-notes.md with status added.' run_check
FILE_PATH= PATH_REGEX='^docs/release-notes/[^/]+\.md$' FILE_STATUS=added \
    expect_success run_check
FILE_PATH= PATH_REGEX='^docs/release-notes/modified-[^/]+\.md$' FILE_STATUS=added \
    expect_failure_message \
        'Found no changes to paths matching ^docs/release-notes/modified-[^/]+\.md$ with status added.' \
        run_check
FILE_PATH=missing.md PATH_REGEX= \
    expect_failure_message 'Found no changes to missing.md.' run_check
FILE_PATH= PATH_REGEX='^changelog/' expect_failure run_check
FILE_PATH= PATH_REGEX= \
    expect_failure_message 'One of path or path-regex must be set.' run_check
FILE_PATH=docs/release-notes.md PATH_REGEX='.*' \
    expect_failure_message 'path and path-regex are mutually exclusive.' run_check
FILE_PATH=missing.md PATH_REGEX= OVERRIDE_LABEL=skip-notes MOCK_LABEL=skip-notes \
    expect_success run_check

echo "require-file-change tests passed"
