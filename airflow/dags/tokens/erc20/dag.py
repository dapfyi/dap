from airflow.decorators import dag, task
from airflow.operators.python import get_current_context
from airflow.utils.dates import days_ago
import os
import s3fs
import json
import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import mmh3
from web3 import Web3
from utils import eth_ip

PARAMS = {
    'source': f"{os.environ['DATA_BUCKET']}/uniswap-v3-subgraph/contract=Factory", 
    'fields': ['args.token0', 'args.token1'], 
    'abi': 'uniswap-v3-subgraph/abis/ERC20.json',
    'eth_client': os.environ['ETHEREUM_CLIENT']
}
CONCURRENCY = 4

@task()
def initialize():
    conf = get_current_context()['dag_run'].conf

    s3_fs = s3fs.S3FileSystem()
    fields = [f.split('.') for f in conf['fields']]
    columns = {f[0] for f in fields}
    df = pq.ParquetDataset(conf['source'], 
        filesystem=s3_fs).read(columns).to_pandas()

    tokens = set()  # unique ERC20 token addresses
    for col in columns:
        if col == 'args':
            keys = [f[1] for f in fields if f[0] == 'args']
            args = pd.json_normalize(df.args.apply(json.loads))[keys]
            tokens.update(np.unique(args))
        else:
            tokens.update(np.unique(df[col]))

    threads = [[] for _ in range(CONCURRENCY)]
    for token in tokens:
        i = mmh3.hash(token, signed=False) % CONCURRENCY
        threads[i].append(token)
    return threads

@task()
def batch(threads, i):
    thread = threads[i]

    conf = get_current_context()['dag_run'].conf
    with open(conf['abi']) as file:
        abi = json.load(file)
    w3 = Web3(Web3.WebsocketProvider(
        f"ws://{eth_ip(conf['eth_client'])}:8546", websocket_timeout=60))

    tokens = []
    for address in thread:
        contract = w3.eth.contract(address, abi=abi)
        try:
            symbol = contract.functions.symbol().call()
        except:
            symbol = address
        try:
            decimals = contract.functions.decimals().call()
        except:
            decimals = 0
        tokens.append({'address': address, 'symbol': symbol, 'decimals': decimals})

    pq.write_to_dataset(
        pa.Table.from_pandas(pd.DataFrame(tokens)),
        f"{os.environ['DATA_BUCKET']}/tokens/erc20",
        filesystem=s3fs.S3FileSystem(),
        compression='SNAPPY',
        partition_filename_cb=lambda _: f'{i}.parquet.snappy'
    )

@dag(
    default_args={
        'retries': 1
    },
    schedule_interval=None,
    start_date=days_ago(2),
    concurrency=CONCURRENCY,
    params=PARAMS,
    tags=['etl']
)
def erc20():
    threads = initialize()
    for i in range(CONCURRENCY):
        batch(threads, i)

erc20_dag = erc20()

