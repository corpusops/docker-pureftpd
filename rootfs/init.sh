#!/bin/bash
set -e
PUREFTPD_SDEBUG=${PUREFTPD_SDEBUG-}
if [[ -n $PUREFTPD_SDEBUG ]];then set -x;fi

join_by() { local IFS="$1"; shift; echo "$*"; }
log() { echo "$@" >&2; }
vv() { log "$@"; "$@"; }


for c in /etc/logrotate.d/pure-ftpd-common;do
    log "Patching /etc/logrotate.d/pure-ftpd-common"
    frep /conf$c:$c --overwrite
done

SUPERVISORD_CONFIGS="${SUPERVISORD_CONFIGS-pureftpd cron rsyslog}"
PURE_FTPD_FLAVOR=${PURE_FTPD_FLAVOR-}

TLS_CN=${TLS_CN:-$(hostname -f)}
TLS_ORG=${TLS_ORG:-acme}
TLS_C=${TLS_C:-FR}
TLS_MODE=${TLS_MODE-1}

PUBLICHOST=${PUBLICHOST-}
NO_CHMOD=${NO_CHMOD-}
FTP_MAX_CLIENTS=${FTP_MAX_CLIENTS:-5}
FTP_MAX_CONNECTIONS=${FTP_MAX_CONNECTIONS:-5}

