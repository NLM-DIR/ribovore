#!/bin/bash

RETVAL=0;
CURRETVAL=0;

# we require 0 or 1 args, if 1 arg, it must be 'teamcity'
do_teamcity=0
if [ $# != 0 ]; then
    if [ $# -gt 1 ] || [ $1 != "teamcity" ]; then 
        echo "Usage:"
        echo "$0"
        echo "OR"
        echo "$0 teamcity"
        exit 1;
    fi
    # if we get here, there's 1 arg and it's 'teamcity'
    do_teamcity=1;
fi

if [ -z "${RIBOSCRIPTSDIR}" ] ; then
    echo "RIBOSCRIPTSDIR environment variable is not set, set it to top-level ribovore/ dir and rerun"
    exit 1
fi

for test in \
    01-iss2-modelname-parantheses.t \
    02-dupfilter-install-errors.t \
; do
    if [ $do_teamcity == 1 ]; then
        echo "##teamcity[testStarted name=\"$test\" captureStandardOutput='true']"
    fi

    prove -v $RIBOSCRIPTSDIR/t/$test;
    CURRETVAL=$?

    if [ $do_teamcity == 1 ]; then 
        if [ $CURRETVAL != 0 ]; then
            echo "##teamcity[testFailed name=\"$test\" message=\"failure\"]"
        fi
        echo "##teamcity[testFinished name=\"$test\"]"
    fi

    if [ $CURRETVAL != 0 ]; then
        RETVAL=1
    fi
done

if [ $RETVAL == 0 ]; then
   echo "Success: all tests passed"
   exit 0
else 
   echo "FAIL: at least one test failed"
   exit 1
fi
