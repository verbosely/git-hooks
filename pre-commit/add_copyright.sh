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

add_copyright() {
    local -a all_unique_years=($(
        git log --date=format:"%Y" --format=format:"%ad%n%cd" -- ${1} \
            | cat - <(echo -e "\n${PRESENT}") | sort --numeric-sort --unique))
    local years_str="${all_unique_years[0]}"
    years_to_string ${all_unique_years[@]} ; unset all_unique_years
    local -ar COPYRIGHT=(
        "Copyright © ${years_str} ${COPYRIGHT_OWNER}." "All rights reserved.")
    local -r INTERPRETER=($(sed --quiet '1p' ${!#} \
        | grep --only-matching --perl-regexp ${SHEBANG_REGEX}))
    sed --quiet '1p' ${!#} | grep --perl-regexp --quiet '^\s*$'
    local -ir BLANK_FIRST_LINE=$?
    sed --quiet '2p' ${!#} | grep --perl-regexp --quiet '^\s*$'
    local -ir BLANK_SECOND_LINE=$?
    [[ ${INTERPRETER} =~ ${INTERPRETERS_REGEX} ]] && {
        (( BLANK_SECOND_LINE )) &&
            sed "1a \\\n# ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}\n" ${!#} ||
            sed "1a \\\n# ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}" ${!#}
    } || {
        local -r EXTENSION=${!###*.}
        [[ ${EXTENSION} =~ ${INTERPRETERS_REGEX} ]] && {
            (( BLANK_FIRST_LINE )) &&
                sed "1i # ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}\n" ${!#} ||
                sed "1i # ${COPYRIGHT[0]}\n# ${COPYRIGHT[1]}" ${!#}
        }
    } || echo -e ${!#} isn\'t a recognized text file. \
        The copyright for ${COPYRIGHT_OWNER} wasn\'t added.

}

main() {
    define_constants
    for (( i=0; ${#STAGED_FILES[*]} - i; i+=2 )); do
        [[ ${STAGED_FILES[i]} =~ R ]] && {
            update_copyright ${STAGED_FILES[i + 2]} ||
            add_copyright ${STAGED_FILES[i + 1]} ${STAGED_FILES[i + 2]}
            i+=1
        } || {
            update_copyright ${STAGED_FILES[i + 1]} ||
            add_copyright ${STAGED_FILES[i + 1]}
        }
    done
}
main
