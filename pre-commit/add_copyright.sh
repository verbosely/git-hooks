#!/usr/bin/env bash

define_constants() {
    declare -gr COPYRIGHT_OWNER="Verbosely"
    declare -agr STAGED_FILES=($(git diff --diff-filter="ARM" \
        --name-status --cached))
    declare -gir PRESENT=$(date +%Y)
    local temp="^(?=.*copyright)(?=.*${COPYRIGHT_OWNER})(?=.*\d{4}).*\K\d{4}"
    declare -gr COPYRIGHT_REGEX="${temp}"
    temp='^(?=#!\s*(/[a-z]+)+).+(\s+\K[a-z]+(?=(\s+|$))|/\K[a-z]+)' 
    declare -gr SHEBANG_REGEX="${temp}"
    local -ar INTERPRETERS=(sh zsh csh ksh tcsh bash fish dash xonsh)
    for (( j=0; ${#INTERPRETERS[*]} - j; j++ )); do
        (( j )) && temp+="|^${INTERPRETERS[j]}$" || temp="^${INTERPRETERS[j]}$"
    done
    declare -gr INTERPRETERS_REGEX="${temp}"
}

update_copyright() {
    local -ar LINE_YEAR=($(
        grep --ignore-case --line-number --max-count=1 \
                --only-matching --perl-regexp ${COPYRIGHT_REGEX} ${1} \
            | cut --delimiter=: --fields=1,2 --output-delimiter=' '))
    (( ${#LINE_YEAR[@]} )) && {
        ! (( PRESENT - ${LINE_YEAR[-1]} )) || {
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
}

add_copyright() {
    local -ir PRESENT=20255
    local shebang_regex='^(?=#!\s*(/[a-z]+)+).+'
    shebang_regex+='(\s+\K[a-z]+(?=(\s+|$))|/\K[a-z]+)' 
    local -r SHEBANG_REGEX="${shebang_regex}"; unset shebang_regex
    local -ar INTERPRETERS=(sh zsh csh ksh tcsh bash fish dash xonsh)
    local -ar COPYRIGHT=(
        "Copyright © ${PRESENT} ${COPYRIGHT_OWNER}." "All rights reserved.")
    for (( j=0; ${#INTERPRETERS[*]} - j; j++ )); do
        (( j )) && interpreters_regex+="|^${INTERPRETERS[j]}$" ||
            interpreters_regex="^${INTERPRETERS[j]}$"
    done
    local -r INTERPRETERS_REGEX="${interpreters_regex}"
    unset interpreters_regex
    local -r INTERPRETER=($(sed --quiet '1p' ${1} \
        | grep --only-matching --perl-regexp ${SHEBANG_REGEX}))
    sed --quiet '1p' ${1} | grep --perl-regexp --quiet '^\s*$'
    local -ir BLANK_FIRST_LINE=$?
    sed --quiet '2p' ${1} | grep --perl-regexp --quiet '^\s*$'
    local -ir BLANK_SECOND_LINE=$?
    [[ ${INTERPRETER} =~ ${INTERPRETERS_REGEX} ]] && {
        (( BLANK_SECOND_LINE )) &&
            sed "1a \\\n# ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}\n" ${1} ||
            sed "1a \\\n# ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}" ${1}
    } || {
        local -r EXTENSION=${1##*.}
        [[ ${EXTENSION} =~ ${INTERPRETERS_REGEX} ]] && {
            (( BLANK_FIRST_LINE )) &&
                sed "1i # ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}\n" ${1} ||
                sed "1i # ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}" ${1}
        }
    }
}

main() {
    local -ar STAGED_FILES=($(git diff --name-status --no-renames --cached))
    for (( i=0; ${#STAGED_FILES[*]} - i; i+=2 )); do
        ! [[ ${STAGED_FILES[i]} =~ M|A ]] || {
            update_copyright ${STAGED_FILES[i + 1]} ||
            add_copyright ${STAGED_FILES[i + 1]} ||
            echo -e ${STAGED_FILES[i+1]} is not a recognized text file. \
                The copyright for ${COPYRIGHT_OWNER} wasn\'t added.
        }
    done
}
main
