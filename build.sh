#!/bin/bash

echo "StackTach dev env build script"

PACKAGE=false
TOX=false
DEPLOY=false

while getopts pdt opt; do
  case $opt in
  p)
      PACKAGE=true
      ;;
  t)
      TOX=true
      ;;
  d)
      DEPLOY=true
      ;;
  esac
done

shift $((OPTIND - 1))

DEV_DIR=git
PKG_DIR=dist
SOURCE_DIR=$DEV_DIR
VENV_DIR=.venv
PIPELINE_ENGINE=winchester

if [[ "$PACKAGE" = true ]]
then
    SOURCE_DIR=$PKG_DIR
    rm -rf $PKG_DIR
    rm -rf $VENV_DIR
fi

if [[ -f local.sh ]]; then
    source local.sh
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  mkdir $SOURCE_DIR
fi

if [[ ! -d "$VENV_DIR" ]]; then
  virtualenv $VENV_DIR
fi

cd $SOURCE_DIR
for file in shoebox simport notigen notification-utils \
            stackdistiller quincy quince \
            klugman winchester
do
    git clone http://git.openstack.org/cgit/stackforge/stacktach-$file
done
# We still have some stragglers ...
for file in StackTach/notabene rackerlabs/yagi
do
    git clone https://github.com/$file
done

if [[ "$TOX" = true ]]
then
    for file in shoebox simport notification-utils \
                stackdistiller winchester
    do
        cd stacktach-$file
        set -e
        tox
        set +e
        cd ..
    done
fi

cd ..

source ./$VENV_DIR/bin/activate

# Some extra required libs ...
pip install mysql-connector-python --allow-external mysql-connector-python
pip install gunicorn
pip install httpie
pip install librabbitmq

# Needed by pyrax:
pip install pbr

for file in $SOURCE_DIR/*
do
    echo "----------------------- $file ------------------------------"
    cd $file
    rm -rf build dist
    python setup.py install
    cd ../..
done

(cat yagi.conf.$PIPELINE_ENGINE ; cat yagi.conf.common ) > yagi.conf

if [ $PIPELINE_ENGINE == "winchester" ]
then
    winchester_db -c winchester.yaml upgrade head
fi

if [[ "$PACKAGE" = true ]]
then
    SHA=$(git log --pretty=format:'%h' -n 1)
    mkdir dist
    #rm $VENV_DIR/lib/python2.7/site-packages/daemon-*.egg
    virtualenv --relocatable $VENV_DIR
    mv $VENV_DIR dist/stv3
    cd dist
    tar -zcvf ../stacktachv3_$SHA.tar.gz stv3
    cd ..
    echo "Release tarball in stacktachv3_$SHA.tar.gz"

    if [[ "$DEPLOY" == true ]]
    then
        echo Do ansible stuff here ...
    fi
else
    screen -c screenrc.$PIPELINE_ENGINE
fi
