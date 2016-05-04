#!/usr/bin/env bash

set -ue

FIRST_RUN=
ARCH="$HOSTTYPE"
while getopts fn opt; do
    case "$opt" in
        f)  # First run -- don't expect to delete existing logs
            FIRST_RUN="yes"
            ;;

        n)  # Noarch -- don't expect different arch directories.
            ARCH="noarch"
            ;;
    esac
done
readonly FIRST_RUN ARCH
readonly CYGPORT_FILE="$(echo *.cygport)"
readonly PROJECT_NAME=${CYGPORT_FILE%.*}
TAG=$(git describe --exact-match) || {
    echo "Tag the release before saving build logs"
    exit 1
} >&2
readonly TAG
readonly BUILD=${TAG#v}
readonly BUILD_DIR="$(pwd)/${PROJECT_NAME}-${BUILD}.${ARCH}"
readonly SRC_LOG_DIR="${BUILD_DIR}/log"
readonly DST_LOG_DIR="$(pwd)/logs"
readonly CYGCHECK_FILE="cygcheck.out"
readonly COMPULSORY_LOG_FILES="install pkg upload"
readonly OPTIONAL_LOG_FILES="compile check"

if [[ "$ARCH" == "noarch" ]]; then
    cd "$DST_LOG_DIR"
else
    cd "${DST_LOG_DIR}/${ARCH}"
fi

for log in $COMPULSORY_LOG_FILES; do
    log_filename="${PROJECT_NAME}-${BUILD}-${log}.log"
    src_log_path="${BUILD_DIR}/log/${log_filename}"
    [[ -f "$src_log_path" && -r "$src_log_path" ]] || {
        echo "Log file $src_log_path missing!"
        exit 2
    } >&2
    [[ -n $FIRST_RUN ]] || git rm -q "$PROJECT_NAME"-*-"$log".log
    cp "$src_log_path" .
    git add "$log_filename"
done

for log in $OPTIONAL_LOG_FILES; do
    log_filename="${PROJECT_NAME}-${BUILD}-${log}.log"
    src_log_path="${BUILD_DIR}/log/${log_filename}"
    [[ -f "$src_log_path" && -r "$src_log_path" ]] || {
        echo "Skipping missing $src_log_path"
        continue
    } >&2
    [[ -n $FIRST_RUN ]] || git rm -q "$PROJECT_NAME"-*-"$log".log
    cp "$src_log_path" .
    git add "$log_filename"
done

cygcheck -srv >"$CYGCHECK_FILE"
git add "$CYGCHECK_FILE"

if [[ "$ARCH" == "noarch" ]]; then
    git commit -m "$TAG"
else
    git commit -m "$TAG $HOSTTYPE"
fi
git push