FTP_PASSIVE_PORTS=${FTP_PASSIVE_PORTS:-"30000:30009"}
FTP_PASSIVE_PORTS=${FTP_PASSIVE_PORTS//-/:}
FTP_PASSIVE_PORTS=${FTP_PASSIVE_PORTS// /:}

FTP_USER_NAME=${FTP_USER_NAME-ftp}
FTP_USER_HOME="${FTP_USER_HOME:-"/home/${FTP_USER_NAME}"}"
FTP_USER_HOME_PERMISSION=${FTP_USER_HOME_PERMISSION-}
FTP_USER_UID=${FTP_USER_UID-1000}
FTP_USER_GID=${FTP_USER_GID-1000}
FTP_USER_PASS=${FTP_USER_PASS-}

NO_INIT=${NO_INIT-}

PASSWD_FILE="${PASSWD_FILE:-/etc/pure-ftpd/passwd/pureftpd.passwd}"
if [ ! -e /etc/pure-ftpd/pureftpd.passwd ];then
    ln -sfv "$PASSWD_FILE" /etc/pure-ftpd/pureftpd.passwd
fi

NO_PASSIVE_MODE="${NO_PASSIVE_MODE-}"
CONFIG_PUBLIC_HOST=""
if [[ -z "$NO_PASSIVE_MODE" ]] && [[ -z "$PUBLICHOST" ]];then
    PUBLICHOST=$(ip r get 1|head -n1|awk -F src '{print $2}'|awk '{print $1}')
fi
if [[ -n "$PUBLICHOST" ]];then
    CONFIG_PUBLIC_HOST="-P $PUBLICHOST"
fi

PERSISTENT_PURE_FTPD_DB=${PERSISTENT_PURE_FTPD_DB:-/etc/pure-ftpd/passwd/pureftpd.pdb}
DEFAULT_PURE_FTPD_DB=${DEFAULT_PURE_FTPD_DB:-/etc/pure-ftpd/pureftpd.pdb}
PURE_FTPD_DB=${PURE_FTPD_DB:-${DEFAULT_PURE_FTPD_DB}}
if [ ! -e "${PURE_FTPD_DB}" ];then
    PURE_FTPD_DB="${PERSISTENT_PURE_FTPD_DB}"
fi
PURE_FTPD_DB_DIR=$(dirname ${PURE_FTPD_DB})
# ENV vars for pure-pw defaults settings
export PURE_PASSWDFILE="${PASSWD_FILE}"
export PURE_DBFILE="${PURE_FTPD_DB}"

PURE_FTPD_EXTRA_FLAGS=" ${PURE_FTPD_EXTRA_FLAGS-} "
DEFAULT_PURE_FTPD_FLAGS="-l puredb:${PURE_DBFILE} -E -j ${CONFIG_PUBLIC_HOST}"
if [[ -n "$TLS_MODE" ]];then DEFAULT_PURE_FTPD_FLAGS="$DEFAULT_PURE_FTPD_FLAGS --tls=${TLS_MODE}";fi

if ( echo $PURE_FTPD_FLAVOR | grep -q hardened );then
	DEFAULT_PURE_FTPD_FLAGS="$DEFAULT_PURE_FTPD_FLAGS -s -A -j -Z -H -4 -E -R -G -X -x"
fi
if [[ -n $NO_CHMOD ]];then
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -R"
fi
ADDED_FLAGS=${ADDED_FLAGS-}
PURE_FTPD_FLAGS=" ${@:-"${DEFAULT_PURE_FTPD_FLAGS}"} ${ADDED_FLAGS} ${PURE_FTPD_EXTRA_FLAGS} "


if [[ -z $NO_INIT ]];then

if [ ! -e $PURE_FTPD_DB_DIR ]; then mkdir $PURE_FTPD_DB_DIR;fi

# Load in any existing db from volume store
if [ -e "$PASSWD_FILE" ];then
    pure-pw mkdb
fi

# detect if using TLS (from file in volume) but no flag set, set one
if [ -e /etc/ssl/private/pure-ftpd.pem ] && \
    [[ "$PURE_FTPD_FLAGS" != *"--tls"* ]];then
    log "TLS Enabled"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS --tls=1 "
fi

# If TLS flag is set and no certificate exists, generate it
if [ ! -e /etc/ssl/private/pure-ftpd.pem ] && \
    [[ "$PURE_FTPD_FLAGS" == *"--tls"* ]] && \
    [ ! -z "$TLS_CN" ] && \
    [ ! -z "$TLS_ORG" ] && \
    [ ! -z "$TLS_C" ];then

    log "Generating self-signed certificate"
    mkdir -p /etc/ssl/private

    if [[ "$TLS_USE_DSAPRAM" == "true" ]];then
        openssl dhparam -dsaparam -out \
            /etc/ssl/private/pure-ftpd-dhparams.pem 2048
    else
        openssl dhparam -out /etc/ssl/private/pure-ftpd-dhparams.pem 2048
    fi

    openssl req -subj "/CN=${TLS_CN}/O=${TLS_ORG}/C=${TLS_C}" -days $((50*365)) \
        -x509 -nodes -newkey rsa:2048 -sha256 -keyout \
        /etc/ssl/private/pure-ftpd.pem \
        -out /etc/ssl/private/pure-ftpd.pem
    chmod 600 /etc/ssl/private/*.pem
fi

# Add user

if [ ! -z "$FTP_USER_NAME" ] && \
    [ ! -z "$FTP_USER_PASS" ] && \
    [ ! -z "$FTP_USER_HOME" ];then

    log "Creating user..."

    # make sure the home folder exists
    mkdir -p "$FTP_USER_HOME"

    # Generate the file that will be used to inject in the password prompt stdin
    PWD_FILE="$(mktemp)"
    echo "$FTP_USER_PASS
$FTP_USER_PASS" > "$PWD_FILE"

    # Set uid/gid
    PURE_PW_ADD_FLAGS=""
    if [ ! -z "$FTP_USER_UID" ];then
        PURE_PW_ADD_FLAGS="$PURE_PW_ADD_FLAGS -u $FTP_USER_UID"
    else
        PURE_PW_ADD_FLAGS="$PURE_PW_ADD_FLAGS -u ftpuser"
    fi
    if [ ! -z "$FTP_USER_GID" ];then
        PURE_PW_ADD_FLAGS="$PURE_PW_ADD_FLAGS -g $FTP_USER_GID"
    fi

    addmode=add
    if ( pure-pw list |awk '{print $1}' |egrep -q "^${FTP_USER_NAME}$" );then
        addmode=mod
    fi

    pure-pw user${addmode} "$FTP_USER_NAME" \
        -m -d "$FTP_USER_HOME" $PURE_PW_ADD_FLAGS < "$PWD_FILE"

    if [ "x${addmode}" = "xmod" ];then
        ( echo "$FTP_USER_PASS";echo "$FTP_USER_PASS" )| pure-pw passwd $FTP_USER_NAME
        pure-pw mkdb
    fi

    if [ ! -z "$FTP_USER_HOME_PERMISSION" ];then
        chmod "$FTP_USER_HOME_PERMISSION" "$FTP_USER_HOME"
        log " root user give $FTP_USER_NAME ftp user at $FTP_USER_HOME directory has $FTP_USER_HOME_PERMISSION permission"
    fi

    if [ ! -z "$FTP_USER_UID" ];then
        if ! [[ $(ls -ldn $FTP_USER_HOME \
                    | awk '{print $3}') = $FTP_USER_UID ]];then
            chown $FTP_USER_UID "$FTP_USER_HOME"
            log " root user give $FTP_USER_HOME directory $FTP_USER_UID owner"
        fi
    else
        if ! [[ $(ls -ld $FTP_USER_HOME \
                    | awk '{print $3}') = 'ftpuser' ]];then
            chown ftpuser "$FTP_USER_HOME"
            log " root user give $FTP_USER_HOME directory ftpuser owner"
        fi
    fi

    rm "$PWD_FILE"
fi

# Set passive port range in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -p "* ]] && [[ -z "$NO_PASSIVE_MODE" ]];then
    log "Setting default port range to: $FTP_PASSIVE_PORTS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -p $FTP_PASSIVE_PORTS"
fi

# Set max clients in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -c "* ]];then
    log "Setting default max clients to: $FTP_MAX_CLIENTS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -c $FTP_MAX_CLIENTS"
fi

# Set max connections per ip in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -C "* ]];then
    log "Setting default max connections per ip to: $FTP_MAX_CONNECTIONS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -C $FTP_MAX_CONNECTIONS"
fi
fi

# let users know what flags we've ended with (useful for debug)
log "Starting Pure-FTPd:"
log "  pure-ftpd $PURE_FTPD_FLAGS"

# start pureftpd with requested flags
export \
    FTP_MAX_CLIENTS \
    FTP_MAX_CONNECTIONS \
    FTP_PASSIVE_PORTS \
    FTP_USER_GID \
    FTP_USER_HOME \
    FTP_USER_HOME_PERMISSION \
    FTP_USER_NAME \
    FTP_USER_PASS \
    FTP_USER_UID \
    PURE_FTPD_FLAGS \
    PURE_FTPD_FLAVOR \
    SUPERVISORD_CONFIGS \
    TLS_C \
    TLS_CN \
    TLS_ORG \
    PASSWD_FILE

if ( echo "$@" | egrep -q "bash$|debug|shell" );then
    exec bash
else
    exec /bin/supervisord.sh
fi
# vim:set et sts=4 ts=4 tw=0:
