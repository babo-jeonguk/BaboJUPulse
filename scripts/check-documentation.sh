#!/usr/bin/env bash
# Validate tracked and untracked Markdown documentation without building the app.
# Checks relative links, heading fragments, Git-ignored targets, local absolute
# paths, table shape, fenced code closure, and the public-content policy.
# Failures report a rule identifier, a safe repository-relative file label, and
# a line number. Link targets and matching text are not printed.
#
# Usage:
#   scripts/check-documentation.sh                 # all tracked/untracked Markdown
#   scripts/check-documentation.sh --files <path>  # scan named files
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

rule_failed=0

report() {
    printf 'documentation: rule=%s file=%s line=%s\n' "$1" "$2" "$3" >&2
    rule_failed=1
}

safe_label() {
    local path=${1//\\//}
    path=${path#"$root"/}
    printf '%s' "$path"
}

documents() {
    local path

    if [ "$#" -gt 0 ]; then
        for path in "$@"; do
            [ -f "$path" ] && printf '%s\n' "$path"
        done
        return 0
    fi

    git ls-files -z --cached --others --exclude-standard -- '*.md' '*.markdown' \
        | while IFS= read -r -d '' path; do
            [ -f "$path" ] && printf '%s\n' "$path"
        done
}

sanitize_fences() {
    awk '
        {
            sub(/\r$/, "")
            if (match($0, /^[ \t]{0,3}(```+|~~~+)/)) {
                marker = substr($0, RSTART, RLENGTH)
                sub(/^[ \t]*/, "", marker)
                character = substr(marker, 1, 1)
                length_marker = length(marker)
                if (!open) {
                    open = 1
                    open_character = character
                    open_length = length_marker
                    print ""
                    next
                }
                if (character == open_character && length_marker >= open_length) {
                    open = 0
                    print ""
                    next
                }
            }
            if (open) {
                print ""
                next
            }
            print
        }
    ' "$1"
}

sanitize_document() {
    sanitize_fences "$1" | awk '
        {
            line = $0
            if (line ~ /^[ \t]{4,}/) {
                print ""
                next
            }
            gsub(/`[^`]*`/, "", line)
            gsub(/<!--.*-->/, "", line)
            print line
        }
    '
}

links_in_document() {
    sanitize_document "$1" | awk '
        {
            line = $0
            while (match(line, /!?\[[^]]*\]\([^)]+\)/)) {
                token = substr(line, RSTART, RLENGTH)
                start = index(token, "](") + 2
                target = substr(token, start, length(token) - start)
                print NR "\t" target
                line = substr(line, RSTART + RLENGTH)
            }
        }
    '
}

anchors_in_document() {
    sanitize_document "$1" | awk '
        function trim(value) {
            sub(/^[ \t]+/, "", value)
            sub(/[ \t]+$/, "", value)
            return value
        }
        function slug(value,    i, character, result) {
            sub(/[ \t]+#+[ \t]*$/, "", value)
            gsub(/<[^>]*>/, "", value)
            gsub(/!?\[([^]]*)\]\([^)]*\)/, "\\1", value)
            gsub(/[*_~]/, "", value)
            value = tolower(value)
            result = ""
            for (i = 1; i <= length(value); i++) {
                character = substr(value, i, 1)
                if (character == " ") {
                    result = result "-"
                } else if (character ~ /[a-z0-9_-]/) {
                    result = result character
                }
            }
            return result
        }
        /^[ \t]{0,3}#{1,6}[ \t]+/ {
            heading = $0
            sub(/^[ \t]{0,3}#{1,6}[ \t]+/, "", heading)
            heading = slug(trim(heading))
            count[heading]++
            if (count[heading] > 1) {
                print heading "-" (count[heading] - 1)
            } else {
                print heading
            }
        }
    '
}

table_errors() {
    sanitize_fences "$1" | awk '
        { lines[NR] = $0 }
        function cells(value,    count) {
            gsub(/\\\|/, "", value)
            sub(/^[ \t]*\|/, "", value)
            sub(/\|[ \t]*$/, "", value)
            count = split(value, parts, "|")
            return count
        }
        END {
            for (i = 2; i <= NR; i++) {
                if (lines[i] ~ /^[ \t]{4,}/) {
                    continue
                }
                if (lines[i] !~ /^[ \t]*\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)+\|?[ \t]*$/) {
                    continue
                }
                expected = cells(lines[i - 1])
                j = i + 1
                while (j <= NR && lines[j] ~ /\|/ && lines[j] !~ /^[ \t]*$/) {
                    if (lines[j] ~ /^[ \t]{4,}/) {
                        break
                    }
                    actual = cells(lines[j])
                    if (actual != expected) {
                        print j "\t" expected "\t" actual
                    }
                    j++
                }
            }
        }
    '
}

fence_errors() {
    awk '
        {
            sub(/\r$/, "")
            if (match($0, /^[ \t]{0,3}(```+|~~~+)/)) {
                marker = substr($0, RSTART, RLENGTH)
                sub(/^[ \t]*/, "", marker)
                character = substr(marker, 1, 1)
                length_marker = length(marker)
                if (!open) {
                    open = 1
                    open_character = character
                    open_length = length_marker
                } else if (character == open_character && length_marker >= open_length) {
                    open = 0
                }
            }
        }
        END {
            if (open) {
                print NR
            }
        }
    ' "$1"
}

check_fragment() {
    local document=$1
    local line=$2
    local target_file=$3
    local fragment=$4
    local anchors

    [ -n "$fragment" ] || return 0
    case "$target_file" in
        *.md|*.markdown) ;;
        *) return 0 ;;
    esac

    fragment=${fragment//%20/-}
    anchors="$(anchors_in_document "$target_file")"
    if ! printf '%s\n' "$anchors" | grep -Fxq -- "$fragment"; then
        report "fragment" "$(safe_label "$document")" "$line"
    fi
}

check_link() {
    local document=$1
    local line=$2
    local target=$3
    local path
    local fragment
    local directory
    local name
    local resolved
    local relative

    target=${target#"${target%%[![:space:]]*}"}
    target=${target%"${target##*[![:space:]]}"}
    target=${target#<}
    target=${target%>}
    target=${target%%[[:space:]]*}
    [ -n "$target" ] || return 0

    case "$target" in
        '#'*)
            check_fragment "$document" "$line" "$document" "${target#\#}"
            return 0
            ;;
        http://*|https://*|mailto:*|tel:*|data:*|//*)
            return 0
            ;;
        file:[//]/*|/*|[A-Za-z]:[\\/]*|\\\\*)
            report "local-absolute-path" "$(safe_label "$document")" "$line"
            return 0
            ;;
    esac

    path=${target%%#*}
    fragment=""
    if [ "$path" != "$target" ]; then
        fragment=${target#*#}
    fi
    path=${path%%\?*}
    [ -n "$path" ] || return 0

    directory=$(dirname "$path")
    name=$(basename "$path")
    if [ "$name" = "." ] || [ "$name" = "/" ]; then
        name=""
    fi

    if ! resolved=$(
        cd "$(dirname "$document")" 2>/dev/null \
            && cd "$directory" 2>/dev/null \
            && printf '%s/%s' "$(pwd -P)" "$name"
    ); then
        report "relative-link" "$(safe_label "$document")" "$line"
        return 0
    fi
    resolved=${resolved%/}

    if [ ! -e "$resolved" ]; then
        report "relative-link" "$(safe_label "$document")" "$line"
        return 0
    fi

    relative=${resolved#"$root"/}
    if [ "$relative" = "$resolved" ]; then
        report "outside-repository" "$(safe_label "$document")" "$line"
        return 0
    fi

    if git check-ignore --quiet --no-index -- "$relative"; then
        report "ignored-target" "$(safe_label "$document")" "$line"
        return 0
    fi

    if [ -f "$resolved" ]; then
        check_fragment "$document" "$line" "$resolved" "$fragment"
    fi
}

check_document() {
    local document=$1
    local line
    local target
    local count
    local expected

    while IFS=$'\t' read -r line target; do
        [ -n "$line" ] && check_link "$document" "$line" "$target"
    done < <(links_in_document "$document")

    while IFS=$'\t' read -r line expected count; do
        [ -n "$line" ] || continue
        report "table-columns" "$(safe_label "$document")" "$line"
    done < <(table_errors "$document")

    line=$(fence_errors "$document")
    if [ -n "$line" ]; then
        report "unclosed-fence" "$(safe_label "$document")" "$line"
    fi
}

main() {
    local docs=()
    local document
    local result=0
    local code=0

    if [ "${1:-}" = "--files" ]; then
        shift
        if [ "$#" -eq 0 ]; then
            echo "usage: $0 [--files <path>...]" >&2
            exit 2
        fi
        while IFS= read -r document; do
            docs+=("$document")
        done < <(documents "$@")
    else
        while IFS= read -r document; do
            docs+=("$document")
        done < <(documents)
    fi

    if [ "${#docs[@]}" -eq 0 ]; then
        echo "documentation: no Markdown files found" >&2
        exit 2
    fi

    for document in "${docs[@]}"; do
        check_document "$document"
    done

    set +e
    bash "$root/scripts/check-public-content.sh" --files "${docs[@]}"
    code=$?
    set -e
    if [ "$code" -eq 1 ]; then
        result=1
    elif [ "$code" -ne 0 ]; then
        echo "documentation: public-content validation could not complete" >&2
        exit 2
    fi

    if [ "$rule_failed" -eq 1 ]; then
        result=1
    fi

    if [ "$result" -eq 1 ]; then
        echo "documentation: validation failed" >&2
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
