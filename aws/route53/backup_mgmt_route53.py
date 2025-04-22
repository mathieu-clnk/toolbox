#!/usr/bin/python

import boto3
import json
import jmespath
import sys,getopt

def usage():
    print("backup_mgmt_route53.py --action='backup-zone'|'restore-zone'|'delete-zone' --zone='ZONEID' --file=file [ --profile=myprofile ] [ --region=eu-west-1 ] ")

class Route53:

    def __init__(self,zone,profile=None,region='eu-west-1'):
        self.zone = zone
        session = boto3.Session(profile_name=profile)
        self.client = session.client('route53', region_name=region)


    def get_records(self):
        paginator = self.client.get_paginator('list_resource_record_sets')
        page_iterator = paginator.paginate(HostedZoneId=self.zone)
        records = []
        for page in page_iterator:
            records = records + page['ResourceRecordSets']
        return records

    def backup_records(self,output):
        f = open(output, "w")
        f.write(json.dumps(self.get_records(), indent=4))
        f.close()

    def set_record(self,record,action):
        self.client.change_resource_record_sets(HostedZoneId=self.zone,
                                                ChangeBatch={
                                                    'Comment': 'Route53 restore',
                                                    'Changes': [
                                                        {
                                                            'Action': action,
                                                            'ResourceRecordSet': record
                                                        }
                                                        ]
                                                })


    def restore_records(self,input):
        with open(input) as record_file:
            data = json.load(record_file)
            for record in data:
                self.set_record(record,'UPSERT')

    def delete_records(self,input):
        with open(input) as record_file:
            data = json.load(record_file)
            for record in data:
                if record['Type'] not in [ 'NS' , 'SOA' ]:
                    self.set_record(record,'DELETE')

    def delete_zone(self,input):
        self.delete_records(input)
        self.client.delete_hosted_zone(Id=zone)

if __name__ == '__main__':
    """ In this main function, we are fetching the users from IAM and passing the username to access_key() """

    profile = None
    region = "eu-west-1"
    action = None
    zone = None
    file = None

    try:
        opts, args = getopt.getopt(sys.argv[1:], "ha:f:r:p:z:", ["help","action=", "file=", "region=","profile=","zone="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print(str(err))  # will print something like "option -a not recognized"
        usage()
        sys.exit(2)


    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-r", "--region"):
            region = a
        elif o in ("-z", "--zone"):
            zone = a
        elif o in ("-a", "--action"):
            action = a
        elif o in ("-f", "--file"):
            file = a
        elif o in ("-p", "--profile"):
            profile = a
        else:
            assert False, "unhandled option"
            usage()
            sys.exit(2)

    if action is None or zone is None or file is None:
        usage()
        sys.exit(1)

    route53 = Route53(zone, profile, region)

    if action == 'backup-zone':
        route53.backup_records(file)
    elif action == 'restore-zone':
        route53.restore_records(file)
    elif action == 'delete-zone':
        route53.delete_zone(file)
    else:
        usage()
        sys.exit(3)