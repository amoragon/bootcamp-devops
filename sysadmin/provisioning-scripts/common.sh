#!/bin/bash

function common::add_elastic_apt_repository() {
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - 2>> apt-error.log

    apt-get install apt-transport-https 2>> apt-error.log
    if [ -e /etc/apt/sources.list.d/elastic-7.x.list ]
    then
        echo "Elastic repository already exists. It won't be added"
    else
        echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
    fi
}

function common::enable_service() {
    if [ "$(systemctl is-enabled $1)" != "enabled" ]
    then
        echo -n "Enabling ${1^}" | tr . " "
        systemctl enable $1 2>> systemctl-error.log
        echo "...ok!"
    fi
}

function common::start_service() {
    if [ "$(systemctl is-active $1)" != "active" ]
    then
        echo -n "Starting ${1^}" | tr . " "
        systemctl start $1 2>> systemctl-error.log
        echo "...ok!"
    fi
}

function common::stop_service() {
    if [ "$(sudo systemctl is-active $1)" == "active" ]
    then
        echo -n "Stoping ${1^}" | tr . " " 
        systemctl stop $1 2>> systemctl-error.log
        echo "...ok!"
    fi
}
