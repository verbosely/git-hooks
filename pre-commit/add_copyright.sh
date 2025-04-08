#!/usr/bin/env bash

needed_binaries() {
    echo "file git grep sed vim"
}

define_constants() {
    LC_ALL=en_US.UTF-8
    local temp
    declare -gr COPYRIGHT_OWNER="Verbosely"
    declare -agr STAGED_FILES=($(git diff --diff-filter="ARM" \
        --name-status --cached))
    declare -gir PRESENT=$(date +%Y)
    temp="([[:punct:]]|[[:space:]])*copyright([[:space:]]*(\xc2\xa9|\(c\))"
    temp+="[[:space:]]*|[[:space:]]+)([[:digit:]]{4}(,[[:space:]]*|"
    temp+="[[:space:]]+)|[[:digit:]]{4}[[:space:]]*-[[:space:]]*[[:digit:]]{4}"
    temp+="(,[[:space:]]*|[[:space:]]+))+${COPYRIGHT_OWNER}"
    temp+="([[:punct:]]|[[:space:]])*"
    declare -gr COPYRIGHT_REGEX="${temp}"
    declare -gr SHEBANG_REGEX='#![[:space:]]*(\/([[:alnum:]]|[._-])+)+'
    temp='@@ -[[:digit:]]+(,[[:digit:]]+)? \+[[:digit:]]+(,[[:digit:]]+)? @@'
    declare -gr HUNK_HEADER_REGEX="${temp}"
    declare -gr COPYRIGHT_LINE_2="All rights reserved."
    temp="([[:punct:]]|[[:space:]])*${COPYRIGHT_LINE_2}"
    temp+="([[:punct:]]|[[:space:]])*$"
    declare -gr COPYRIGHT_LINE_2_REGEX="${temp}"
    declare -Agr LANGUAGE_COMMENT_MAP=(
        ["sh"]="#"
        ["zsh"]="#"
        ["csh"]="#"
        ["tcsh"]="#"
        ["fish"]="#"
        ["xonsh"]="#"
        ["dash"]="#"
        ["bash"]="#"
        ["ksh"]="#"
        ["python"]="#"
        ["conf"]="#"
        ["nginx"]="#"
        ["ruby"]="#"
        ["go"]="//"
        ["javascript"]="//"
        ["typescript"]="//"
    )
    unset define_constants
}

check_diff() {
    case "${FUNCNAME[1]}" in
        'update_copyright')
            [[ -z "$(git diff --name-only -- "${1}")" ]] &&
                no_diff_updated+=(${1}) || diff_updated+=(${1})
        ;;
        'add_new_copyright')
            [[ -z "$(git diff --name-only -- "${1}")" ]] &&
                no_diff_added+=(${1}) || diff_added+=(${1})
        ;;
    esac
}

is_not_text_type() {
    ! [[ $(file --brief --mime-type ${1}) =~ text/ ]] &&
        non_text+=(${1})
}

copyright_exists() {
    read copyright_line old_year < <(
        sed --quiet --regexp-extended "
            /^${COPYRIGHT_REGEX}$/I{= ; s/.*([[:digit:]]{4}).*/\1/p ; q}" ${1} |
        paste --delimiters=' ' --serial)
    (( copyright_line ))
}

update_copyright() {
    (( PRESENT - old_year )) && {
        check_diff "${1}"
        [[ $(( PRESENT - old_year )) -eq 1 ]] && {
            sed --quiet "${copyright_line}p" ${1} |
            grep --perl-regexp --quiet '^.*\d{4}\s*-\s*\d{4}(?!.*\d{4})' &&
            sed --in-place --regexp-extended "
                ${copyright_line}s/(.*)[[:digit:]]{4}/\1${PRESENT}/" ${1} ||
            sed --in-place --regexp-extended "
                ${copyright_line}s/(.*)([[:digit:]]{4})/\1\2-${PRESENT}/" ${1}
        } || {
            sed --in-place --regexp-extended "
                ${copyright_line}s/(.*[[:digit:]]{4})/\1, ${PRESENT}/" ${1}
        }
    }
}

