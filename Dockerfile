FROM ubuntu:xenial AS base
LABEL maintainer="Justin Hoppensteadt <justinrocksmadscience+git@gmail.com>"

ENV BITCOIN_GENBUILD_NO_GIT=1 \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    QT_X11_NO_MITSHM=1 \
    LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

RUN apt-get -y update && \
    apt-get -y dist-upgrade && \
    apt-get -y --no-install-recommends install  \
        libsqlite3-0 \
        libzmqpp3 \
        libboost-chrono1.58.0 \
        libboost-filesystem1.58.0 \
        libboost-system1.58.0 \
        libboost-thread1.58.0 \
        libevent-pthreads-2.0-5 \
        libevent-2.0-5

RUN groupadd -r -g 1000 armory && \
    useradd -r -m -u 1000 -g 1000 armory

FROM base AS build

RUN apt-get -y --no-install-recommends install  \
        automake  \
        autotools-dev  \
        bsdmainutils \
        build-essential  \
        cmake \
        git-core  \
        libattr1-dev \
        libboost-all-dev \
        libc6-dev \
        libcap-dev \
        libcrypto++-dev  \
        libcrypto++-utils  \
        libevent-dev \
        liblmdb-dev \
        libltdl-dev \
        libprotoc-dev \
        libqtcore4 libqt4-dev python-qt4 pyqt4-dev-tools \
        libsqlite3-dev \
        libssl-dev \
        libtool  \
        libuv1-dev \
        libzmqpp-dev \
        pkg-config \
        protobuf-compiler \
        python-dev \
        python-pip \
        python-twisted \
        python-psutil \
        python-setuptools \
        shtool \
        software-properties-common \
        swig \
        unzip \
        valgrind

COPY ./db-4.8.30.zip /
RUN cd /tmp && \
    unzip /db-4.8.30.zip && \
    cd db-4.8.30 && \
    cd build_unix/ && \
    ../dist/configure --prefix=/usr/local --enable-cxx && \
    make && \
    make check && \
    make install

RUN rm -rf /db-4.8.30.zip /tmp/db-4.8.30Z /usr/local/share/doc

WORKDIR /tmp
RUN git clone https://github.com/warmcat/libwebsockets.git && cd libwebsockets && git checkout v4.0.21
RUN mkdir /tmp/libwebsockets/build
WORKDIR /tmp/libwebsockets/build
RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    make && \
    make install

RUN rm -rf /tmp/libwebsockets

RUN cd /tmp && \
    git clone https://github.com/bitcoin/bitcoin.git && \
    cd bitcoin && \
    git checkout v0.20.1 && \
    ./autogen.sh && \
    ./configure \
        --prefix=/usr/local \
        --enable-gprof \
        --enable-determinism \
        --enable-utils \
    && \
    make && \
    make check && \
    make install

RUN cd /tmp && \
    git clone https://github.com/goatpig/BitcoinArmory.git && \
    cd BitcoinArmory && \
    echo git checkout py3_fixes && \
    git submodule init && \
    git submodule update

WORKDIR /tmp/BitcoinArmory
RUN export LIBS="-ldl $LIBS" LDFLAGS="-ldl $LDFLAGS" CFLAGS="-fno-strict-aliasing $CFLAGS" && ./autogen.sh && \
    ./configure \
        --prefix=/usr/local \
        --with-gnu-ld \
        --enable-wallet --enable-tools \
        --enable-tests \
        && \
    make

RUN export LIBS="-ldl $LIBS" LDFLAGS="-ldl $LDFLAGS" CFLAGS="-fno-strict-aliasing $CFLAGS" && \
    make check || ( find -type f -name test-suite.log -exec grep -H "" {} \;  ; exit 1)

RUN apt-get -y --no-install-recommends install \
        rsync \
        python-pip

RUN export LIBS="-ldl $LIBS" LDFLAGS="-ldl $LDFLAGS" CFLAGS="-fno-strict-aliasing $CFLAGS" && make install

COPY ./guardian.py /usr/local/lib/armory/guardian.py
RUN chmod 644 /usr/local/lib/armory/guardian.py

USER armory

RUN pip install --user psutil

USER root

FROM base as release

RUN apt-get -y --no-install-recommends install \
        libattr1 \
        libc6 \
        libcrypto++-utils  \
        libuv1 \
        libzmq5 \
        python-qt4

COPY --from=build /usr/local /usr/local
COPY --from=build /home /home

RUN chown -R armory:armory /home/armory

RUN apt-get -y -f install && \
    apt-get -y remove make rsync && \
    apt-get -y autoremove && \
    apt-get -y autoclean && \
    rm -rfv /root /tmp /var/lib/apt /var/cache /usr/local/doc && \
    mkdir /root /tmp && chmod 1777 /tmp && chmod 700 /root

RUN mkdir -p /var/cache/apt/archives/partial
RUN find /usr/local -ls

EXPOSE 8233
EXPOSE 8332
EXPOSE 8333
EXPOSE 9001
USER armory
ENTRYPOINT "/usr/bin/nice"
CMD "/usr/local/bin/armory"
