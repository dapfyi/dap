-- ./submit.sh -c mining sparkubi thrift

-- you can set a LOG_BUCKET SQL snippet in Redash for handy reference
CREATE TEMPORARY TABLE log USING json 
LOCATION 's3://LOG_BUCKET/fluent-bit/containers/date=2022-03-17'

SELECT * FROM log LIMIT 3

-- identify pod_name prefix of interest
SELECT kubernetes.pod_name, kubernetes.labels.app, kubernetes.labels.`spark-role`, 
    COUNT(*) AS logs, min(time) AS start_time
FROM log WHERE kubernetes.pod_name LIKE '%uniswap%' GROUP BY 1, 2, 3 ORDER BY logs DESC 
 
SELECT split(kubernetes.pod_name, '-')[5] AS exec, log FROM log 
-- narrow down exec log analysis to a given run
WHERE kubernetes.pod_name LIKE 'blake-uniswap-swaps-81c1097f83ef4664-exec-%'
-- expiry of tokens in ETH conversion state store
AND log LIKE '% removed timed out % state in base0 mapping%'
LIMIT 50

