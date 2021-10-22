#!/bin/bash

# GUSER=

glist() {
  gcloud compute instances list --filter="labels.owner:${GUSER}"
}

gcreate() {
  local usage="Usage: gcreate [IMAGE] [INSTANCE_NAMES]"
  if [ "$#" -lt 2 ]; then echo "${usage}"; return 1; fi
  local image
  image="$(gcloud compute images list | grep "$1" | awk 'NR == 1')"
  if [ -z "${image}" ]; then image="$(gcloud compute images list --show-deprecated | grep "$1" | awk 'NR == 1')"; fi
  if [ -z "${image}" ]; then echo "gcreate: unknown image $image"; echo "${usage}"; return 1; fi
  local image_name
  image_name="$(echo "${image}" | awk '{print $1}')"
  local image_project
  image_project="$(echo "${image}" | awk '{print $2}')"
  local default_service_account
  default_service_account="$(gcloud iam service-accounts list | grep '\-compute@developer.gserviceaccount.com' | awk 'BEGIN {FS="  "}; {print $2}')"
  shift
  (set -x; gcloud compute instances create $(echo $@ | sed "s/[^ ]* */${GUSER}-&/g") \
    --labels owner="${GUSER}" \
    --machine-type=n1-standard-4 \
    --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE \
    --service-account="${default_service_account}" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --image="${image_name}" --image-project="${image_project}" \
    --boot-disk-size=200GB --boot-disk-type=pd-standard \
    --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any)
}

gdelete() {
  local usage="Usage: gdelete [INSTANCE_NAMES]"
  local instance_name_prefix=""
  if [ -n "$1" ]; then
    instance_name_prefix="${GUSER}-$1"
  fi
  if ! gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep RUNNING | grep -q "^${instance_name_prefix}" ; then echo "no instances match pattern \"^${instance_name_prefix}\""; echo "${usage}" return 1; fi
  gcloud compute instances delete --delete-disks=all $(gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep RUNNING | grep "^${instance_name_prefix}" | awk '{print $1}' | xargs echo)
}

gonline() {
  local usage="Usage: gonline [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance
  for instance in "$@"; do
    local instance_name_prefix="${GUSER}-${instance}"
    (set -x; gcloud compute instances add-access-config "${instance_name_prefix}" --access-config-name="external-nat")
  done
}

gairgap() {
  local usage="Usage: gairgap [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance
  for instance in "$@"; do
    local instance_name_prefix="${GUSER}-${instance}"
    local access_config_name
    access_config_name="$(gcloud compute instances describe "${instance_name_prefix}" --format="value(networkInterfaces[0].accessConfigs[0].name)")"
    (set -x; gcloud compute instances delete-access-config "${instance_name_prefix}" --access-config-name="${access_config_name}")
  done
}

gssh() {
  local usage="Usage: gssh [INSTANCE_NAME]"
  if [ "$#" -ne 1 ]; then echo "${usage}"; return 1; fi
  local instance_name_prefix="${GUSER}-$1"
  while true; do
    start_time="$(date -u +%s)"
    gcloud compute ssh --tunnel-through-iap "${instance_name_prefix}"
    end_time="$(date -u +%s)"
    elapsed="$(bc <<<"$end_time-$start_time")"
    if [ "${elapsed}" -gt "60" ]; then # there must be a better way to do this
      return
    fi
    sleep 2
  done
}

gdisk() {
  local usage="Usage: gdisk [DISK_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  (set -x; gcloud compute disks create $(echo $@ | sed "s/[^ ]* */${GUSER}-disk-&/g") \
    --labels owner="${GUSER}" \
    --type=pd-balanced --size=100GB)
}

gattach() {
  local usage="Usage: gattach [INSTANCE_NAME] [DISK_NAME]"
  if [ "$#" -ne 2 ]; then echo "${usage}"; return 1; fi
  local instance_name_prefix="${GUSER}-$1"
  local disk_name_prefix="${GUSER}-disk-$2"
  local device_name_prefix="${GUSER}-$1-disk-$2"
  (set -x; gcloud compute instances attach-disk "${instance_name_prefix}" --disk="${disk_name_prefix}" --device-name="${device_name_prefix}")
}

gtag() {
  local usage="Usage: gattach [INSTANCE_NAME] [comma-delimited list of TAGS]"
  if [ "$#" -ne 2 ]; then echo "${usage}"; return 1; fi
  local instance_name_prefix="${GUSER}-$1"
  local tags="$2"
  (set -x; gcloud compute instances add-tags "${instance_name_prefix}" --tags="${tags}")
}
