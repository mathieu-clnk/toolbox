# command to execute script python3 s3_tag.py -i { “map-migrated” : “d-1234567-8910”, “map-migrated-app”: “myapp” } -profile aws_profile_name
# by default the profile for aws is default
import boto3 
from botocore.exceptions import ClientError
import argparse
import yaml
import json

class S3:
    @staticmethod
    def update_tags(tags_param,profile):
        try:
            input_tag=json.loads(tags_param)
            session=boto3.Session(profile_name=profile)
            s3 = session.client('s3')
            response = s3.list_buckets()
            for bucket in response['Buckets']:
                try:
                    bucketTags = s3.get_bucket_tagging(Bucket=bucket['Name'])
                    s3_tags = bucketTags['TagSet']
                    tags = {x['Key']:x['Value'] for x in s3_tags }
                    for input_tag_key in input_tag:
                        if (input_tag_key in tags):
                            print('Tag already exist in ',bucket['Name'])
                        else:
                            s3_tags.append({'Key':input_tag_key, 'Value': input_tag[input_tag_key]})
                            put_tag = s3.put_bucket_tagging(
                                Bucket=bucket['Name'],
                                Tagging={
                                    'TagSet': s3_tags
                                }
                            )
                            if put_tag['ResponseMetadata']['HTTPStatusCode'] == 204:
                                print('succesfully added the missing default',input_tag_key,' in',bucket['Name'])
                except ClientError : #for tags not found
                    print('No tags found in', bucket['Name'])
                    new_tags=[]
                    for input_tag_key in input_tag:
                        new_tags.append({'Key': input_tag_key, 'Value': input_tag[input_tag_key]})
                    put_tag = s3.put_bucket_tagging(
                        Bucket=bucket['Name'],
                        Tagging={
                            'TagSet': new_tags
                        }
                    )
                    if put_tag['ResponseMetadata']['HTTPStatusCode'] == 204:
                        print('succesfully added the missing default',input_tag,' in',bucket['Name'])                             

                except Exception as e:
                    print(e)
        except Exception as e:
            print(e)

# initialize parser
parser=argparse.ArgumentParser(prog='AWS S3 tagging operation')
parser.add_argument("action",  nargs='?',default="get")
parser.add_argument("-i", "--input",help = "Input tag parameters", default="")
parser.add_argument("-profile", "--profile",help = "Input aws profile", default="default")

args=parser.parse_args()

if args.action=='get':
    S3.update_tags(args.input,args.profile)
