#!/usr/bin/env bash
set -e
log() { echo "$@" >&2; }
vv() { log "($COPS_CWD) $@";"$@"; }
debug() { if [[ -n "${ADEBUG-}" ]];then log "$@";fi }
die_() {
    rc=${1:-1}
    shift
    if [[ -n $@ ]];then
        log $@
    fi
    exit $rc
}
die() { die_ 256 $@; }
export COPS_CWD="${COPS_CWD:-$(pwd)}"
export LOCAL_COPS_ROOT="${LOCAL_COPS_ROOT:-$COPS_CWD/local/corpusops.bootstrap}"
export LOCAL_DCOPS_ROOT="$(dirname  $LOCAL_COPS_ROOT)"
export SYS_COPS_ROOT=${SYS_COPS_ROOT:-/srv/corpusops/corpusops.bootstrap}
export USER_COPS_ROOT="${USER_COPS_ROOT:-$HOME/corpusops/corpusops.bootstrap}"
if [ "x$(whoami)" = "xroot" ];then
    export DEFAULT_COPS_ROOT=$SYS_COPS_ROOT
else
    export DEFAULT_COPS_ROOT=$USER_COPS_ROOT
fi
export COPS_ROOT="${COPS_ROOT:-$DEFAULT_COPS_ROOT}"
export COPS_URL="${COPS_URL:-https://github.com/corpusops/corpusops.bootstrap.git}"
export NO_SHARED_COPS="${NO_SHARED_COPS-${SKIP_COPS_FROM_SYSTEM-}}"
if [[ -n ${SKIP_COPS_SETUP-} ]];then
    die_ 0 "-> Skip corpusops setup"
fi
test_corpusops_present() {
    # in docker images, corpusops has been stripped from some folders
    # testing git isnt enougth
    if [ -e "$LOCAL_COPS_ROOT" ] && \
        [ -e "$LOCAL_COPS_ROOT/roles" ] && \
        [ -e "$LOCAL_COPS_ROOT/bin" ] && \
        [ -e "$LOCAL_COPS_ROOT/hacking" ];then
        return 0
    else
        return 1
    fi
}
# Maintain corpusops fresh and operational
# Using system one
if [[ -z $NO_SHARED_COPS ]] && ! ( test_corpusops_present );then
    if [ ! -e local/corpusops.bootstrap ];then
        log "Reuse corpusops from: $COPS_ROOT"
        if [ ! -e "$LOCAL_DCOPS_ROOT" ];then
            mkdir -pv "$LOCAL_DCOPS_ROOT"
        fi
        ln -sf "$COPS_ROOT" "$LOCAL_COPS_ROOT"
    elif [ -h local/corpusops.bootstrap ];then
        log "Reuse corpusops from: $(readlink -f "$LOCAL_COPS_ROOT")"
    elif [ -d local/corpusops.bootstrap ];then
        log "Local corpusops copy in: local/corpusops.bootstrap"
    fi
fi
# Using local copy in fallback
if [[ -n ${SKIP_COPS_CHECKOUT-} ]];then
        log "Skip corpusops.bootstrap checkout"
else
    if ! ( test_corpusops_present; );then
        if [ ! -e "$COPS_ROOT" ];then
            mkdir -p "$COPS_ROOT" || die "$COPS_ROOT can't be created"
        fi
        if ! git clone "$COPS_URL" "$LOCAL_COPS_ROOT";then
            die_ 21 "Error while cloning $COPS_URL -> $LOCAL_COPS_ROOT"
        fi
    else
        addmsg=
        if [ -h $LOCAL_COPS_ROOT ];then
            addmsg="${add} -> $(readlink -f $LOCAL_COPS_ROOT)"
        fi
        log "corpusops.bootstrap already there in $LOCAL_COPS_ROOT${addmsg}"
    fi
fi
