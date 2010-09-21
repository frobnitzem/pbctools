#!/bin/sh

NAME=$1

if [ ! "$NAME" ]; then
    echo "Usage: tar_release.sh NAME (e.g. pbctools-2.3)"
    exit 2;
fi

if [ ! -d $NAME ]; then
    echo "Directory $NAME does not exist!"
    exit 1
fi

ARCHNAME=$(basename $NAME)

echo "Creating archive $ARCHNAME.tar.gz..."
tar -chzvf $ARCHNAME.tar.gz $NAME --exclude-vcs --exclude=maintainer
