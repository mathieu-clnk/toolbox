#!/usr/bin/python

import datetime, boto3
import dateutil
import sys, getopt

import json
import jmespath
import os


def usage():
    print("aws_users_ak_check.py --action='get_all_policies'|'get_unused_policies'|'get_direct_attached_policies' [ --aws-profile=myprofile ] [ --aws-region=eu-west-1 ] [ --scope='All'|'AWS'|'Local' ] [ --output=folder ]")

class IamPolicies:

    def __init__(self,profile=None,region='eu-west-1'):
        session = boto3.Session(profile_name=profile)
        self.client = session.client('iam', region_name=region)
        self.resource = session.resource('iam',region_name=region)


    def myconverter(o):
        if isinstance(o, datetime.datetime):
            return o.__str__()

    def dump_policy_disk(self,policy_name,policy_content,output):
        print("Write policy arn: %s" % policy_name)
        file_name = policy_name.split('/')[1]
        path = output + '/' + file_name
        f = open(path,"w")
        f.write(json.dumps(policy_content, default = self.myconverter()))
        f.close()

    def get_policies_ids(self,scope):
        paginator = self.client.get_paginator('list_policies')
        page_iterator = paginator.paginate(Scope=scope)
        policies_ids = []
        for page in page_iterator:
            policies_ids = policies_ids + jmespath.search('[*].Arn', page['Policies'])
        return policies_ids

    def get_policy_content(self,arn):
        policy = self.resource.Policy(arn)
        return policy.default_version.document

    def get_policies_content(self,list,output=None):
        policies = []
        for arn in list:
            policy_content = self.get_policy_content(arn)
            if output is None:
                policies.append(policy_content)
            else:
                self.dump_policy_disk(arn,policy_content,output)
        return policies

    def get_all_policies(self, scope='Local',output=None):
        return self.get_policies_content(self.get_policies_ids(scope),output)

    def get_all_attached_policies(self,username):
        paginator = self.client.get_paginator('list_attached_user_policies')
        page_iterator = paginator.paginate(UserName=username)
        policies_arn = []
        for page in page_iterator:
            policies_arn = policies_arn + jmespath.search('[*].PolicyArn', page['AttachedPolicies'])
        return policies_arn

    def get_unused_policies(self):
        paginator = self.client.get_paginator('list_policies')
        page_iterator = paginator.paginate(Scope=scope)
        unused_policies_ids = []
        for page in page_iterator:
            unused_policies_ids = unused_policies_ids + jmespath.search('[?AttachmentCount==`0`].Arn', page['Policies'])
        return unused_policies_ids

    def get_all_user_name(self):
        paginator = self.client.get_paginator('list_users')
        page_iterator = paginator.paginate()
        user_names = []
        for page in page_iterator:
            user_names = user_names + jmespath.search('[*].UserName', page['Users'])
        return user_names

    def get_direct_attached_policies(self):
        policies_users = dict()
        for user in self.get_all_user_name():
            policies_users[user] = self.get_all_attached_policies(user)
        return policies_users

if __name__ == '__main__':
    """ In this main function, we are fetching the users from IAM and passing the username to access_key() """

    aws_profile = None
    aws_region = "eu-west-1"
    action = None
    scope = 'Local'
    output = None

    try:
        opts, args = getopt.getopt(sys.argv[1:], "ha:s:t:o:p:", ["help","aws-region=", "scope=", "action=","output=","aws-profile="])
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
        elif o in ("-a", "--aws-region"):
            aws_region = a
        elif o in ("-s", "--scope"):
            scope = a
        elif o in ("-t", "--action"):
            action = a
        elif o in ("-o", "--output"):
            output = a
        elif o in ("-p", "--aws-profile"):
            aws_profile = a
        else:
            assert False, "unhandled option"
            usage()
            sys.exit(2)

    if action is None:
        usage()
        sys.exit(1)

    iam_policies = IamPolicies(aws_profile, aws_region)

    if output is not None and not os.path.exists(output):
        os.mkdir(output)

    if action == 'get_all_policies':
        if output is None:
            print(iam_policies.get_all_policies(scope,output))
        else:
            iam_policies.get_all_policies(scope,output)
    elif action == 'get_unused_policies':
        print(iam_policies.get_unused_policies())
    elif action == 'get_direct_attached_policies':
        print(iam_policies.get_direct_attached_policies())
    else:
        usage()
        sys.exit(3)