years_to_string() {
    local -i consecutive=1
    local -i temp
    for (( j=2 ; $# - j + 1 ; j++ )); do
        temp=$(( j - 1 ))
        [[ $(( ${!j} - ${!temp} )) -ne 1 ]] && {
            consecutive=1
            years_str+=", ${!j}"
        } || {
            (( consecutive )) && years_str+="-${!j}" ||
                years_str="${years_str%-*}-${!j}"
            consecutive=0
        }
    done
}

is_not_recognized_text_type() {
    file_type=$(
        vim -es -c "filetype detect | set filetype? | quit" ${1} |
            cut --delimiter== --fields=2)
    [ -z "$file_type" ] || [ -z "${LANGUAGE_COMMENT_MAP["$file_type"]+key}" ] &&
        unrecognized_text+=(${1})
}

prepare_copyright() {
    local -a all_unique_years=($(
        git log --date=format:"%Y" --format=format:"%ad%n%cd" -- "$@" |
            cat - <(echo -e "\n${PRESENT}") | sort --numeric-sort --unique))
    local years_str="${all_unique_years[0]}"
    years_to_string ${all_unique_years[@]} ; unset all_unique_years
    local line1="${LANGUAGE_COMMENT_MAP["${file_type}"]} Copyright © "
    line1+="${years_str} ${COPYRIGHT_OWNER}."
    local line2="${LANGUAGE_COMMENT_MAP["${file_type}"]} ${COPYRIGHT_LINE_2}"
    copyright+=("${line1}" "${line2}") ; unset line1 line2
}

add_new_copyright() {
    local -a copyright=()
    prepare_copyright "$@"
    check_diff "${!#}"
    sed --in-place --regexp-extended "
        1{/^${SHEBANG_REGEX}/{\${
                    \$a\
                        \\\n${copyright[0]}\n${copyright[1]}
                    b} ;
                n ;
                2{/^[[:space:]]*$/{
                        2i\
                            \\\n${copyright[0]}\n${copyright[1]}
                        b} ;
                    2i\
                        \\\n${copyright[0]}\n${copyright[1]}\n
                    b}} ;
            /^[[:space:]]*$/{
                1i\
                    ${copyright[0]}\n${copyright[1]}
                b} ;
            1i\
                    ${copyright[0]}\n${copyright[1]}\n
            b} ;" ${!#}
}

extract_hunks() {
    for file in "${diff_updated[@]}" "${diff_added[@]}"; do
        hunks+=("$(
            git diff --output-indicator-new='+' --output-indicator-old='-' \
                --output-indicator-context=' ' "${file}" |
            sed --quiet --regexp-extended "
                /${HUNK_HEADER_REGEX}/{h
                    :a
                        n ; /${HUNK_HEADER_REGEX}/{
                            x ; /\+${COPYRIGHT_REGEX}/I{p ; q} ; g ; ba} ;
                        H ; \${x ; /\+${COPYRIGHT_REGEX}/I{p ; q}} ; ba}")")
    done
}

extract_diff_headers() {
    for file in "${diff_updated[@]}" "${diff_added[@]}"; do
        diff_headers+=("$(
            git diff ${file} |
            sed --quiet --regexp-extended "
                1,/${HUNK_HEADER_REGEX}/{/${HUNK_HEADER_REGEX}/!p}")")
    done
}

extract_new_counts() {
    for hunk in "${hunks[@]}"; do
        new_counts+=("$(
            echo -e "${hunk}" |
            sed --quiet --regexp-extended "
                1s/.+[^[:digit:]]([[:digit:]]+).+/\1/p")")
    done
}

revise_hunk_for_add() {
    revised_hunks_for_adds+=("$(
        echo -e "${1}" |
        sed --quiet --regexp-extended "
            /^(\+|-| )${SHEBANG_REGEX}/{p ; b}
            /^\+${COPYRIGHT_REGEX}$/I{
                p ; \${ba} ; n ; /^\+${COPYRIGHT_LINE_2_REGEX}/I{
                    p ; \${ba} ; n ; /^\+[[:space:]]*$/{p ; ba} ; bb} ; bb}
            /^-/{x ; /./{x ; H ; b} ; x ; h ; b}
            p ; b
            :a
                x ; /./p ; bc
            :b
                x ; /./p ; x ; p
            :c
                n ; p ; bc")")
}

find_preexistent_changes_for_add() {
    local -a preexistent_changes
    read -a preexistent_changes < <(echo -e "${1}" |
        nl --number-format=rn --number-separator=: - |
        sed --quiet --regexp-extended "
            /^[[:space:]]+[[:digit:]]+:\+[[:space:]]*$/{\${ba} ; h ; n}
            /^[[:space:]]+[[:digit:]]+:\+${COPYRIGHT_REGEX}$/I{
                n ; /^[[:space:]]+[[:digit:]]+:\+${COPYRIGHT_LINE_2_REGEX}/I{
                    n ; /^[[:space:]]+[[:digit:]]+:\+[[:space:]]*$/{
                        s/.*// ; x ; d}
                    x ; s/.*// ; x}}
            x ; /^$/x
            :a
                /^[[:space:]]+[[:digit:]]+:\+/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/n/p}
                /^[[:space:]]+[[:digit:]]+:-/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/o/p}
                s/.*// ; x ; /./ba" |
        paste --delimiters=' ' --serial)
    preexistent_changes_for_adds+=("${preexistent_changes[*]}")
}

revise_hunk_for_update() {
    revised_hunks_for_updates+=("$(
        echo -e "${1}" |
        sed --quiet --regexp-extended "
            /^-${COPYRIGHT_REGEX}$/I{x ; /./{p ; s/.*//} ; x ; p ; ba}
            /^\+${COPYRIGHT_REGEX}$/Ibd
            /^(\+|-)${SHEBANG_REGEX}/bc
            /^(\+|-)/{\${bc} ; x ; /./{x ; H ; b} ; x ; h ; b}
            bc
            :a
                n
                /^\+${COPYRIGHT_REGEX}$/Ibd
                /^(\+|-)/{\${bc} ; x ; /./{x ; H ; ba} ; x ; h ; ba}
                bc
            :b
                n ; p ; bb
            :c
                x ; /./{p ; s/.*//} ; x ; p ; b
            :d
                p ; x ; /./p ; bb")")
}

find_preexistent_changes_for_update() {
    local -a preexistent_changes
    read -a preexistent_changes < <(echo -e "${1}" |
        nl --number-format=rn --number-separator=: - |
        sed --quiet --regexp-extended "
            /^[[:space:]]+[[:digit:]]+:-${COPYRIGHT_REGEX}$/I{h ; n}
            /^[[:space:]]+[[:digit:]]+:\+${COPYRIGHT_REGEX}$/Ibb
            x ; /^$/x
            :a
                /^[[:space:]]+[[:digit:]]+:\+/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/n/p}
                /^[[:space:]]+[[:digit:]]+:-/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/o/p}
                s/.*// ; x ; /./ba ; b
            :b
                n
                /^[[:space:]]+[[:digit:]]+:\+/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/n/p}
                /^[[:space:]]+[[:digit:]]+:-/{
                    s/^[[:space:]]+([[:digit:]]+).*/\1/p ; s/.*/o/p}
                bb" |
        paste --delimiters=' ' --serial)
    preexistent_changes_for_updates+=("${preexistent_changes[*]}")
}

process_hunks_for_adds() {
    for hunk in "${hunks[@]:${#diff_updated[*]}}"; do
        revise_hunk_for_add "${hunk}"
    done
    for revised_hunk in "${revised_hunks_for_adds[@]}"; do
        find_preexistent_changes_for_add "${revised_hunk}"
    done
}

process_hunks_for_updates() {
    for hunk in "${hunks[@]::${#diff_updated[*]}}"; do
        revise_hunk_for_update "${hunk}"
    done
    for revised_hunk in "${revised_hunks_for_updates[@]}"; do
        find_preexistent_changes_for_update "${revised_hunk}"
    done
}

build_final_hunk_regex() {
    for (( j=0 ; ${#preexistent_changes[*]} - j ; j+=2 )); do
        [ ${preexistent_changes[j+1]} = 'n' ] && {
            hunk_fix_regex+="${preexistent_changes[j]}d;"
            (( new_counts[i]-- )) ; } || {
            hunk_fix_regex+="${preexistent_changes[j]}s/^-(.*)/ \1/;"
            (( new_counts[i]++ )) ; }
    done
}

create_patches() {
    local hunk_fix_regex
    local -a preexistent_changes
    local -ar PREEXISTENT_CHANGES_ALL=("${preexistent_changes_for_updates[@]}"
        "${preexistent_changes_for_adds[@]}")
    local -ar REVISED_HUNKS_ALL=(
        "${revised_hunks_for_updates[@]}" "${revised_hunks_for_adds[@]}")
    for (( i=0 ; ${#PREEXISTENT_CHANGES_ALL[*]} - i ; i++ )); do
        preexistent_changes=(${PREEXISTENT_CHANGES_ALL[i]})
        hunk_fix_regex=""
        build_final_hunk_regex
        (( ${#preexistent_changes[*]} )) &&
            patches+=("${diff_headers[i]}\n$(
                echo -e "${REVISED_HUNKS_ALL[i]}" |
                sed --regexp-extended "
                    1s/(.+[^[:digit:]])[[:digit:]]+(.+)/\1${new_counts[i]}\2/
                    ${hunk_fix_regex}")") ||
            patches+=("${diff_headers[i]}\n${REVISED_HUNKS_ALL[i]}")
    done
}

apply_updated_copyright_patches() {
    for (( i=0 ; ${#diff_updated[*]} - i ; i++ )); do
        echo -e "${patches[i]}" |
                git apply --cached --whitespace=fix - &> /dev/null &&
            diff_successes_updated+=("${diff_updated[i]}") ||
            diff_failures_updated+=("${diff_updated[i]}")
    done
}

apply_new_copyright_patches() {
    for (( i=0 ; ${#diff_added[*]} - i ; i++ )); do
        echo -e "${patches[@]:${#diff_updated[*]} + i:1}" |
                git apply --cached --whitespace=fix - &> /dev/null &&
            diff_successes_added+=("${diff_added[i]}") ||
            diff_failures_added+=("${diff_added[i]}")
    done
}

stage_changes() {
    local -a hunks=() diff_headers=() new_counts=() patches=() \
        revised_hunks_for_updates=() revised_hunks_for_adds=() \
        preexistent_changes_for_updates=() preexistent_changes_for_adds=()
    (( ${#no_diff_updated[*]} + ${#no_diff_added[*]} )) &&
        git add "${no_diff_updated[@]}" "${no_diff_added[@]}"
    extract_hunks
    extract_diff_headers
    extract_new_counts
    process_hunks_for_adds
    process_hunks_for_updates
    create_patches
    apply_updated_copyright_patches
    apply_new_copyright_patches
}

print_results() {
    local msg
    ! (( ${#non_text[*]} )) || {
        msg="The following files aren't of text MIME type "
        msg+="and were thus skipped:\n${non_text[*]}"
        print_message 0 "yellow" "${msg}"
    }
    ! (( ${#unrecognized_text[*]} )) || {
        msg="The following files aren't recognized text files "
        msg+="and were thus skipped:\n${unrecognized_text[*]}"
        print_message 0 "yellow" "${msg}"
    }
    ! (( ${#no_diff_updated[*]} + ${#diff_successes_updated[*]} )) || {
        local -a update=("${no_diff_updated[@]}" "${diff_successes_updated[@]}")
        msg="Copyrights were updated in the following files "
        msg+="in the working tree and index:\n${update[*]}"
        print_message 0 "green" "${msg}"
    }
    ! (( ${#no_diff_added[*]} + ${#diff_successes_added[*]} )) || {
        local -a add=("${no_diff_added[@]}" "${diff_successes_added[@]}")
        msg="Copyrights were added to the following files "
        msg+="in the working tree and index:\n${add[*]}"
        print_message 0 "green" "${msg}"
    }
    ! (( ${#diff_failures_added[*]} + ${#diff_failures_updated[*]} )) || {
        local -a failures=("${diff_failures_added[@]}"
            "${diff_failures_updated[@]}")
        msg="Failed to apply patches to the index!\nCopyrights were added "
        msg+="or updated in the following files in the working tree only:\n"
        msg+="${failures[*]}"
        print_message 1 "red" "${msg}"
    }
}

main() {
    . shared/checks.sh ; print_hook_lifecycle "start" "${0}"
    check_binaries $(needed_binaries) ; define_constants
    local -a non_text=() unrecognized_text=() no_diff_updated=() diff_added=() \
        no_diff_added=() diff_updated=() diff_failures_updated=() \
        diff_successes_updated=() diff_failures_added=() diff_successes_added=()
    local -i copyright_line old_year
    local file_type
    for (( i=0; ${#STAGED_FILES[*]} - i; i+=2 )); do
        ! [[ ${STAGED_FILES[i]} =~ R|M|A ]] || {
            [[ ${STAGED_FILES[i]} =~ R ]] && (( i++ ))
            is_not_text_type ${STAGED_FILES[@]:i+1:1} || {
                copyright_exists ${STAGED_FILES[@]:i+1:1} && {
                    update_copyright ${STAGED_FILES[@]:i+1:1} ; continue ; }
                is_not_recognized_text_type ${STAGED_FILES[@]:i+1:1} ||
                add_new_copyright ${STAGED_FILES[@]:i:2}
            }
        }
    done
    stage_changes ; unset diff_added diff_updated
    notify
}
main
