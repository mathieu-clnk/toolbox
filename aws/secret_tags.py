import boto3
import yaml
import json
import os.path
import argparse


class YMLDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(YMLDumper, self).increase_indent(flow, False)

class Secrets:
    @staticmethod
    def set_tag_secrets(inputFile):
        try:
            client = boto3.client('secretsmanager')
            if os.path.exists(inputFile):
                if os.path.getsize(inputFile) > 0:
                    with open(inputFile) as file:
                        input_tags =  yaml.safe_load(file)
                    for secrets in input_tags['aws_secrets']:
                        tags=secrets.get('tags',None)
                        if tags is not None:
                            for tag in tags:
                                response = client.tag_resource(
                                    SecretId=secrets['name'],
                                    Tags=[
                                        {
                                            'Key': tag,
                                            'Value': tags[tag]
                                        },
                                    ]
                                )
                            print("Sucessfully added tags in",secrets['name'])
                        else:
                            print("No tags in",secrets['name'])
            else:
                print("Input file doesn't exist.")
        except Exception as e:
            print(e)

    @staticmethod
    def get_list_secrets(fileName):
        result = {}
        result['aws_secrets']=[]
        try:
            client = boto3.client('secretsmanager')
            paginator= client.get_paginator("list_secrets")
            secrets_iterator = paginator.paginate()
            for secrets in secrets_iterator:
                for secret in secrets['SecretList']:
                    if "Tags" in secret.keys() and len(secret['Tags']) > 0:
                        tags={x['Key']:x['Value'] for x in secret['Tags']}
                        result['aws_secrets'].append({'name': secret['Name'], 'tags': tags})
                    else:
                        result['aws_secrets'].append({'name': secret['Name']})
            with open(fileName, 'w') as file:
                documents = yaml.dump(result, file,Dumper=YMLDumper, default_flow_style=False)
            print("Sucessfully get tags")
        except Exception as e:
            print("An error occured: ")
            print(e)

    @staticmethod
    def set_default_tags_secrets(tags):
        result = {}
        result['aws_secrets']=[]
        try:
            client = boto3.client('secretsmanager')
            paginator= client.get_paginator("list_secrets")
            secrets_iterator = paginator.paginate()
            for secrets in secrets_iterator:
                for secret in secrets['SecretList']:
                    if not "Tags" in secret.keys() or len(secret['Tags']) < 1:
                            print('add tags for %s' % secret['Name'])
                            response = client.tag_resource(
                                SecretId=secret['Name'],
                                Tags=tags
                                )
            print("Sucessfully set default tags")
        except Exception as e:
            print("An error occured: ")
            print(e)

# Initialize parser
parser = argparse.ArgumentParser(prog='AWS Secret tagging operation')
parser.add_argument("action",  nargs='?',default="get")
parser.add_argument("-o", "--Output", default="default.yml",help = "Output YML file name.")
parser.add_argument("-i", "--Input",help = "Input YML file name.", default="")
parser.add_argument("-t", "--Tags",help = "Tags Json.", default="")

args = parser.parse_args()


if args.action== "set":
    Secrets.set_tag_secrets(args.Input)
elif args.action== "set-default":
    aws_tags = []
    for tag in json.loads(args.Tags):
        for k in tag.keys():
            obj = { "Key" : k , "Value" : tag[k] }
            aws_tags.append(obj)
    Secrets.set_default_tags_secrets(aws_tags)
elif args.action== "get":
    Secrets.get_list_secrets(args.Output)
