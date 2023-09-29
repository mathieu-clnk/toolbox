import boto3
import os

def lambda_handler(event,context):
    try:
        items={}
        items['vpn']=[]
        sns=boto3.client('sns')

        ec2client = boto3.client('ec2')

        for vpn in event['vpns']:
            # Get VPN status

            response = ec2client.describe_vpn_connections(
                Filters=[
                    {
                        'Name': 'tag:Name',
                        'Values': [
                            vpn['name'],
                        ]
                    },
                ],
            )

            # Count number of active tunnels
            up = 0
            for tunnel in response.get('VpnConnections')[0].get('VgwTelemetry'):
                if tunnel.get('Status') == 'UP':
                    up += 1

            if up < int(vpn['active_tunnels']):
                items['vpn'].append(str('VPN: '+vpn['name']+' shall have '+vpn['active_tunnels']+' tunnels but only '+str(up)+' is active'))
        newlist="\n".join(items['vpn'])
        if len(items['vpn'])>0:
            response=sns.publish(
                TopicArn=event['topic'],
                Message='Critical - tunnels are DOWN: \n %s' %newlist,
                Subject='Alarm for VPN tunnels',
                )
    except Exception as e:
        print(e)
