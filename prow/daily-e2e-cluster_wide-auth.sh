#!/bin/bash

# Copyright 2017 Istio Authors

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


#######################################
# Presubmit script triggered by Prow. #
#######################################

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

export KUBECONFIG=${HOME}/.kube/config
if [[ ${CI:-} == 'bootstrap' ]]; then
  export KUBECONFIG=/home/bootstrap/.kube/config
fi

# exports $HUB, $TAG, and $ISTIOCTL_URL
source greenBuild.VERSION
echo "Using artifacts from HUB=${HUB} TAG=${TAG} ISTIOCTL_URL=${ISTIOCTL_URL}"

ISTIO_SHA=`curl $ISTIOCTL_URL/../manifest.xml | grep istio/istio | cut -f 6 -d \"`
[[ -z "${ISTIO_SHA}"  ]] && echo "error need to test with specific SHA" && exit 1

mkdir -p ${GOPATH}/src/istio.io
cd ${GOPATH}/src/istio.io
git clone -n https://github.com/istio/istio.git
cd istio
git checkout $ISTIO_SHA

source "./prow/cluster_lib.sh"
trap delete_cluster EXIT
create_cluster 'cluster-wide-auth'

ISTIO_GO=$(cd $(dirname $0)/..; pwd)

# Download envoy and go deps
make init

make generate_yaml
mkdir -p ${GOPATH}/src/istio.io/istio/_artifacts
# It seems logs are generated on tmp ?
trap "cp -a /tmp/istio* ${GOPATH}/src/istio.io/istio/_artifacts" EXIT

echo 'Running Integration Tests'
./tests/e2e.sh --auth_enable --cluster_wide "$@" \
  --mixer_tag "${TAG}"\
  --mixer_hub "${HUB}"\
  --pilot_tag "${TAG}"\
  --pilot_hub "${HUB}"\
  --ca_tag "${TAG}"\
  --ca_hub "${HUB}"\
  --istioctl_url "${ISTIOCTL_URL}"
