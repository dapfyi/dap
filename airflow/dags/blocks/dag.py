from airflow.decorators import dag, task
from airflow.operators.python import get_current_context
from airflow.utils.dates import days_ago
from airflow.api.client.local_client import Client
import os
import s3fs
import boto3
from web3 import Web3
from web3.datastructures import AttributeDict
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from constants import EPOCH_LENGTH
from utils import eth_ip, checkpoint_override

PARAMS = {
    'eth_client': os.environ['ETHEREUM_CLIENT']
}
CONCURRENCY = 8
BATCH_LENGTH = 1000
assert(EPOCH_LENGTH % BATCH_LENGTH == 0)
threads = int(EPOCH_LENGTH / BATCH_LENGTH)

def checkpoint_key(run_id_prefix, epoch):
    return f'blocks/_LAST_BLOCK_{run_id_prefix}__{epoch}'

@task()
def initialize(epoch=412):
    dag_run = get_current_context()['dag_run']
    conf, run_id_prefix = dag_run.conf, dag_run.run_id.split('_')[0]
    epoch = conf.get('epoch', epoch) 
    epoch = checkpoint_override(epoch, checkpoint_key(run_id_prefix, epoch)) 
    w3 = Web3(Web3.HTTPProvider(f"http://{eth_ip(conf['eth_client'])}:8545"))
    last_block = w3.eth.block_number  
    return {        
        'epoch': epoch,
        'last_block': last_block
    }               
                    
@task(executor_config={
    'KubernetesExecutor': {
        'request_cpu': '900m',
        'request_memory': '700Mi',
    }
})
def batch(index, args):
    conf = get_current_context()['dag_run'].conf
    w3 = Web3(Web3.WebsocketProvider(
        f"ws://{eth_ip(conf['eth_client'])}:8546", 
        websocket_timeout=60, websocket_kwargs={'max_size': 10000000}))

    blocks = []
    start = args['epoch'] * EPOCH_LENGTH + index
    for block in range(start, start + BATCH_LENGTH):
        blocks.append(w3.eth.get_block(block, full_transactions=True))
    blocks = [dict(block) for block in blocks]
    for block in blocks:
        block.update({
            'transactions': [dict(t) for t in block['transactions']],
            # prevent OverflowError in pyarrow handling
            'totalDifficulty': str(block['totalDifficulty'])})
        for transaction in block['transactions']:
            transaction.update({'value': str(transaction['value'])})
            transaction.update({
                k: [dict(x) for x in v] for k, v in transaction.items()
                if (isinstance(v, list) and len(v) > 0 
                    and isinstance(v[0], AttributeDict))})

    pq.write_to_dataset(
        pa.Table.from_pandas(pd.DataFrame(blocks)),
        f"{os.environ['DATA_BUCKET']}/blocks/epoch={args['epoch']}",
        filesystem=s3fs.S3FileSystem(),
        compression='SNAPPY',
        partition_filename_cb=lambda _: f'{start}.parquet.snappy'
    )
    return args

@task()
def checkpoint(args):
    dag_run = get_current_context()['dag_run']
    conf, run_id_prefix = dag_run.conf, dag_run.run_id.split('_')[0]

    key = checkpoint_key(run_id_prefix, args['epoch'])
    metadata = boto3.resource('s3').Object(os.environ['DATA_BUCKET'], key)
    metadata.put(Body=str(args['last_block']))

    # Trigger reload up to last epoch.
    past_reload = args['last_block'] >= (args['epoch'] + 2) * EPOCH_LENGTH
    if past_reload and run_id_prefix == 'manual':
        conf.update({'epoch': args['epoch'] + 1})
        Client(None).trigger_dag(
            dag_id='block_etl',
            run_id=f"manual__blocks_{conf['epoch']}_{args['last_block']}",
            conf=conf
        )

@dag(
    default_args={
        'retries': 1
    },
    schedule_interval=None,
    start_date=days_ago(2),
    concurrency=CONCURRENCY,
    params=PARAMS
)
def block_etl():
    args = initialize()
    checkpoint_task = checkpoint(args)
    for i in range(threads):
        batch(i * BATCH_LENGTH, args) >> checkpoint_task

block_etl_dag = block_etl()

