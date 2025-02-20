#!/usr/bin/env bash

main() {
    file='add_copyright.sh'
    local -i present=$(date +%Y)
    local -a line_year=($(
        grep --ignore-case --line-number --max-count=1 \
                --only-matching --perl-regexp \
                '^(?=.*copyright)(?=.*verbosely)(?=.*\d{4}).*\K\d{4}' ${file} \
            | cut --delimiter=: --fields=1,2 --output-delimiter=' '))
    (( ${#line_year[@]} )) && {
        ! (( present - ${line_year[-1]} )) || {
            [[ $(( present - ${line_year[-1]} )) -eq 1 ]] && {
                sed --quiet "${line_year[0]}p" ${file} \
                    | grep --perl-regexp --quiet \
                        '^.*\d{4}\s*-\s*\d{4}(?!.*\d{4})' &&
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*)[[:digit:]]{4}/\1${present}/p" \
                    ${file} ||
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*)([[:digit:]]{4})/\1\2-${present}/p" \
                    ${file}
            } || {
                sed --quiet --regexp-extended \
                    "${line_year[0]}s/(.*[[:digit:]]{4})/\1, ${present}/p" \
                    ${file}
            }
        }
    }
}
main
