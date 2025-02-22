#!/usr/bin/env bash

update_copyright() {
    local -i present=$(date +%Y)
    local copyright_regex='^(?=.*copyright)(?=.*verbosely)(?=.*\d{4}).*\K\d{4}'
    local -a line_year=($(
        grep --ignore-case --line-number --max-count=1 \
                --only-matching --perl-regexp ${copyright_regex} ${1} \
            | cut --delimiter=: --fields=1,2 --output-delimiter=' '))
    (( ${#line_year[@]} )) && {
        ! (( present - ${line_year[-1]} )) || {
            [[ $(( present - ${line_year[-1]} )) -eq 1 ]] && {
                sed --quiet "${line_year[0]}p" ${1} \
                    | grep --perl-regexp --quiet \
                        '^.*\d{4}\s*-\s*\d{4}(?!.*\d{4})' &&
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*)[[:digit:]]{4}/\1${present}/p" ${1} ||
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*)([[:digit:]]{4})/\1\2-${present}/p" \
                    ${1}
            } || {
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*[[:digit:]]{4})/\1, ${present}/p" ${1}
            }
        }
    }
}

add_copyright() {
    local -i present=20255
    local shebang_regex='^(?=#!\s*(/[a-z]+)+).+'
    shebang_regex+='(\s+\K[a-z]+(?=(\s+|$))|/\K[a-z]+)' 
    local interpreters_regex
    local -a interpreters=(sh zsh csh ksh tcsh bash fish dash xonsh)
    local -a copyright=(
        "Copyright © ${present} Verbosely." "All rights reserved.")
    for (( j=0; ${#interpreters[*]} - j; j++ )); do
        (( j )) && interpreters_regex+="|^${interpreters[j]}$" ||
            interpreters_regex="^${interpreters[j]}$"
    done
    local interpreter=($(sed --quiet '1p' ${1} \
        | grep --only-matching --perl-regexp ${shebang_regex}))
    sed --quiet '1p' ${1} | grep --perl-regexp --quiet '^\s*$'
    local -i blank_first_line=$?
    sed --quiet '2p' ${1} | grep --perl-regexp --quiet '^\s*$'
    local -i blank_second_line=$?
    [[ ${interpreter} =~ ${interpreters_regex} ]] && {
        (( blank_second_line )) &&
            sed "1a \\\n# ${copyright[0]}\n# ${copyright[1]}\n" ${1} ||
            sed "1a \\\n# ${copyright[0]}\n# ${copyright[1]}" ${1}
    } || {
        local ext=${1##*.}
        [[ ${ext} =~ ${interpreters_regex} ]] && {
            (( blank_first_line )) &&
                sed "1i # ${copyright[0]}\n# ${copyright[1]}\n" ${1} ||
                sed "1i # ${copyright[0]}\n# ${copyright[1]}" ${1}
        }
    }
}

main() {
    local staged_files=($(git diff --name-status --no-renames --cached))
    for (( i=0; ${#staged_files[*]} - i; i+=2 )); do
        ! [[ ${staged_files[i]} =~ M|A ]] || {
            update_copyright ${staged_files[i + 1]} ||
            add_copyright ${staged_files[i + 1]}
        }
    done
}
main
