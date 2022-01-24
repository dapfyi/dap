import spark.sql

try {

    println("BLAKE ~ Uniswap Database")
    sql("CREATE DATABASE IF NOT EXISTS uniswap")
    
    println("BLAKE ~ rated_swaps Table")
    sql(s"""CREATE TABLE IF NOT EXISTS uniswap.rated_swaps(
        `address` STRING,
        `blockNumber` BIGINT,
        `transactionHash` BINARY,
        `event` STRING,
        `logIndex` BIGINT,
        `transactionIndex` BIGINT,
        `blockHash` BINARY,
        `contract` STRING,
        `epoch` INT,
        `amount0` STRING,
        `amount1` STRING,
        `liquidity` STRING,
        `recipient` STRING,
        `sender` STRING,
        `sqrtPriceX96` STRING,
        `tick` BIGINT,
        `timestamp` BIGINT,
        `gas` BIGINT,
        `gasPrice` STRING,
        `baseFeePerGas` STRING,
        `gasFees` STRING,
        `tip` STRING,
        `pool` STRING,
        `fee` BIGINT,
        `tickSpacing` BIGINT,
        `token0` STRUCT<`symbol`: STRING, `decimals`: DECIMAL(38,0), `address`: STRING>,
        `token1` STRUCT<`symbol`: STRING, `decimals`: DECIMAL(38,0), `address`: STRING>,
        `logId` DECIMAL(38,18),
        `price1` STRING,
        `price0` STRING,
        `resolvedSqrtPrice` DOUBLE,
        `fee0` STRING,
        `fee1` STRING,
        `netAmount0` STRING,
        `netAmount1` STRING,
        `volume0` STRING,
        `volume1` STRING,
        `tickAmount0` DOUBLE,
        `tickAmount1` DOUBLE,
        `tickDepth0` DOUBLE,
        `tickDepth1` DOUBLE,
        `isBasePool` BOOLEAN,
        `is1` BOOLEAN,
        `pairedToken` STRUCT<`symbol`: STRING, `decimals`: DECIMAL(38,0), `address`: STRING>,
        `pairedToken0` STRUCT<`symbol`: STRING, `decimals`: DECIMAL(38,0), `address`: STRING>,
        `pairedToken1` STRUCT<`symbol`: STRING, `decimals`: DECIMAL(38,0), `address`: STRING>,
        `blockNumberTs` TIMESTAMP,
        `lastPrice0` STRING,
        `lastPrice1` STRING,
        `priceDelta0` STRING,
        `priceDelta1` STRING,
        `priceDeltaPct0` DOUBLE,
        `priceDeltaPct1` DOUBLE,
        `tickDelta` BIGINT,
        `base0` STRUCT<`poolAddress`: STRING, `price`: STRING, `is1`: BOOLEAN, `logId`: DECIMAL(38,18)>,
        `base1` STRUCT<`poolAddress`: STRING, `price`: STRING, `is1`: BOOLEAN, `logId`: DECIMAL(38,18)>,
        `usdBase` STRUCT<`poolAddress`: STRING, `price`: STRING, `is1`: BOOLEAN, `logId`: DECIMAL(38,18)>,
        `baseAmounts` MAP<STRING, STRING>,
        `totalFees` STRING,
        `totalFeePct` DOUBLE,
        `usdAmounts` MAP<STRING, STRING>,
        `totalFeesUsd` STRING) 
        PARTITIONED BY (date STRING) 
        ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe' 
        STORED AS 
            INPUTFORMAT 'io.delta.hive.DeltaInputFormat' 
            OUTPUTFORMAT 'io.delta.hive.DeltaOutputFormat' 
        LOCATION 's3a://${sys.env("DELTA_BUCKET")}/uniswap/rswaps'
    """)
    
    println("BLAKE ~ MSCK Repair")
    sql("MSCK REPAIR TABLE uniswap.rated_swaps")

    System.exit(0)

} catch {

    case error: Throwable =>
        println(s"Abnormal termination: $error")
        System.exit(1)

}

