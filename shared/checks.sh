. $(dirname ${BASH_SOURCE[0]})/notifications.sh

check_binaries() {
    local -a missing_binaries=()
    local -ar NEEDED_BINARIES=($*)
    which which &> /dev/null || terminate "which"
    for binary in "${NEEDED_BINARIES[@]}"; do
        which ${binary} &> /dev/null || missing_binaries+=($binary)
    done
    ! (( ${#missing_binaries[*]} )) || terminate "${missing_binaries[*]}"
}
