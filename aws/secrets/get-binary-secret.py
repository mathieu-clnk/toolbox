import boto3
import getopt
import sys

def usage():
    print("get-binary-secret.py --secret-id <secret-id> --file-output <file-path>")

class AwsSecretManager:

    def __init__(self, profile=None, region='eu-west-1'):
        session = boto3.Session(profile_name=profile)
        self.client = session.client('secretsmanager', region_name=region)


    def save_binary_secret(self,secret_id,file_output):
        try:
            response = self.client.get_secret_value(SecretId=secret_id)
            f = open(file_output,"wb")
            f.write(response['SecretBinary'])
            f.close()
        except:
            print("Unhandled error")
            raise

if __name__ == '__main__':
    """ In this main function, we are fetching the users from IAM and passing the username to access_key() """

    profile = None
    region = "eu-west-1"
    secret_id = None
    file_output = None

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hf:p:r:s:", ["help","file-output=", "region=","profile=","secret-id="])
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
        elif o in ("-s", "--secret-id"):
            secret_id = a
        elif o in ("-f", "--file-output"):
            file_output = a
        elif o in ("-p", "--profile"):
            profile = a
        else:
            assert False, "unhandled option"
            usage()
            sys.exit(2)

    if file_output is None or secret_id is None:
        usage()
        sys.exit(1)

    aws_secret = AwsSecretManager(profile,region)
    aws_secret.save_binary_secret(secret_id,file_output)