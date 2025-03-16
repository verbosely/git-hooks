#!/usr/bin/env bash

needed_binaries() {
    echo "file git grep sed vim"
}

define_constants() {
    declare -gr COPYRIGHT_OWNER="Verbosely"
    declare -agr STAGED_FILES=($(git diff --diff-filter="ARM" \
        --name-status --cached))
    declare -gir PRESENT=$(date +%Y)
    local temp="^(?=.*copyright)(?=.*${COPYRIGHT_OWNER})(?=.*\d{4}).*\K\d{4}"
    declare -gr COPYRIGHT_REGEX="${temp}"
    declare -gr SHEBANG_REGEX='^#!\s*(/(\w|\.)+)+'
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

is_not_text_type() {
    ! [[ $(file --brief --mime-type ${1}) =~ text/ ]] &&
        non_text+=(${1})
}

check_copyright() {
    local -ar LINE_YEAR=($(
        grep --ignore-case --line-number --max-count=1 \
                --only-matching --perl-regexp ${COPYRIGHT_REGEX} ${1} \
            | cut --delimiter=: --fields=1,2 --output-delimiter=' '))
    (( ${#LINE_YEAR[@]} )) && update_copyright ${1}
}

update_copyright() {
    ! (( PRESENT - ${LINE_YEAR[-1]} )) || {
        updated+=(${1})
        [[ $(( PRESENT - ${LINE_YEAR[-1]} )) -eq 1 ]] && {
            sed --quiet "${LINE_YEAR[0]}p" ${1} \
                | grep --perl-regexp --quiet \
                    '^.*\d{4}\s*-\s*\d{4}(?!.*\d{4})' &&
            sed --quiet --regexp-extended \
                "${LINE_YEAR[0]}s/(.*)[[:digit:]]{4}/\1${PRESENT}/p" ${1} ||
            sed --quiet --regexp-extended \
                "${LINE_YEAR[0]}s/(.*)([[:digit:]]{4})/\1\2-${PRESENT}/p" \
                ${1}
        } || {
            sed --quiet --regexp-extended \
                "${LINE_YEAR[0]}s/(.*[[:digit:]]{4})/\1, ${PRESENT}/p" ${1}
        }
    }
}

years_to_string() {
    local -i consecutive=1
    local -i temp
    for (( j=2; $# - j + 1; j++ )); do
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

check_text_type() {
    local -r FILE_TYPE=$(
        vim -es -c "filetype detect | set filetype? | quit" ${!#} \
            | cut --delimiter== --fields=2)
    [ -z "$FILE_TYPE" ] || [ -z "${LANGUAGE_COMMENT_MAP["$FILE_TYPE"]+key}" ] &&
        unrecognized_text+=(${!#}) || { add_copyright "$@"; }
}

add_copyright() {
    added+=(${!#})
    local -a all_unique_years=($(
        git log --date=format:"%Y" --format=format:"%ad%n%cd" -- "$@" \
            | cat - <(echo -e "\n${PRESENT}") | sort --numeric-sort --unique))
    local years_str="${all_unique_years[0]}"
    years_to_string ${all_unique_years[@]} ; unset all_unique_years
    local line1="${LANGUAGE_COMMENT_MAP["${FILE_TYPE}"]} Copyright © "
    line1+="${years_str} ${COPYRIGHT_OWNER}."
    local line2="${LANGUAGE_COMMENT_MAP["${FILE_TYPE}"]} All rights reserved."
    local -ar COPYRIGHT=("${line1}" "${line2}") ; unset line1 line2
    sed --quiet '1p' ${!#} | grep --perl-regexp --quiet "${SHEBANG_REGEX}" && {
        sed --quiet '2p' ${!#} | grep --perl-regexp --quiet '^\s*$' &&
            sed "1a \\\n${COPYRIGHT[0]}\n${COPYRIGHT[1]}" ${!#} ||
            sed "1a \\\n${COPYRIGHT[0]}\n${COPYRIGHT[1]}\n" ${!#}
    } || {
        sed --quiet '1p' ${!#} | grep --perl-regexp --quiet '^\s*$' &&
            sed "1i ${COPYRIGHT[0]}\n${COPYRIGHT[1]}" ${!#} ||
            sed "1i ${COPYRIGHT[0]}\n${COPYRIGHT[1]}\n" ${!#}
    }
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
    ! (( ${#updated} )) || {
        msg="Copyrights were updated in the following files:\n"
        print_message 0 "green" "${msg}${updated[*]}"
    }
    ! (( ${#added} )) || {
        msg="Copyrights were added to the following files:\n"
        print_message 0 "green" "${msg}${added[*]}"
    }
}

main() {
    . shared/checks.sh; check_binaries $(needed_binaries)
    define_constants
    local -a non_text=() unrecognized_text=() updated=() added=()
    for (( i=0; ${#STAGED_FILES[*]} - i; i+=2 )); do
        ! [[ ${STAGED_FILES[i]} =~ R|M|A ]] || {
            [[ ${STAGED_FILES[i]} =~ R ]] && i+=1
            is_not_text_type ${STAGED_FILES[@]:i+1:1} || {
                check_copyright ${STAGED_FILES[@]:i+1:1} ||
                check_text_type ${STAGED_FILES[@]:i:2}
            }
        }
    done
    print_results
}
main
