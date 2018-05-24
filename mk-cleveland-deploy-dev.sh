#!/usr/bin/env bash


function get_distro_info {
    if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        DISTRO_PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        DISTRO_PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        DISTRO_PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        DISTRO_PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        DISTRO_PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        DISTRO_PM='apt'
        if grep -Eqi "14.04" /etc/issue || grep -Eq "14.04" /etc/*-release; then
            DISTRO_VERSION="1404"
        elif grep -Eqi "16.04" /etc/issue || grep -Eq "16.04" /etc/*-release; then
            DISTRO_VERSION="1604"
        fi
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        DISTRO_PM='apt'
    else
        DISTRO='unknown'
    fi
}

function create_group {
    egrep "^$1" /etc/group >& /dev/null  
    if [ $? -ne 0 ]  
    then  
        groupadd $1 
    fi  
}
          
function create_user {
    egrep "^$2" /etc/passwd >& /dev/null  
    if [ $? -ne 0 ]  
    then  
        useradd -g $2 $1  
    fi 
}

function echo_info {
    echo -e "\033[32m ** $1\033[0m"
}

function echo_warning {
    echo -e "\033[33m ## $1\033[0m"
}

function echo_error {
    echo -e "\033[31m ==> $1\033[0m"
}

# =================================================================== #

if [ "`whoami`" != "root" ]; then
    echo_error "root is needed"
    exit 1
fi

get_distro_info

if [ `uname -s` == "Darwin" ]; then
    distribution_prefix=osx
    distribution=mongodb-osx-ssl-x86_64
    extract_name=mongodb-osx-x86_64
    target_folder=/usr/local/Cellar/mongodb
    target_link_folder=/usr/local/bin
elif [ `uname -s` == "Linux" ]; then
    if [ "${DISTRO}" == "Ubuntu" ]; then
        distribution_prefix=linux
        distribution=mongodb-linux-x86_64-ubuntu${DISTRO_VERSION}
        extract_name=${distribution}
        target_folder=/usr/local/lib/mongodb
        target_link_folder=/usr/local/bin
    else
        echo_error "Linux is unsupported base-os in current version"
        exit 1
    fi
else
    echo_error "`uname -s` is unsupported base-os in current version"
    exit 1
fi

work_folder=${HOME}/cleveland_temp
mongodb_version=3.6.5
extract_folder=${work_folder}/${extract_name}-${mongodb_version}
download_file=${distribution}-${mongodb_version}.tgz
download_url=https://fastdl.mongodb.org/${distribution_prefix}/${download_file}
# echo_info "Create new group and user mongodb"
# create_group mongodb
# create_user mongodb mongodb


function install {
    if [ -d ${target_folder} ]; then
        echo_warning "mongodb already installed in current machine, location is: ${target_folder}"
        exit 1
    fi


    echo_info "Create work folder on ${work_folder}"
    mkdir -p ${work_folder}
    rm -rf ${extract_folder}
    mkdir -p ${extract_folder}

    pushd ${work_folder}

    if [ -f ${download_file} ]; then
        echo_info "${download_file} has already been downloaded in current folder"
    else
        echo_info "Fetch mongodb from ${download_url}"
        curl --silent --show-error -Lo ${download_file} -k ${download_url}
    fi

    echo_info "Extract the files from the downloaded archive"
    tar -zxvf ${download_file}
    echo_info "Move to ${target_folder}"
    mv ${extract_folder} ${target_folder}
    echo_info "Create a soft link on ${target_link_folder}"
    for element in `ls ${target_folder}/bin`
    do
        if [ ! -h ${target_link_folder}/${element} ]; then
            ln -s ${target_folder}/bin/${element} ${target_link_folder}/${element}
        fi
    done

    popd
}

function uninstall {
    if [ -d ${target_folder} ]; then
        for element in `ls ${target_folder}/bin`
        do
        if [ -h ${target_link_folder}/${element} ]; then
            echo_info "Remove soft link -> ${element}"
            rm -f ${target_link_folder}/${element}
        fi
        done

        echo_info "Remove folder ${target_folder}"
        rm -rf ${target_folder}
    fi
}

if [ $1 == "install" ]; then
    install
elif [ $1 == "uninstall" ]; then
    uninstall
else
    echo_error "unkown"
fi
