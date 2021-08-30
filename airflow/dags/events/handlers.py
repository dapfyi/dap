import os
import pyarrow.parquet as pq
import s3fs
import pandas as pd
import json

def uniswap_pool(path, epoch, batch):

    if path != '':
        factory = pq.ParquetDataset(
            f"{os.environ['DATA_BUCKET']}/{path}", 
            filters=[('epoch', '<', epoch)],
            filesystem=s3fs.S3FileSystem()
        ).read().to_pandas()
        # drop epoch partition to merge with batch
        pools = factory[factory.event == 'PoolCreated'].drop(['epoch'], axis=1)
        del factory
    else:
        pools = pd.DataFrame({})

    new_pools = pd.DataFrame(batch)
    pools = pd.concat([pools, new_pools]).drop('address', axis=1)

    keys = ['pool']
    args = pd.json_normalize(pools.args.apply(json.loads))[keys]
    pools[keys] = args
    # remove latest pools where address isn't known, yet
    pools = pools[pools.pool.notna()]
    pools.rename(columns={'pool': 'address', 'blockNumber': 'startBlock'}, inplace=True)
    pools['name'] = 'Pool'  # map to template name

    return pools[['address', 'startBlock', 'name']].to_dict('records')

