# Copyright © 2025 Verbosely.
# All rights reserved.

params_to_csv_string() {
    local -i i ; local str="$1"
    for (( i=2; $# + 1 - i; i++ )); do
        str+=", ${!i}"
    done
    echo "${str}"
}
