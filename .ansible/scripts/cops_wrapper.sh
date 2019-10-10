#!/usr/bin/env bash
log() { echo "$@" >&2; }
vv() { log "($COPS_CWD) $@";"$@"; }
debug() { if [[ -n "${ADEBUG-}" ]];then log "$@";fi }
vvdebug() { if [[ -n "${ADEBUG-}" ]];then log "$@";fi;"${@}"; }
export COPS_CWD=${COPS_CWD:-$(pwd)}
export COPS_SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
export COPS_LOCAL_FOLDER="${COPS_LOCAL_FOLDER:-$COPS_CWD/local}"
export LOCAL_COPS_ROOT="$COPS_LOCAL_FOLDER/corpusops.bootstrap"
script="$(basename $0)"
real_script="$LOCAL_COPS_ROOT/hacking/deploy/$script"
real_env="$LOCAL_COPS_ROOT/hacking/deploy/ansible_deploy_env"
debug "local folder: $COPS_LOCAL_FOLDER"
if [ ! -e "$COPS_LOCAL_FOLDER" ];then
    log "local folder not found ($COPS_LOCAL_FOLDER)"
    log "Maybe time to mkdir $COPS_LOCAL_FOLDER or to cd into $COPS_CWD before launching commands"
    exit 1
fi
debug "LOCAL_COPS_ROOT folder: $LOCAL_COPS_ROOT"
if [ ! -e "$LOCAL_COPS_ROOT" ];then
    log "corpusops not found in $LOCAL_COPS_ROOT"
    log "Maybe time to $COPS_SCRIPTS_DIR/download_corpusops.sh"
    exit 1
fi
if [ ! -e "$real_script" ];then
    log "Corpusops script: $script not found (LOCAL_COPS_ROOT: $LOCAL_COPS_ROOT)"
    log "Maybe time to $LOCAL_COPS_ROOT/bin/install.sh -C -s"
    exit 1
fi
if ! vvdebug ln -sf "$real_env" "$COPS_SCRIPTS_DIR/ansible_deploy_env";then
    log "Symlinking env failed: $COPS_SCRIPTS_DIR/ansible_deploy_env"
    exit 1
fi
vvdebug "$real_script" "$@"
