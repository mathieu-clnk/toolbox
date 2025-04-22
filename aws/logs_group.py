import boto3
import yaml
import os.path
import argparse
import json

default_retention_days=30

class YMLDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(YMLDumper, self).increase_indent(flow, False)

class Cloudwatch:
    @staticmethod
    def getLogGroups(fileName):
        result = {}
        result['logGroups']=[]
        try:
            client = boto3.client('logs')
            response = client.describe_log_groups()
            for logs in response['logGroups']:
                retention = logs.get('retentionInDays','Never Expire')
                resp = client.list_tags_log_group(logGroupName=logs['logGroupName'])
                if not resp['tags']:
                    result['logGroups'].append({'logGroupName':logs['logGroupName'],'retentionInDays':retention})
                else:
                    tags = [{x:resp['tags'][x]} for x in resp['tags'] ]
                    result['logGroups'].append({'logGroupName':logs['logGroupName'],'retentionInDays':retention,'tags':tags})
            with open(fileName, 'w') as file:
                documents = yaml.dump(result, file,Dumper=YMLDumper, default_flow_style=False)
            print(f'successfully generated output file: {fileName}')
        except Exception as e:
            print(e)

    @staticmethod
    def setLogGroups(retention_days,inputFile):
        try:
            client = boto3.client('logs')
            if os.path.exists(inputFile):
                if os.path.getsize(inputFile) > 0:
                    with open(inputFile) as file:
                        input_log_groups =  yaml.safe_load(file)
                    for log in input_log_groups['logGroups']:
                        input_retention = log.get('retentionInDays')
                        SetTags = log.get('tags')
                        if input_retention is not None and isinstance(input_retention, int):
                            res = client.put_retention_policy(logGroupName=log['logGroupName'],retentionInDays=input_retention)
                        else:
                            res = client.put_retention_policy(logGroupName=log['logGroupName'],retentionInDays=retention_days)
                        if SetTags is not None:
                            tag = {k:v for d in SetTags for k, v in d.items()}
                            r = client.tag_log_group(logGroupName=log['logGroupName'],tags=tag)
                    print("Successfully set retention policy!!")
                else:
                    print("setting retention policy on never expire log groups.")
                    client = boto3.client('logs')
                    log_groups = client.describe_log_groups()
                    for log_group in log_groups['logGroups']:
                        input_retention_days = log_group.get('retentionInDays')
                        if input_retention_days is None:
                            res = client.put_retention_policy(logGroupName=log_group['logGroupName'],retentionInDays=retention_days)
            else:
                print("Input file doesn't exist.")
        except Exception as e:
            print(e)

    @staticmethod
    def setDefaultLogGroups(retention_days,aws_tags):
        try:
            print("setting retention policy on never expire log groups.")
            client = boto3.client('logs')
            log_groups = client.describe_log_groups()
            for log_group in log_groups['logGroups']:
                input_retention_days = log_group.get('retentionInDays')
                if input_retention_days is None:
                    res = client.put_retention_policy(logGroupName=log_group['logGroupName'],retentionInDays=retention_days)
                    print(f"Successfully set retention policy for {log_group['logGroupName']}!!")
                for aws_tag in aws_tags:
                    r = client.tag_log_group(logGroupName=log_group['logGroupName'], tags=aws_tag)
                print(f"Successfully set tags for {log_group['logGroupName']}!!")

        except Exception as e:
            print(e)


# Initialize parser
parser = argparse.ArgumentParser(prog='AWS Cloudwatch loggroup operations')
parser.add_argument("action",  nargs='?',default="get")
parser.add_argument("-o", "--Output", default="default.yml",help = "Output YML file name.")
parser.add_argument("-i", "--Input", help = "Input YML file absolute path.",default='')
parser.add_argument("-r", "--default-retention",help = "loggroups default retention days.", type=int,default=default_retention_days)
parser.add_argument("-t", "--Tags",help = "Tags Json.", default="")

args = parser.parse_args()
if args.action== "set":
    Cloudwatch.setLogGroups(args.default_retention,args.Input)
elif args.action== "set-default":
    Cloudwatch.setDefaultLogGroups(args.default_retention,json.loads(args.Tags))
else :
    Cloudwatch.getLogGroups(args.Output)