#Stage 1 : builder debian image
FROM corpusops/ubuntu-bare:20.04 AS builder

# properly setup debian sources
ENV DEBIAN_FRONTEND noninteractive

# install package building helpers
# rsyslog for logging (ref https://github.com/stilliard/docker-pure-ftpd/issues/17)
RUN apt-get update -yqq && apt install -y software-properties-common
RUN add-apt-repository -y ppa:corpusops/pure-ftpd \
    && sed -i -re "s/# (deb-src .*$(lsb_release -sc) )/\1/g" /etc/apt/sources.list \
    && echo "deb-src http://ppa.launchpad.net/corpusops/pure-ftpd/ubuntu $(lsb_release -sc) main" >> /etc/apt/sources.list \
    && egrep ^deb-src /etc/apt/sources.list /etc/apt/sources.list.d/* \
    && apt-get -y update \
    && apt-get -y --force-yes --fix-missing install dpkg-dev debhelper \
    && apt-get -y build-dep pure-ftpd


# Build from source - we need to remove the need for CAP_SYS_NICE and CAP_DAC_READ_SEARCH
RUN mkdir /tmp/pure-ftpd/ \
    && cd /tmp/pure-ftpd/ \
    && apt-get source pure-ftpd \
    && cd pure-ftpd-* \
    && sed -i '/CAP_SYS_NICE,/d; /CAP_DAC_READ_SEARCH/d; s/CAP_SYS_CHROOT,/CAP_SYS_CHROOT/;' src/caps_p.h \
    && dpkg-buildpackage -b -uc

#Stage 2 : actual pure-ftpd image
FROM corpusops/ubuntu-bare:20.04 AS image

# feel free to change this ;)
LABEL maintainer "kiorky <kiorky@@cryptelium.net>"

# install dependencies
RUN apt-get -y update
ARG flavor=
# default publichost, you'll need to set this for passive support
ENV \
    PURE_FTPD_FLAVOR="$flavor" \
    DEBIAN_FRONTEND="noninteractive" \
    PUBLICHOST="localhost"

COPY --from=builder /tmp/pure-ftpd/*.deb /tmp/
# install the new deb files
RUN set -ex && apt-get -yqq update \
    && ls /tmp/pure-ftpd* \
    && flavor=$(echo -${flavor}|sed -re "s/-?(latest|hardened)//g") \
    && echo "flavor: $flavor" >&2\
    && apt-get install --no-install-recommends --yes \
        /tmp/pure-ftpd-common*.deb \
        /tmp/pure-ftpd${flavor}_*.deb \
    && apt-mark hold pure-ftpd pure-ftpd-common \
    && apt-get clean all && apt-get autoclean && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /tmp/pure-ftpd*

RUN groupadd ftpgroup \
    && useradd -g ftpgroup -d /home/ftpusers -s /dev/null ftpuser
ADD rootfs/ /
# startup
ENTRYPOINT ["/init.sh"]
