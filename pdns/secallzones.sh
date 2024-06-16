#!/bin/bash -e

echo "[`date +"%T"`] Secallzones starting... "
ZONES=`pdnsutil list-all-zones | grep -v "All zonecount"`
while read -r d; do
  domaininfo="$(pdnsutil show-zone "$d")"

  printf "%s: " "$d"

  # do not sign or attempt to resign slave zones
  if [[ "$domaininfo" =~ "Slave zone" ]]; then
    echo "slave zone, skipping"
    continue
  fi
 
  if [[ "$domaininfo" =~ "Zone is presigned" ]]; then
    # not a slave zone, remove presigned flag
    pdnsutil unset-presigned "$d"
    printf "presigned flag removed, "
  elif ! [[ "$domaininfo" =~ "not actively secured" ]]; then
    # this is already secured, skip
    echo "already secured, skipping."
    continue
  fi

  pdnsutil secure-zone "$d"
  pdnsutil rectify-zone "$d"
  fixdsrrs.sh -d "$d"
  echo "secured."
done <<< "$ZONES"
echo "[`date +"%T"`] Secallzones finished."
