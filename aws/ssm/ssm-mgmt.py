import logging
from pydoc import cli
import time
import botocore
import boto3
import hashlib
import argparse
import sys
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


class Ec2Manager:
    def __init__(self, profile=None, region='eu-west-1'):
        session = boto3.Session(profile_name=profile)
        self.client = session.client('ec2', region_name=region)

    def get_first_instance_id_by_name(self, name):
        filters = [
            {
                'Name': 'tag:Name',
                'Values': [name]
            },
            {
                'Name': 'instance-state-name',
                'Values': ['running']
            }
        ]
        response = self.client.describe_instances(Filters=filters)
        if response == None:
            logger.error("Instance does not exist or is not running.")
            sys.exit(1)
        return response['Reservations'][0]['Instances'][0]['InstanceId']


class DocumentManager:
    def get_json_file(self, file):
        f2 = None
        try:
            with open(file, "rb") as f2:
                res = json.load(f2)

            f2.close()
            return res
        except FileNotFoundError as error:
            logger.error("File %s has not been found." % file)
            raise error
        except Exception as e:
            if f2 != None:
                f2.close()
            raise e

    def get_file_sum(self, file):
        try:
            with open(file, "rb") as f:
                res = json.load(f)
                encoded = json.dumps(res).encode("UTF-8")
                hash = hashlib.sha256(encoded).hexdigest();
                f.close()
                return hash
        except FileNotFoundError as error:
            logger.error("File %s has not been found." % file)
            raise error


class AwsSM:
    def __init__(self, profile=None, region='eu-west-1'):
        session = boto3.Session(profile_name=profile)
        self.client = session.client('ssm', region_name=region)

    def is_document_exists(self, document_name):
        try:
            doc = self.client.get_document(Name=document_name)
            if doc['Name'] == document_name:
                return True
            return False
        except botocore.exceptions.ClientError as error:
            if error.response['Error']['Code'] == 'InvalidDocument':
                return False
            else:
                raise error

    def check_document_latest(self, document_name, file):
        # compare the Json file and the document to see if there is any change.
        document_meta = self.client.describe_document(Name=document_name)
        document_manager = DocumentManager()
        current_sum = document_manager.get_file_sum(file)
        if document_meta['Document']['Hash'] != current_sum:
            logger.info("Document marked to be updated. AWS Document hash: %s, file hash %s" % (
            document_meta['Document']['Hash'], current_sum))
            return False
        return True
        # if jmespath.search("document_meta['Tags']

    def create_document(self, document_name, file):
        # create the AWS SSM document and set as the latest version
        logger.info('The document %s does not exist. A new document is going to be created.' % document_name)
        document_manager = DocumentManager()
        file_content = document_manager.get_json_file(file)
        result = self.client.create_document(Content=json.dumps(file_content), Name=document_name,
                                             DocumentType='Command')
        if result == None:
            logger.error("Cannot create the document %s with the file %s" % (document_name, file))
            sys.exit(1)
        logger.info("Document %s created successfully." % document_name)

    def update_document(self, document_name, file):
        if not self.check_document_latest(document_name, file):
            logger.info('A new version of the document %s is going to be created.' % document_name)
            document_manager = DocumentManager()
            file_content = document_manager.get_json_file(file)
            result = self.client.update_document(Content=json.dumps(file_content), Name=document_name,
                                                 DocumentVersion="$LATEST")
            if result == None:
                logger.error("Cannot update the document %s with the file %s" % (document_name, file))
                sys.exit(1)
            logger.info("Document %s updated successfully." % document_name)
            self.set_default_version(document_name, result['DocumentDescription']['LatestVersion'])
        else:
            logger.info('Latest version of the document already available.')

    def set_default_version(self, document_name, document_version):
        res = self.client.update_document_default_version(Name=document_name, DocumentVersion=document_version)
        if res == None:
            logger.error("Cannot set the version %s for the document %s." % (document_version, document_name))
            sys.exit(2)
        logger.info("Default version %s set for the document %s" % (document_version, document_name))

    def run_custom_document(self, document_name, parameters_json, instance_id):
        # create the AWS SSM document and set as the latest version
        res = self.client.send_command(DocumentName=document_name, Parameters=json.loads(parameters_json),
                                       InstanceIds=[instance_id])
        command_id = res['Command']['CommandId']
        try:
            time.sleep(3)
            cde_result = self.client.get_command_invocation(CommandId=command_id, InstanceId=instance_id)
            while cde_result['Status'] == 'InProgress':
                logger.info(
                    'Command invocation %s is still in progress on the server %s ...' % (command_id, instance_id))
                time.sleep(5)
                cde_result = self.client.get_command_invocation(CommandId=command_id, InstanceId=instance_id)
            return cde_result

        except botocore.exceptions.ClientError as error:
            if error.response['Error']['Code'] == 'InvocationDoesNotExist':
                logger.error('The invocation command (%s) has not been found' % command_id)
            raise error


parser = argparse.ArgumentParser(prog='AWS SSM management')
parser.add_argument("action", nargs='?', default="create-run")
parser.add_argument("-d", "--document", help="AWS Document name", required=True)
parser.add_argument("-f", "--file", help="File name that contains the content")
parser.add_argument("-i", "--instance", help="EC2 Instance name to execute the AWS SSM document", required=True)
parser.add_argument("-p", "--parameters", help="AWS SSM document parameters", required=True)
parser.add_argument("-profile", "--profile", help="Input aws profile", default=None)

args = parser.parse_args()

if args.action == "create-run" and args.file == None:
    logger.error("Please specify -f / --file parameter as this is mandatory with create-run")

ec2_manager = Ec2Manager(args.profile)
instance_id = ec2_manager.get_first_instance_id_by_name(args.instance)
aws_sm = AwsSM(args.profile)
document_exists = aws_sm.is_document_exists(args.document)
if not document_exists and args.action == "create-run":
    aws_sm.create_document(args.document, args.file)
elif not document_exists:
    logger.error("Error the AWS Document %s has not been found.")
    sys.exit(1)
else:
    if args.action == "create-run":
        aws_sm.update_document(args.document, args.file)
logger.info("Running AWS command...")
command_result = aws_sm.run_custom_document(args.document, args.parameters, instance_id)
logger.info('Output : \n%s' % command_result['StandardOutputContent'])
if command_result['StandardErrorContent'] != None and command_result['StandardErrorContent'] != "":
    logger.error('Standard Error: \n%s' % command_result['StandardErrorContent'])
if command_result['Status'] != "Success":
    sys.exit(4)
