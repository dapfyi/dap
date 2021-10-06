from airflow.decorators import dag, task
from airflow.operators.python import get_current_context
from airflow.utils.dates import days_ago
from airflow.api.client.local_client import Client
import os
import boto3
from web3 import Web3
import mmh3
from utils import eth_ip, eth_threads, checkpoint_override
from constants import EPOCH_LENGTH
import events.etl as etl

PARAMS = {
    'subgraph': 'uniswap-v3-subgraph',
    'eth_client': os.environ['ETHEREUM_CLIENT']
}
THREADS = 96
concurrency = eth_threads(PARAMS['eth_client'])

def checkpoint_key(subgraph, run_id_prefix, epoch):
    return f'{subgraph}/_LAST_BLOCK_{run_id_prefix}__{epoch}'

@task()
def scan_contracts():
    dag_run = get_current_context()['dag_run']
    conf, run_id_prefix = dag_run.conf, dag_run.run_id.split('_')[0]
    sources = etl.data_sources(conf['subgraph'])
    min_block = min([source['startBlock'] for source in sources])
    start_epoch = min_block // EPOCH_LENGTH
    epoch = conf.get('epoch', start_epoch)

    metadata_key = checkpoint_key(conf['subgraph'], run_id_prefix, epoch)
    epoch = checkpoint_override(epoch, metadata_key)
    w3 = Web3(Web3.HTTPProvider(f"http://{eth_ip(conf['eth_client'])}:8545"))
    last_block = w3.eth.block_number

    contracts = []
    for source in sources:
        if source['is_factory']:
            factory = etl.FACTORIES[source['name']]
            new_contracts = etl.lookahead(epoch, source, factory['event'], conf)
            batch = etl.process_batch(new_contracts)
            factory_partition = f"{conf['subgraph']}/contract={source['name']}"
            path = '' if epoch == start_epoch else factory_partition
            contracts += factory['handler'](path, epoch, batch)
    if contracts:
        sources += etl.data_templates(conf['subgraph'], contracts)

    return {
        'epoch': epoch, 
        'sources': sources,
        'last_block': last_block
    }

@task()
def partitioner(args):
    threads = [[] for _ in range(THREADS)]
    for source in args['sources']:
        i = mmh3.hash(source['address'], signed=False) % THREADS
        threads[i].append(source)
    args.update({'threads': threads})
    return args

@task()
def thread(i, args):
    conf = get_current_context()['dag_run'].conf
    etl.job(
        args['threads'][i], 
        i, 
        args['epoch'], 
        conf['subgraph'], 
        conf['eth_client']
    )
    return args

@task()
def checkpoint(args):
    dag_run = get_current_context()['dag_run']
    conf, run_id_prefix = dag_run.conf, dag_run.run_id.split('_')[0]

    key = checkpoint_key(conf['subgraph'], run_id_prefix, args['epoch'])
    metadata = boto3.resource('s3').Object(os.environ['DATA_BUCKET'], key)
    metadata.put(Body=str(args['last_block']))

    # A scheduled dag should only run in current epoch,
    # i.e. last_block >= epoch*EPOCH_LENGTH, to prevent run overlap with reload.
    past_reload = args['last_block'] >= (args['epoch'] + 2) * EPOCH_LENGTH
    if past_reload and run_id_prefix == 'manual':
        conf.update({'epoch': args['epoch'] + 1})
        Client(None).trigger_dag(
            dag_id='event_etl',
            run_id=f"manual__{conf['subgraph']}_{conf['epoch']}_{args['last_block']}",
            conf=conf
        )

@dag(
    default_args={
        'retries': 1
    },
    schedule_interval=None, 
    start_date=days_ago(2),
    concurrency=concurrency,
    params=PARAMS,
    tags=['etl']
)
def event():
    args = partitioner(scan_contracts())
    checkpoint_task = checkpoint(args)
    for i in range(THREADS):
        thread(i, args) >> checkpoint_task

event_dag = event()

