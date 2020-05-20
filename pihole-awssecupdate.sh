#!/bin/bash
# Get current and new IP address entry in AWS security group
# Clear variables

set -x

#PATH=/home/nathan/.local/bin:/home/nathan/.local/bin:/home/nathan/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/home/nathan/terraform:/home/nathan/.local/bin/aws

clearvar() {
        CURRENTIP="" NEWIP=""
}

CURRENTIP=`aws ec2 describe-security-groups --group-id sg-0965167f16a94b955 | awk 'NR==7 {print $2}'`
NEWIP=`curl -X GET "https://api.cloudflare.com/client/v4/zones/212e54119a66dc835b5138db1929dd46/dns_records/01913c532b52c894ab874678ddb0b49d" \
-H "X-Auth-Email: pheistman@live.co.uk" \
-H "X-Auth-Key: ccd9ce6cff57c2cdb2a5c302f1aa7816a1bb5" \
-H "Content-Type: application/json"  \
--data '{"type":"A","name":"blowtorch.xyz"}'|tr "," "\n"|grep content|tr -d '"'|cut -c 9-`

# function to add new IP address entry in AWS security group
addip() {
    aws ec2 authorize-security-group-ingress \
    --group-id sg-0965167f16a94b955 \
    --ip-permissions IpProtocol=tcp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${NEWIP}/32',Description="pihole access from home IP only"}]'  \
      IpProtocol=udp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${NEWIP}/32',Description="pihole access from home IP only"}]'
}

# function to delete current IP address entry in AWS security group
delip() {
    aws ec2 revoke-security-group-ingress \
    --group-id sg-0965167f16a94b955 \
    --ip-permissions IpProtocol=tcp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${CURRENTIP}',Description="pihole access from home IP only"}]'  \
      IpProtocol=udp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${CURRENTIP}',Description="pihole access from home IP only"}]'
}

if [ "$CURRENTIP" == "0.0.0.0/0" ]; then
    addip
    echo "Subject: AWS pihole security group added home IP address" | sendmail -v eapreko@icloud.com
elif [ "$CURRENTIP" !=  "$NEWIP/32" ]; then
    delip
    addip
    echo "Subject: UPDATED - AWS pihole security group updated home IP address" | sendmail -v eapreko@icloud.com
else [ "$CURRENTIP" == "$NEWIP/32" ]
    echo "$(date) Nothing to do"
#   echo "Subject: Nothing to do" | sendmail -v  eapreko@icloud.com
fi
