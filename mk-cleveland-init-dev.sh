#!/usr/bin/env bash

set -e

function echo_info {
    echo -e "\033[32m ** $1\033[0m"
}

function echo_warning {
    echo -e "\033[33m ## $1\033[0m"
}

function echo_error {
    echo -e "\033[31m ==> $1\033[0m"
}

function init {
    echo_info "Create folders for each instance"
    # example
    prefix=280
    mongos_suffix=17
    config_suffix=18,19,20
    shard_suffix=21,22,23,24,25,26
    replicaSet_num=2
    total_suffix=${mongos_suffix},${config_suffix},${shard_suffix}
    echo ${total_suffix}
    for i in `echo ${total_suffix} | tr "," "\n"`; do
        echo "$i ~~"
    done 
}

init
