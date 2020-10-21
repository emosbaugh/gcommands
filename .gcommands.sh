# GPREFIX=

gcreate() {
  local usage="Usage: gcreate [IMAGE] [INSTANCE_NAMES]"
  if [ "$#" -lt 2 ]; then echo $usage; return 1; fi
  local image="$(gcloud compute images list | grep $1 | awk 'NR == 1')"
  if [ -z "$image" ]; then image="$(gcloud compute images list --show-deprecated | grep $1 | awk 'NR == 1')"; fi
  if [ -z "$image" ]; then echo "gcreate: unknown image $image"; echo $usage; return 1; fi
  local image_name="$(echo $image | awk '{print $1}')"
  local image_project="$(echo $image | awk '{print $2}')"
  local default_service_account="$(gcloud iam service-accounts list | grep '\-compute@developer.gserviceaccount.com' | awk 'BEGIN {FS="  "}; {print $2}')"
  shift
  (set -x; gcloud beta compute --project=replicated-qa instances create $(echo $@ | sed "s/[^ ]* */${GPREFIX}&/g") \
    --zone=us-west1-b --machine-type=n1-standard-4 \
    --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE \
    --service-account=$default_service_account \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --image=$image_name --image-project=$image_project \
    --boot-disk-size=200GB --boot-disk-type=pd-standard \
    --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any)
}

gdelete() {
  local usage="Usage: gdelete [INSTANCE_NAME_PREFIX]"
  instance_name_prefix=$GPREFIX$1
  if [ -z "$(gcloud compute instances list | awk '{if(NR>1)print}' | grep RUNNING | grep "^$instance_name_prefix")" ]; then echo "no instances match pattern \"^$instance_name_prefix\""; echo $usage return 1; fi
  gcloud compute instances delete $(gcloud compute instances list | awk '{if(NR>1)print}' | grep RUNNING | grep "^$instance_name_prefix" | awk '{print $1}' | xargs echo)
}

gonline() {
  local usage="Usage: gonline [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo $usage; return 1; fi
  (set -x; gcloud compute instances add-access-config $1 --access-config-name="external-nat")
}

gairgap() {
  local usage="Usage: gairgap [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo $usage; return 1; fi
  local access_config_name="$(gcloud compute instances describe $1 --format="value(networkInterfaces[0].accessConfigs[0].name)")"
  (set -x; gcloud compute instances delete-access-config $1 --access-config-name="$access_config_name")
}

gssh() {
  local usage="Usage: gssh [INSTANCE_NAME]"
  if [ "$#" -ne 1 ]; then echo $usage; return 1; fi
  while true; do
    start_time="$(date -u +%s)"
    gcloud compute ssh --tunnel-through-iap $1
    end_time="$(date -u +%s)"
    elapsed="$(bc <<<"$end_time-$start_time")"
    if [ "$elapsed" -gt "60" ]; then # there must be a better way to do this
      return
    fi
    sleep 2
  done
}
