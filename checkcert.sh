#!/usr/bin/env bash

### data to be analyzed and params to change ###

maximumCertAge=30
notifyEmail="test@notanemail.com"

localCertArray=( "/etc/puppetlabs/client-tools/ssl/certs/ca.pem"
            "/etc/puppetlabs/puppet/ssl/certs/ca.pem")

urlArray=(  "puppet.classroom.puppet.com"
            "prileydevnix0.classroom.puppet.com"
            "prileydevwin0.classroom.puppet.com")

peMaster="prileydevmaster0.classroom.puppet.com:8140"


### core of script ###

currentDateSec=$(date +%s)


expiringCertArray=()

for cert in "${localCertArray[@]}"
do
  echo -e "\nValidating:" $cert"\n"

  certDate=$(cat $cert |openssl x509 -noout -enddate |sed 's/notAfter=//')
  echo "Cert Date is" $certDate
  certDateSec=$(date -d "${certDate}" +%s)
  echo "Cert Date seconds are" $certDateSec
  daysToExpiration=$(( ($certDateSec - $currentDateSec) / 86400 ))
  echo "Difference in Days is" $daysToExpiration

  if (($daysToExpiration < $maximumCertAge))
  then
    expiringCertArray+=("$cert:$dateDiffDays")
    echo "ERROR! Cert:" $cert "is expiring within" $maximumCertAge "days"
  else
    echo "Cert:" $cert "is NOT expiring within" $maximumCertAge "days"
  fi
done


for cert in "${urlArray[@]}"
do
  echo -e "\nValidating:" $cert"\n"

  curl -k --request GET "https://$peMaster/puppet-ca/v1/certificate/$cert" --header 'Content-Type: text/plain' > tmp-$cert.pem

  certDate=$(cat tmp-$cert.pem |openssl x509 -noout -enddate |sed 's/notAfter=//')
  echo "Cert Date is" $certDate
  certDateSec=$(date -d "${certDate}" +%s)
  echo "Cert Date seconds are" $certDateSec
  daysToExpiration=$(( ($certDateSec - $currentDateSec) / 86400 ))
  echo "Difference in Days is" $daysToExpiration
  rm tmp-$cert.pem

  if (($daysToExpiration < $maximumCertAge))
  then
    expiringCertArray+=("$cert:$dateDiffDays")
    echo "ERROR! Cert:" $cert "is expiring within" $maximumCertAge "days"
  else
    echo "Cert:" $cert "is NOT expiring within" $maximumCertAge "days"
  fi
done


if (( ${#expiringCertArray[@]} ))
then
  echo "There are errors lets log and possibly email them."
  for expCert in ${expiringCertArray[@]}
  do
    echo "Cert has expired for:" $expCert
  done
else
  echo "There are no errors"

fi
