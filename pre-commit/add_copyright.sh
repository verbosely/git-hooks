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
    (( ${copyright_line} ))
}

update_copyright() {
    (( PRESENT - ${old_year} )) && {
        check_diff "${1}"
        [[ $(( PRESENT - ${old_year} )) -eq 1 ]] && {
            sed --quiet "${copyright_line}p" ${1} |
            grep --perl-regexp --quiet '^.*\d{4}\s*-\s*\d{4}(?!.*\d{4})' &&
            sed --quiet --regexp-extended "
                ${copyright_line}s/(.*)[[:digit:]]{4}/\1${PRESENT}/p" ${1} ||
            sed --quiet --regexp-extended "
                ${copyright_line}s/(.*)([[:digit:]]{4})/\1\2-${PRESENT}/p" ${1}
        } || {
            sed --quiet --regexp-extended "
                ${copyright_line}s/(.*[[:digit:]]{4})/\1, ${PRESENT}/p" ${1}
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
    sed --regexp-extended "
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

extract_hunk() {
    hunks+=($(
        git diff --output-indicator-new='+' --output-indicator-old='-' \
            --output-indicator-context=' ' ${1} |
        sed --quiet --regexp-extended "
            /${HUNK_HEADER_REGEX}/{h
                :a
                    n ; /${HUNK_HEADER_REGEX}/{
                        x ; /\+${COPYRIGHT_REGEX}/I{p ; q} ; g ; ba} ;
                    H ; \${x ; /\+${COPYRIGHT_REGEX}/I{p ; q}} ; ba}"))
}

extract_diff_header() {
    diff_headers+=($(
        git diff ${1} |
        sed --quiet --regexp-extended "
            1,/${HUNK_HEADER_REGEX}/{/${HUNK_HEADER_REGEX}/!p}"))
}

extract_new_count() {
    new_counts+=($(
        echo -e "${1}" |
        sed --quiet --regexp-extended "1s/.+[^[:digit:]]([[:digit:]]+).+/\1/p"))
}

stage_changes() {
    local -a hunks=() diff_headers=() new_counts=()
    (( ${#no_diff_updated[*]} + ${#no_diff_added[*]} )) &&
        git add "${no_diff_updated[@]}" "${no_diff_added[@]}"
    for file in "${diff_updated[@]}" "${diff_added[@]}"; do
        extract_hunk "${file}"
        extract_diff_header "${file}"
    done
    for hunk in "${hunks[@]}"; do
        extract_new_count "${hunk}"
    done
}

print_results() {
    local msg
    ! (( ${#non_text[*]} )) || {
        msg="The following files aren't of text MIME type "
        msg+="and were thus skipped:\n"
        print_message 0 "yellow" "${msg}${non_text[*]}"
    }
    ! (( ${#unrecognized_text[*]} )) || {
        msg="The following files aren't recognized text files "
        msg+="and were thus skipped:\n"
        print_message 0 "yellow" "${msg}${unrecognized_text[*]}"
    }
    #! (( ${#updated[*]} )) || {
    #    msg="Copyrights were updated in the following files:\n"
    #    print_message 0 "green" "${msg}${updated[*]}"
    #}
    #! (( ${#added[*]} )) || {
    #    msg="Copyrights were added to the following files:\n"
    #    print_message 0 "green" "${msg}${added[*]}"
    #}
}

main() {
    . shared/checks.sh ; check_binaries $(needed_binaries)
    define_constants ; unset define_constants
    local -a non_text=() unrecognized_text=() staged=() unstaged=()
    local -a no_diff_updated=() no_diff_added=() diff_added=() diff_updated=()
    local -i copyright_line old_year
    local file_type
    for (( i=0; ${#STAGED_FILES[*]} - i; i+=2 )); do
        ! [[ ${STAGED_FILES[i]} =~ R|M|A ]] || {
            [[ ${STAGED_FILES[i]} =~ R ]] && i+=1
            is_not_text_type ${STAGED_FILES[@]:i+1:1} || {
                copyright_exists ${STAGED_FILES[@]:i+1:1} && {
                    update_copyright ${STAGED_FILES[@]:i+1:1} ; continue ; }
                is_not_recognized_text_type ${STAGED_FILES[@]:i+1:1} ||
                add_new_copyright ${STAGED_FILES[@]:i:2}
            }
        }
    done
    #stage_changes
    print_results
}
main
