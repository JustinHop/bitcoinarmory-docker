#!/bin/bash

WORKDIR=$(dirname $(realpath $0))
cd $WORKDIR

. ./tag

docker run -it --rm \
    --name=armory \
    -p 8223:8223 \
    -p 8332:8332 \
    -p 8333:8333 \
    -p 9001:9001 \
    -e TZ \
    -e DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e DBUS_SESSION_BUS_ADDRESS \
    -v $WORKDIR/home:/home \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    $TAG:latest $@

