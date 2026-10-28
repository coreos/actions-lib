#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${FILE_PATH}" && -n "${PATH_REGEX}" ]]; then
    echo "path and path-regex are mutually exclusive." >&2
    exit 1
fi
if [[ -z "${FILE_PATH}" && -z "${PATH_REGEX}" ]]; then
    echo "One of path or path-regex must be set." >&2
    exit 1
fi

if [[ -n "${OVERRIDE_LABEL}" ]]; then
    # Don't trust the label list in the event metadata, since runs can be
    # scheduled out of order and the list might be stale.
    label=$(curl --fail --no-progress-meter \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token ${TOKEN}" \
        "${PR_URL}" |
        jq --arg override_label "${OVERRIDE_LABEL}" \
            '.labels[] | select(.name == $override_label)')
    if [[ -n "${label}" ]]; then
        echo "PR has ${OVERRIDE_LABEL} label; skipping"
        exit 0
    fi
fi

if [[ -n "${FILE_PATH}" ]]; then
    description="${FILE_PATH}"
else
    description="paths matching ${PATH_REGEX}"
fi
if [[ -n "${FILE_STATUS}" ]]; then
    description="${description} with status ${FILE_STATUS}"
fi

page=1
while true; do
    files=$(curl --fail --no-progress-meter \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token ${TOKEN}" \
        "${PR_URL}/files?per_page=100&page=${page}")

    if [[ -n "${FILE_PATH}" ]]; then
        diffinfo=$(jq --arg path "${FILE_PATH}" --arg status "${FILE_STATUS}" \
            '.[] | select(.filename == $path and ($status == "" or .status == $status))' \
            <<< "${files}")
    else
        diffinfo=$(jq --arg path_regex "${PATH_REGEX}" --arg status "${FILE_STATUS}" \
            '.[] | select((.filename | test($path_regex)) and
                ($status == "" or .status == $status))' <<< "${files}")
    fi

    if [[ -n "${diffinfo}" ]]; then
        echo "Found change to ${description}."
        exit 0
    fi

    file_count=$(jq 'length' <<< "${files}")
    if (( file_count < 100 )); then
        break
    fi
    ((page += 1))
done

echo "Found no changes to ${description}." >&2
if [[ -n "${OVERRIDE_LABEL}" ]]; then
    echo "To ignore, add ${OVERRIDE_LABEL} label to PR." >&2
fi
exit 1
