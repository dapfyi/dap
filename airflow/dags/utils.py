import boto3
import os

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

