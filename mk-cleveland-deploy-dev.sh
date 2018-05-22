#!/usr/bin/env bash

work_folder=${HOME}/cleveland_temp
extract_folder=${work_folder}/mongodb
mongodb_version=3.6.4
bin=/usr/local/bin

if [ `uname -s` == "Darwin" ] ; then
    distribution_prefix=osx
    distribution=mongodb-osx-ssl-x86_64
    target_folder=/usr/local/Cellar/mongodb
elif [ `uname -s` == "Linux" ] ; then
    echo "Linux is unsupported base-os in current version"
    exit 1
fi

if [ -d ${target_folder} ]; then
    echo "mongodb already installed in current machine, location is: ${target_folder}"
    exit 1
fi

echo "  ** Create work folder on ${work_folder}"
mkdir -p ${work_folder}
rm -rf ${extract_folder}
mkdir -p ${extract_folder}

pushd ${work_folder}

download_file=${distribution}-${mongodb_version}.tgz
download_url=https://fastdl.mongodb.org/${distribution_prefix}/${download_file}

if [ -f ${download_file} ]; then
    echo "  ** ${download_file} already exiests in current folder"
else
    echo "  ** Fetch mongodb from ${download_url}"
    curl --silent --show-error -Lo ${download_file} -k ${download_url}
fi

echo "  ** Extract the files from the downloaded archive"
tar -zxvf ${download_file} -C ${extract_folder}
echo "  ** Move to ${target_folder}"
mv -aR ${extract_folder} ${target_folder}
echo " ** Create a soft link on ${bin}"
cp -s ${target_folder} ${bin}/mongodb

