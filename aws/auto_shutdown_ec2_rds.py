# to exceute the script to stop ec2 and rds : python3 auto_shutdown_ec2_rds.py
# to update_tags : python3 auto_shutdown_ec2_rds.py stop_tags -instance=instance_name/application_tag_value -stopdate=20210622 -jiraticket=AOE-176
import boto3
import datetime
import argparse
import os

class Shutdown_ec2_rds:
    @staticmethod
    def stop_instances(profile):
        try:
            session=boto3.Session(profile_name=profile)
            ec2_resource = session.resource('ec2')
            ec2=session.client('ec2')
            rds=session.client('rds')
            now=datetime.date.today().strftime('%Y%m%d')
            for instance in ec2_resource.instances.all():
                ec2_stop=True
                instance_name = None
                if instance.tags!=None:
                    for tag in instance.tags:
                        if tag['Key']=='stop-exception':
                            if tag['Value']>now:
                                ec2_stop=False
                            if tag['Key'] == 'Name':
                                instance_name = tag['Value']
                if ec2_stop==True:
                    response=ec2.stop_instances(
                        InstanceIds=[
                            instance.id
                        ]
                    )
                    for state in response['StoppingInstances']:
                        if state['PreviousState']['Name']=='stopped':
                            print('Instance id ',instance.id,' name: ',instance_name,' is already stopped')
                        elif state['CurrentState']['Name']=='stopping':
                            print(instance.id," name: ",instance_name,"stopping succesfully")
            rds_instance=rds.describe_db_instances()
            for rds_tags in rds_instance['DBInstances']:
                rds_stop=True
                instance_name = None
                for rds_tag in rds_tags['TagList']:
                    if rds_tag['Key']=='stop-exception':
                        if rds_tag['Value']>now:
                            rds_stop=False
                        if tag['Key'] == 'Name':
                            instance_name = tag['Value']
                if rds_tags['DBInstanceStatus']!='Available':
                   rds_stop=False
                if rds_stop==True:        
                    result = rds.stop_db_instance(
                        DBInstanceIdentifier=rds_tags['DBInstanceIdentifier']
                    )
                    if result['DBInstance']['DBInstanceStatus']=='stopping':
                        print(rds_tags['DBInstanceIdentifier'],' name: ',instance_name,'stopping successfully')
        except Exception as e:
            print(e)

    @staticmethod
    def tags_update(instance_name,**kwargs):
        try:
            stop_date = kwargs.get('stop_date', None)
            jira_ticket = kwargs.get('jira_ticket', None)
            session=boto3.Session(profile_name=kwargs.get('profile', None))
            ec2=session.client('ec2')
            ec2_resource = session.resource('ec2')
            rds=session.client('rds')
            for instance in ec2_resource.instances.all():
                update_ec2=False
                for tag in instance.tags:
                    if tag['Key']=='Name':
                        if tag['Value']==instance_name:
                            update_ec2=True
                    elif tag['Key']=='application':
                        if tag['Value']==instance_name:
                            update_ec2=True
                if update_ec2==True:
                    if stop_date != '':
                        response=ec2.create_tags(
                            Resources=[
                                instance.id,
                            ],
                            Tags=[
                                {
                                    'Key': 'stop-exception',
                                    'Value': stop_date,
                                },
                            ]
                        )
                        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
                            print('Updated stop-exception tag for',instance.id)
                    if jira_ticket is not None:
                        response=ec2.create_tags(
                            Resources=[
                                instance.id,
                            ],
                            Tags=[
                                {
                                    'Key': 'jira-stop-exception',
                                    'Value': jira_ticket,
                                },
                            ]
                        )
                        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
                            print('Updated jira-stop-exception tag for',instance.id)
            rds_instance=rds.describe_db_instances()
            for db in rds_instance['DBInstances']:
                update_rds=False
                if db['DBInstanceIdentifier']==instance_name:
                    update_rds=True
                for rds_tag in db['TagList']:
                    if rds_tag['Key']=='application':
                        if rds_tag['Value']==instance_name:
                            update_rds=True
                if update_rds==True:
                    if stop_date != '':
                        result = rds.add_tags_to_resource(
                            ResourceName=db['DBInstanceArn'],
                            Tags=[
                                {
                                    'Key': 'stop-exception',
                                    'Value': stop_date
                                },
                            ]
                        )  
                        if result['ResponseMetadata']['HTTPStatusCode'] == 200:
                            print('Updated stop-exception tag for',db['DBInstanceIdentifier']) 
                    if jira_ticket is not None:
                        result = rds.add_tags_to_resource(
                            ResourceName=db['DBInstanceArn'],
                            Tags=[
                                {
                                    'Key': 'jira-stop-exception',
                                    'Value': jira_ticket
                                },
                            ]
                        )
                        if result['ResponseMetadata']['HTTPStatusCode'] == 200:
                            print('Updated jira-stop-exception tag for',db['DBInstanceIdentifier'])
        except Exception as e:
            print(e)
# initialize Parser
parser=argparse.ArgumentParser(prog='AWS EC2 and RDS Shutdown operation')
parser.add_argument("action",nargs='?',default='stop')
parser.add_argument("-stopdate", "--stopDate", default="",help = "Stop Date for tag stop-exception")
parser.add_argument("-instance", "--instance", default="",help = "Instance name/application value to update tag stop-exception")
parser.add_argument("-jiraticket", "--jira", default=None,help = "Jira ticket")
parser.add_argument("-profile", "--profile", default="",help = "Profile name")
parser.add_argument("-region", "--region", default="",help = "region")
args = parser.parse_args()

if args.region is None:
    args.region = os.getenv("AWS_REGION","eu-west-1")

if args.action=='stop':
    Shutdown_ec2_rds.stop_instances(args.profile)
elif args.action=='update_tags':
    Shutdown_ec2_rds.tags_update(args.instance,stop_date=args.stopDate,jira_ticket=args.jira,profile=args.profile)