#!/usr/bin/env bash

# https://blog.csdn.net/qq_34382962/article/details/112209805
set -euo pipefail

PROG_NAME=$0
ACTION=$1

APP_NAME=tinyproxy

usage() {
    echo "Usage: ${PROG_NAME} {install|start|stop|restart}"
    exit 2 # bad usage
}

get_pid() {
    ps -ef | grep ${APP_NAME} | grep -v grep | awk '{print $2}'
}

install() {
    which tinyproxy &>/dev/null;ret=$?
    if [[ ${ret} -ne 0 ]]; then
        echo "Installing..."
        sudo apt-get install -y tinyproxy
        sudo sed -i 's/^Allow 127.0.0.1/#Allow 127.0.0.1/g' /etc/tinyproxy/tinyproxy.conf
        sudo sed -i 's/^Allow ::1/#Allow ::1/g' /etc/tinyproxy/tinyproxy.conf
    else
        echo "Already has a tiny. Ignore installing."
    fi
}

start() {
    echo "INFO: try to start ${APP_NAME}..."
    local s=0
    local pid=$(get_pid)

    if [[ -z "${pid}" ]]; then
        sudo systemctl start ${APP_NAME}
        sleep 1
        pid=$(get_pid)
    fi

    while [[ -z "${pid}" && ${s} -le 60 ]]; do
        let s+=1
        sleep 1
        echo "INFO: Waiting for ${s} s..."
        pid=$(get_pid)
    done

    if [[ -n "${pid}" ]]; then
        echo "INFO: start ${APP_NAME} successfully, pid=${pid}"
    else
        echo "INFO: start ${APP_NAME} failed"
    fi
}

stop() {
    echo "INFO: try to stop ${APP_NAME}..."
    local pid=$(get_pid)
    if [[ -n "${pid}" ]]; then
        sudo systemctl stop ${APP_NAME}
        sleep 1
        local s=0
        pid=$(get_pid)
        while [[ -n "${pid}" && ${s} -le 60 ]]; do
            let s+=1
            sleep 1
            echo "INFO: Waiting for ${s} s..."
            pid=$(get_pid)
        done
    fi

    if [[ -n "${pid}" ]]; then
        echo "INFO: stop ${APP_NAME} failed! pid is ${pid}"
        exit 1
    fi

    echo "INFO: stop ${APP_NAME} successfully"
}

restart() {
    echo "INFO: try to restart ${APP_NAME}..."
    sudo systemctl restart ${APP_NAME}
    sleep 1
    local s=0
    pid=$(get_pid)
    while [[ -z "${pid}" && ${s} -le 60 ]]; do
        let s+=1
        sleep 1
        echo "INFO: Waiting for ${s} s..."
        pid=$(get_pid)
    done

    if [[ -z "${pid}" ]]; then
        echo "INFO: restart ${APP_NAME} failed! pid is ${pid}"
        exit 1
    fi

    echo "INFO: restart ${APP_NAME} successfully"
}

main() {
    case "${ACTION}" in
        install)
            install
        ;;
        start)
            start
        ;;
        stop)
            stop
        ;;
        restart)
            restart
        ;;
        *)
            usage
        ;;
    esac
}

main