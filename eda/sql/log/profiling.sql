
SET pod_prefix=dap-uniswap-aggregate-5345297f9863643c-exec

SET output_table=profiling

SET pattern=%"op"%
SET schema=STRUCT<`child`: STRUCT<`den`: STRUCT<`b`: BIGINT, `p`: BIGINT>, `num`: STRUCT<`b`: BIGINT, `p`: BIGINT>>, `left`: STRUCT<`den`: STRUCT<`b`: BIGINT, `p`: BIGINT>, `num`: STRUCT<`b`: BIGINT, `p`: BIGINT>>, `ns`: BIGINT, `op`: STRING, `right`: STRUCT<`den`: STRUCT<`b`: BIGINT, `p`: BIGINT>, `num`: STRUCT<`b`: BIGINT, `p`: BIGINT>>, `t1`: BIGINT, `t2`: BIGINT, `t3`: BIGINT>

--SET pattern=%"fn":"operate"%
--SET schema=STRUCT<`fn`: STRING, `ns`: BIGINT, `t1`: BIGINT, `t2`: BIGINT>

--SET pattern=%"fn":"scale"%
--SET schema=STRUCT<`fn`: STRING, `ns`: BIGINT, `t1`: BIGINT>

--SET pattern=%"fn":"scale2"%
--SET schema=STRUCT<`fn`: STRING, `ns`: BIGINT, `scale`: BIGINT, `t1`: BIGINT, `t2`: BIGINT>

--SET pattern=%"gcd"%
--SET schema=STRUCT<`compute`: BIGINT, `gcd`: BIGINT, `search`: BIGINT>

--SET pattern=%"resolve"%
--SET schema=STRUCT<`arg`: STRUCT<`den`: STRUCT<`b`: BIGINT, `p`: BIGINT>, `num`: STRUCT<`b`: BIGINT, `p`: BIGINT>>, `fn`: STRING, `ns`: BIGINT, `t1`: BIGINT, `t2`: BIGINT, `t3`: BIGINT>

-- project cached tabular structures upon SparkUBI profiling logs
CACHE TABLE ${output_table} 
    WITH raw AS (
        SELECT split(kubernetes.pod_name, '-')[5] AS exec,
            regexp_replace(log, '^.+INFO root: ', '') AS log
        FROM log
        WHERE kubernetes.pod_name LIKE '${pod_prefix}-%'
        AND log LIKE '%{%}%'
    )     
    SELECT exec, json.* FROM (  -- generate schema: SELECT schema_of_json('{...}')
        SELECT exec, from_json(log, '${schema}') AS json
        FROM raw WHERE log LIKE '${pattern}'
    ) 

-- overview of operations to optimize in run selected above by pod_name filter
SELECT op, 
    count(*) AS ops, 
    sum(ns) AS total_ns, 
    avg(ns) AS avg_ns
FROM profiling 
GROUP BY op 
ORDER BY total_ns DESC 
-- A, S, M, D (Add, Subtract, Multiply, Divide) can include SF (Simplified Fraction)

-- spot expensive sub-operations between timestamps
SELECT 
    avg(t1) AS avg_t1, 
    avg(t2) AS avg_t2,
    avg(t3) AS avg_t3
FROM profiling 
WHERE op == 'A'

