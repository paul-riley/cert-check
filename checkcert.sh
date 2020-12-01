#!/usr/bin/env bash

###################################
#  Paul Riley
#  paul.riley@puppet.com
#
#  Checks certs locally and remotely using API calls for Puppet Enterprise Master
#  11/30/2020
###################################

### data to be analyzed and params to change ###

maximumCertAge=30

notifyEmail=""

localCertArray=( "/etc/puppetlabs/client-tools/ssl/certs/ca.pem"
            "/etc/puppetlabs/puppet/ssl/certs/ca.pem")

urlArray=(  "puppet.classroom.puppet.com"
            "prileydevnix0.classroom.puppet.com"
            "prileydevwin0.classroom.puppet.com")

peMaster="prileydevmaster0.classroom.puppet.com:8140"

### business logic in script ###

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
    daysExpString=$(printf '%0d' $daysToExpiration)
    expiringCertArray+=("$cert:$daysExpString")
    echo "ERROR! Cert:" $cert "is expiring in" $daysExpString "days"
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
    daysExpString=$(printf '%0d' $daysToExpiration)
    expiringCertArray+=("$cert:$daysExpString")
    echo "ERROR! Cert:" $cert "is expiring in" $daysExpString "days"
  else
    echo "Cert:" $cert "is NOT expiring within" $maximumCertAge "days"
  fi
done


if (( ${#expiringCertArray[@]} ))
then
  echo "There are errors lets log and possibly email them."
  emailText=$'The following certs exipire within 30 days. Please take action!\n\n'
  for expCert in ${expiringCertArray[@]}
  do
    logger "ERROR! Puppet Certficate expires for ${expCert} days from NOW!"

    emailText+="Certifcate expires for ${expCert} days from NOW!"
    emailText+=$'\n'

  done
  if [[ ! -z "$notifyEmail" ]]
  then
    echo ${emailText} > tmp-email.txt
    sendmail $notifyEmail < tmp-email.txt
    rm tmp-email.txt
  fi
else
  echo "No certificate errors"
fi
