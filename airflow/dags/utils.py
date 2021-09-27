import boto3
import os
import s3fs
from constants import EPOCH_LENGTH

def describe_instance(name):
    ec2 = boto3.client('ec2')
    return ec2.describe_instances(Filters=[
        {'Name': 'tag:Name', 'Values': [name]},
        {'Name': 'subnet-id', 'Values': [os.environ['SUBNET_A']]},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ])['Reservations'][0]['Instances'][0]

def eth_ip(eth_client):
    ip = describe_instance(eth_client)['PrivateIpAddress']
    return ip

def eth_threads(eth_client):
    cpu = describe_instance(eth_client)['CpuOptions']
    return cpu['CoreCount'] * cpu['ThreadsPerCore'] - 1 

def checkpoint_override(epoch, key):

    def load(key,
        data_bucket=os.environ['DATA_BUCKET'], s3_fs=s3fs.S3FileSystem()):
        if s3_fs.exists(f'{data_bucket}/{key}'):
            object = boto3.resource('s3').Object(data_bucket, key)
            metadata = int(object.get()['Body'].read())
            return metadata
        else:
            return 0

    _last_block = load(key)
    while _last_block >= EPOCH_LENGTH * (epoch + 2):
        print(f'epoch {epoch} persisted at least 2 epochs ahead: skip')
        epoch += 1
        key = f"{key.split('__')[0]}__{epoch}"
        _last_block = load(key)

    return epoch

