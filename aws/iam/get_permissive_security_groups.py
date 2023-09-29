import boto3
from botocore.exceptions import ClientError

import sys
import getopt
import jmespath
import json

def usage():
    print "get_permissive_security_groups.py [ --aws-profile=myprofile ] --public-only='no'|'yes'"


class EC2:

    def __init__(self,profile=None,region='eu-west-1'):
        session = boto3.Session(profile_name=profile)
        self.client = session.client('ec2', region_name=region)
        self.resource = session.resource('ec2',region_name=region)

    def check_all_sg(self):
        paginator = self.client.get_paginator('describe_security_groups')
        pages = paginator.paginate()

        badSecurityGroups = []

        sgs = []
        # Loop on the Security Groups
        for page in pages:
            sgs = sgs + page['SecurityGroups']
        for sg in sgs:
            bad = False
            # Loop on Ip Permissions
            for permission in sg['IpPermissions']:

                # Check only where the port is not specified port or not HTTP(S) ports
                if (('ToPort' in permission and permission['ToPort'] != 80 and permission['ToPort'] != 443)
                        or ('ToPort' not in permission)):

                    # Loop on IpRanges
                    for iprange in permission['IpRanges']:
                        if 'CidrIp' in iprange and iprange['CidrIp'] == '0.0.0.0/0':
                            bad = True
                            break
                if bad:
                    break

            if bad:
                badSecurityGroups.append(sg['GroupId'])

        return badSecurityGroups

    def get_instances_per_sgs(self,sgs,public_only=True):
        paginator = self.client.get_paginator('describe_instances')
        if public_only is True:
            filters = [{
                'Name': 'instance.group-id',
                'Values': sgs
            },
                {
                    'Name': 'network-interface.addresses.association.public-ip',
                    'Values': ['*']
                }

            ]
        else:
            filters = [{
                'Name': 'instance.group-id',
                'Values': sgs
            }]

        ids = []
        pages = paginator.paginate(Filters=filters)
        for page in pages:
            if len(page['Reservations']) > 0:
                ids = ids + jmespath.search('[*].Instances[0].InstanceId', page['Reservations'])
        return ids

if __name__ == '__main__':

    aws_profile = None

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hi:p:", ["help","public-only=","aws-profile="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        usage()
        sys.exit(2)

    public_only = True

    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-i", "--public-only"):
            if a in [ "no", "n", "No", "N", "NO", "false", "False" ]:
                public_only = False
        elif o in ("-p", "--aws-profile"):
            aws_profile = a
        else:
            assert False, "unhandled option"
            usage()
            sys.exit(2)



    # Get all regions (working with ec2)
    regions = []

    session = boto3.Session(profile_name=aws_profile)
    client = session.client('ec2', region_name='eu-west-1')
    response = client.describe_regions()
    for region in response['Regions']:
        regions.append(region['RegionName'])

    # Variable to get all bad security groups

    reports = []
    # Loop on region
    for region in regions:
        ec2 = EC2(aws_profile,region)
        report = dict()
        report['Region'] = region
        report['GroupsId'] = ec2.check_all_sg()
        report['InstancesId'] = ec2.get_instances_per_sgs(report['GroupsId'], public_only)
        reports.append(report)
    print(json.dumps(reports))