#!/bin/bash
# Get current and new IP address entry in AWS security group
# Clear variables

set -x

#PATH=/home/nathan/.local/bin:/home/nathan/.local/bin:/home/nathan/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/home/nathan/terraform:/home/nathan/.local/bin/aws

clearvar() {
        CURRENTIP="" NEWIP="" OLDIPINFO=""
}

CURRENTIP=`aws ec2 describe-security-groups --group-id sg-0177ff950373f57da |grep 'pihole access'|awk '{print $2}'|head -1`
NEWIP=`curl -X GET "https://api.cloudflare.com/client/v4/zones/212e54119a66dc835b5138db1929dd46/dns_records/01913c532b52c894ab874678ddb0b49d" \
-H "X-Auth-Email: pheistman@live.co.uk" \
-H "X-Auth-Key: ccd9ce6cff57c2cdb2a5c302f1aa7816a1bb5" \
-H "Content-Type: application/json"  \
--data '{"type":"A","name":"blowtorch.xyz"}'|tr "," "\n"|grep content|tr -d '"'|cut -c 9-`

# function to add new IP address entry in AWS security group
addip() {
    aws ec2 authorize-security-group-ingress \
    --group-id sg-0177ff950373f57da \
    --ip-permissions IpProtocol=tcp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${NEWIP}/32',Description="pihole access from home IP only"}]'  \
      IpProtocol=udp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${NEWIP}/32',Description="pihole access from home IP only"}]'
}

# function to delete current IP address entry in AWS security group
delip() {
    aws ec2 revoke-security-group-ingress \
    --group-id sg-0177ff950373f57da \
    --ip-permissions IpProtocol=tcp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${CURRENTIP}',Description="pihole access from home IP only"}]'  \
      IpProtocol=udp,FromPort=53,ToPort=53,IpRanges='[{CidrIp='${CURRENTIP}',Description="pihole access from home IP only"}]'
}

if [ "$CURRENTIP" == "0.0.0.0/0" ]; then
    echo "$(date) Adding new IP info" > ~/awslog.txt
    addip
    #echo -e  "Subject: AWS pihole security group added home IP address" > ./secupdate.txt
    #/usr/sbin/ssmtp -v eapreko@icloud.com < ./secupdate.txt
elif [ "$CURRENTIP" !=  "$NEWIP/32" ]; then
    echo "$(date) Deleting and adding new IP info" > ~/awslog.txt
    delip
    addip
    OLDIPINFO=`aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RevokeSecurityGroupIngress|tr "," "\n"|egrep -i "eventTime|eventName|ipRanges"|head -3|tr -d '"'`
    #echo -e "Subject: UPDATED - AWS pihole security group updated home IP address\n\n$OLDIPINFO\n\n$NEWIP" > ./secupdate.txt
    #/usr/sbin/ssmtp -v eapreko@icloud.com < ./secupdate.txt
else [ "$CURRENTIP" == "$NEWIP/32" ]
    echo "$(date) Nothing to do!" > ~/awslog.txt
    #echo -e "Subject:Nothing to do\n\n$(date)\n" > ./secupdate.txt
#    /usr/sbin/ssmtp -v eapreko@icloud.com < ./secupdate.txt
fi
