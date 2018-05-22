#!/bin/bash

PROG=${0}

# We need virtualenv from somewhere
virtualenv=`which virtualenv`
if [ ! -x "${virtualenv}" ]; then
    echo "location of virtualenv is unknown"
    exit 1
fi

# Set up env_name either from command line, else current git branch
if [ $# -eq 1 ]; then
    if [ "$1" == "git" ]; then
	env_name=`git rev-parse --abbrev-ref HEAD`
    else
	env_name=$1
    fi
else
    env_name='pika-deploy'
fi

# Normalize env_name, replace '/' with '_'
env_name=${env_name//\//_}
# our venv base path
venv_dir=.venv/${env_name}
# our venv bin dir
venv_bin_dir=${venv_dir}/bin

# Our virtual environments are found within <toplevelgit>/.venv
export WORKON_HOME=`pwd`/.venv

# pick python
use_python=python3.5
set +e
python3.5 --version
set -e
if [ $? -ne 0 ] ; then
    use_python=python3.5
fi

# determine which shasum command to use.
#  - mac has shasum, but not sha1sum
#  - ubuntu has shasum and sum1sum
#  - rhel has sum1sum, but not shasum
if [[ $(command -v shasum) ]] ; then
  SHACMD=$(command -v shasum)
elif [[ $(command -v sha1sum) ]] ; then
  SHACMD=$(command -v sha1sum)
else
  echo "Unable to locate simple sha checksome (shasum or sha1sum)"
  exit 1
fi

# just nuke everything that gets dump into the working directory.
pika_deploy_state_dir=$(pwd)/.pika_deploy

# note that soon .kube, .minikube, and .helm will be down under $[pika_deploy_state_dir},
# but be aggressive on cleanup for now.
rm -rf .kube .minikube .venv ${pika_deploy_state_dir} .helm ${venv_dir}

# make sure there is a blank pika-deploy-state dir, with current pointing to it.
mkdir -p ${pika_deploy_state_dir}/_unset_dir
ln -s ${pika_deploy_state_dir}/_unset_dir ${pika_deploy_state_dir}/current

# mkvirtualenv, OK if its already there
${virtualenv} --clear --python=${use_python} ${venv_dir}

# activate the virtual environment
source ${venv_bin_dir}/activate

# Use locally sourced pip configuration
export PIP_CONFIG_FILE=`pwd`/pip.conf

# Update local-pip to latest
pip install -U pip

# Install all required "shipping" packages
pip install -r requirements.txt

# Create local requirements (for example, pylint)
pip install -r requirements_devtime.txt

# Determine OS
if [ "$(uname -s)" == "Darwin" ] ; then
    this_os="darwin"
    exe_ext=""
    etcd_archive_suffix="zip"
elif [ "$(uname -s)" == "Linux" ] ; then
    this_os="linux"
    exe_ext=""
    etcd_archive_suffix="tar.gz"
elif [ "$(uname -s)" == "Windowsmaybe" ] ; then
    this_os="windows"
    exe_ext=".exe"
    etcd_archive_suffix="zip"
else
    echo "Unsupported base-os to do pika from"
    exit 1
fi

alleged_kstable=$(curl -sk https://storage.googleapis.com/kubernetes-release/release/stable.txt)
kstable=v1.8.4
echo "** Fetching kubectl for local environment, version=${kstable} (alleged stable is ${alleged_kstable})"
echo "  *TODO*: handle version and check version vs local copy"
kc_bin=${venv_bin_dir}/kubectl${exe_ext}
if [ -f  ${kc_bin} ] ; then
    echo "  ** kubectl already installed in venv"
else
    curl --silent --show-error -Lo ${kc_bin} -k https://storage.googleapis.com/kubernetes-release/release/${kstable}/bin/${this_os}/amd64/kubectl${exe_ext}
    chmod +x ${kc_bin}
    echo "  ** kubectl installed in venv"
fi

mk_version="v0.24.1"   # not trusting any kind of 'latest' at the moment. Will need to qualify releases
echo "** Fetching minikube for local environment, version=${mk_version}"
echo "  *TODO*: handle version and check version vs local copy"
mk_bin=${venv_bin_dir}/minikube${exe_ext}
if [ -f ${mk_bin} ] ; then
    echo "  ** minikube already installed in venv"
else
    curl --silent --show-error -Lo ${mk_bin} -k https://storage.googleapis.com/minikube/releases/${mk_version}/minikube-${this_os}-amd64${exe_ext}
    chmod +x ${mk_bin}
    echo "  ** minikube installed in venv"
fi

helm_version="v2.7.2"   # not trusting any kind of 'latest' at the moment. Will need to qualify releases
echo "** Fetching helm for local environment, version=${helm_version}"
echo "  *TODO*: handle version and check version vs local copy"
helm_archive_name=helm-${helm_version}-${this_os}-amd64.tar.gz
helm_archive_path=${venv_dir}/${helm_archive_name}
helm_archive_bin=${venv_dir}/${this_os}-amd64/helm${exe_ext}
helm_bin=${venv_bin_dir}/helm${exe_ext}
if [ -f ${helm_bin} ] ; then
    echo "  ** helm already installed in venv"
else
    echo "  ** getting helm binary archive"
    curl --silent --show-error -Lo ${helm_archive_path} -k https://storage.googleapis.com/kubernetes-helm/${helm_archive_name}
    echo "  ** extracting helm binary from archive"
    tar -C ${venv_dir} -xzf ${helm_archive_path}
    cp ${helm_archive_bin} ${helm_bin}
    echo "  ** helm installed in venv"
fi

# etcdctl is IN the etcd package..
# Note: if you change etcd_version, alter services_controller.py as well to point to the same version please.
etcd_version="v3.3.1"
latest=$(curl -sk https://github.com/coreos/etcd/releases/latest | egrep -o "v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+")
echo "** Fetching etcdctl for local environment using version ${etcd_version}, latest is ${latest}"
etcdctl_bin=${venv_bin_dir}/etcdctl${exe_ext}
etcd_archive_name=etcd-${etcd_version}-${this_os}-amd64.${etcd_archive_suffix}
etcd_archive_path=${venv_dir}/${etcd_archive_name}
etcdctl_archive_bin=${venv_dir}/etcd-${etcd_version}-${this_os}-amd64/etcdctl${exe_ext}
if [ -f ${etcdctl_bin} ] ; then
    echo "  ** etcdctl already installed in venv"
else
    echo "  ** getting etcd binary archive"
    curl --silent --show-error -Lo ${etcd_archive_path} -k https://github.com/coreos/etcd/releases/download/${etcd_version}/${etcd_archive_name}
    echo "  ** extracting etcdctl binary from archive"
    if [ "${etcd_archive_suffix}" == "zip" ] ; then
        unzip -d ${venv_dir} ${etcd_archive_path}
    else
        tar -C ${venv_dir} -xzf ${etcd_archive_path}
    fi
    cp ${etcdctl_archive_bin} ${etcdctl_bin}
fi

# Name our "instance"
pika_instance=$(pwd | ${SHACMD})
# remove trailing "  -"
pika_instance=${pika_instance/  -/}

# Generate a script that assists in switching environments
cat > myenv_${env_name} <<End-of-message
# *** Autgenerated file, do not commit to remote repository
if [[ "\${BASH_VERSION}" =~ ^[23]\..* ]] ; then
  echo "NOTE: bash version needs to be 4+ for autocompletion setup. Current is ${BASH_VERSION}."
  echo "      autocompletion setup skipped, but everything else is set up."
  _SETUP_AC=0
else
  _SETUP_AC=1
  [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion
fi

DIR="\$( cd "$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

if [ "\$(declare -F deactivate)" == "deactivate" ] ; then
    # force the deactivate, which will repair PATH.
    deactivate;
fi

export WORKON_HOME=\${DIR}/.venv
source ${venv_bin_dir}/activate

# Basically rename virtualenv's deactivate
if [ "\$(uname -s)" == "Darwin" ] ; then
    eval "\$(declare -f deactivate | sed "s/[[:<:]]deactivate[[:>:]]/_extra_deactivate/g")"
else
    eval "\$(declare -f deactivate | sed "s/\<deactivate\>/_extra_deactivate/g")"
fi
# Now make our own that calls the orig.
deactivate() {
    _extra_deactivate;
    if [ -n "\${_OLD_VIRTUAL_PYTHONPATH+isset}" ]; then
        PYTHONPATH="\${_OLD_VIRTUAL_PYTHONPATH}";
        export PYTHONPATH;
        unset _OLD_VIRTUAL_PYTHONPATH;
    fi;
    if [ -n "\${_OLD_PIKA_HELM_HOME+isset}" ]; then
        HELM_HOME="\${_OLD_PIKA_HELM_HOME}";
        export HELM_HOME;
        unset _OLD_PIKA_HELM_HOME;
    fi;
    unset _PIKA_INSTANCE;
    unset MINIKUBE_PROFILE;
    unset MINIKUBE_HOME;
    unset KUBECONFIG;
    unset pika_setenv;
    unset deactivate;
}

# Shell functions to quickly get pika ENV variables:
pika_setenv() {
    eval \$(pika-deploy devtools envs show)
    echo "use \\\${PIKA_CONTROLLER_URL} to access pika-controller"
}

export PATH=\${DIR}/src/bin:\$PATH
export _OLD_VIRTUAL_PYTHONPATH=\${PYTHONPATH}
export _OLD_PIKA_HELM_HOME=\${HELM_HOME}
export PYTHONPATH=\${PYTHONPATH:+\${PYTHONPATH}:}\${DIR}:\${DIR}/src/

export _PIKA_INSTANCE=${pika_instance}
export MINIKUBE_HOME=${pika_deploy_state_dir}/current
export KUBECONFIG=${pika_deploy_state_dir}/current/.kube/config
export HELM_HOME=${pika_deploy_state_dir}/current/.helm/

if [ ${PIKA_DEPLOY_EXPERIMENT_MULTI_KUBE:0} ] ; then
    # experimental feature that allows multiple minikubes to be run on the same box
    export MINIKUBE_PROFILE="minikube_${pika_instance}.local"
    minikube profile ${MINIKUBE_PROFILE}
fi

if [ \${SETUP_AC} ] ; then
eval "$(register-python-argcomplete pika-deploy)"
End-of-message

kubectl completion bash >> myenv_${env_name}
minikube completion bash >> myenv_${env_name}
helm completion bash >> myenv_${env_name}

# Add the end of the "if ${SETUP_AC}"
echo "fi" >> myenv_${env_name}

echo ""
echo "${PROG}: complete, run the following to use '${env_name}' environment:"
echo
echo "source myenv_${env_name}"
cp myenv_${env_name} .venv/
pwd > .venv/built_in
exit 0
