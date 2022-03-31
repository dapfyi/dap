# SparkUBI
A Spark extension to process blockchain integers with arbitrary precision. 

With SparkUBI, you can transform your cluster into a precise off-chain computation engine leveraging the power of Apache Spark.

[ [Features](#features) ] [ [Installation](#installation) ] [ [Key Concepts](#key-concepts) ] [ [Spark SQL API](#spark-sql-api) ] [ [Optimization](#optimization-highlights) ] [ [Configuration](#configuration) ]
## Features
- a Spark SQL interface for calculation and aggregation on integers that can't fit in a native type
- resolution safety: constant unit in the last place (ulp) through fixed-point arithmetic 
- token decimal tracking across operations and DEX exchange rates
- support for fractional bits (common DeFi encoding)
- minimized rounding error can only occur in 2 cases: overflow and scaling factor adjustment

> SparkUBI operates on fractions of decimal and binary fractions, giving extra capabilities:
- lossless fraction simplification to speed up calculations
- exact divisions represented as rational numbers

## Installation
Build SparkUBI, make the jar available to your cluster and register it as a Spark extension with the following property: 

`spark.sql.extensions=fyi.dap.sparkubi.Extensions` 

The same class can also be called to dynamically load SparkUBI in a session builder: 

`SparkSession.withExtensions(new fyi.dap.sparkubi.Extensions)`
## Key Concepts
### Basic Arithmetic Plan
```
Operation on respective fraction parts yields an exact rational number.
                               ^
                     __________|__________
                   /                       \
   common bit encoding of numerators        |\________
                  ^                         |          \
                  |                         |           |
          common denominator                |          '*'
                  ^                         |           ^
                  |                         |           |
               '+' '-'                     '*' '/' -> inverse right
                   \________       ________/
                             \   /
                               ^
                             __|__
                           /       \ 
           Operand Pair: left  &  right fractions
```
### UBI
In SparkUBI core, we find the _Unscaled Big Integer_ (UBI): a data structure created to combine the higer-level control of big floating-point numbers with fixed-point features. The MathContext of a 0 scale BigDecimal controls a number accuracy and rounding while fractional values are still represented as integer multiples of some fixed small unit, like in the EVM.
### Fractions
A fraction, the underlying number representation, is made of 2 UBIs: a numerator and a denominator. 

In general, the fully detailed string representation of a fraction could be written as `1e8b96/2e0b0`, where: 
- `1` is the UBI numerator integer
- `8` its number of decimals
- `96` its bit encoding
- similarly for the denominator `2e0b0`, which is exactly equal to `2`. 

Separators `e`, `b` and `/` stand for scientific notation, bits and fraction part delimiter, respectively.
### Naming Conventions

Not to confuse fractions of Unscaled Big Integers and their fractional bits, the latter is referred to as _bit encoding_. 
> A value with _f_ fraction bits is said to be _f_ bit encoded or simply to have _f_ bits, i.e. a 1/2^_f_ scaling factor. 

_Scale_ only refers to decimals as in ERC20 or Java BigDecimal standards.
## Spark SQL API
SQL functions with Scala bindings are called on dataframes for ease of use and executed as catalyst expressions for performance.

They take `org.apache.spark.sql.Column` arguments of `StringType` and also return a `StringType`. Input strings should represent either a usual number format like 1, 1.0, 8.24E-4, or a fraction as described in [Key Concepts](#fractions). 
> When passing fractions to SparkUBI functions: bits, scale and denominator can be omitted. Default values will imply integers aren't binary encoded, a 0 scale or a 1 denominator.

In Scala, import `fyi.dap.sparkubi.functions._` to access SparkUBI functions outside SQL expressions.
- Exact __arithmetic__ functions between 2 fractions: `ubim` multiplication, `ubid` division, `ubia` addition and `ubis` subtraction. 
- __Aggregate__ functions with fraction buffer `ubi_min`, `ubi_max`, `ubi_sum` and `ubi_avg` can be called along Spark defaults.
- Potentially __lossy__ `ubi_resolve` translates a UBI number into a BigDecimal string. Cast its output to your numeric type of choice.
- Other __unary__ functions include `ubi_abs`, the absolute value, and `ubi_sign`, equivalent of BigDecimal.signum applied to a fraction.
### Examples
- `ubid(col1, col2)` in SQL and `ubid($"col1", $"col2")` in Scala yield the fraction described above for col1 = `1e8b96` and col2 = `2`

- `CAST(ubi_resolve(column) AS double)` in SQL or `ubi_resolve('column).cast("double")` in Scala return `10.0` for `2e-1b1`
> 2 divided by 1 bit and multiplied by 10^-(-1)

## Optimization Highlights
### Fractions
Fractions are automatically simplified to contain precision in serial computations.
### Precision
Tunable precision limits can efficiently control memory and computation costs in different contexts. 
> Calculations on single transactions can be processed with higher accuracy than an aggregation trading it off to scale.
### Spark Catalyst
Whole-stage code generation compiles multiple expressions in a single function leveraging CPU register data.

_illustrative example_

`val df = spark.range(10).where(ubi_sign('id.cast("string")) === 0)`

`df` is a DataFrame filtering an `id` column after casting its input and applying a SparkUBI function.
```
scala> df.explain("formatted")
== Physical Plan ==
* Filter (2)
+- * Range (1)

(1) Range [codegen id : 1]
Output [1]: [id#714L]
Arguments: Range (0, 10, step=1, splits=Some(2))

(2) Filter [codegen id : 1]
Input [1]: [id#714L]
Condition : (ubi_sign(cast(id#714L as string)) = 0)
```
The query execution plan shows it's been split in 2 physical operators sharing the same codegen id. All function calls, including SparkUBI transformations, are effectively merged into one.

`df.explain("codegen")` shows the optimized Java code, commented extract from generated `processNext()` function below:
```
   ...       // string input instantiates a Fraction argument for the sign method in SparkUBI Unary object 
/* 102 */    filter_value_1 = fyi.dap.sparkubi.Unary.sign(fyi.dap.sparkubi.Typecast.stringToFraction(filter_value_2));
/* 103 */
/* 104 */    boolean filter_value_0 = false;
/* 105 */    filter_value_0 = filter_value_1 == 0;  // filter condition specified in query is tested
/* 106 */    if (!filter_value_0) continue;  // skipped iterator overhead in case condition is false 
/* 107 */
/* 108 */    ((org.apache.spark.sql.execution.metric.SQLMetric) references[1] /* numOutputRows */).add(1);
   ...       // whole-stage codegen materializes only selected rows
```
## Configuration
SparkUBI is configured through environment variables. They should be set both on the driver and executors.

_Kubernetes_

You could set `spark.kubernetes.driverEnv.SPARKUBI_PRECISION` and `spark.executorEnv.SPARKUBI_PRECISION` to configure precision like any other variable through Spark properties in cluster mode. However, it is probably best to configure manifests. In client mode, the environment variable should already be set in the driver container.
### Precision
Set `SPARKUBI_PRECISION`: maximum number of digits in an integer (`200` default). 
> By default, SparkUBI handles overflow at the cost of rounding errors beyond this threshold.
### Minimum Fractional Bits
Set `SPARKUBI_MIN_BITS`: by default, this value ensures integers are not decoded below `192` bits while dynamically managing precision. 
> That's how SparkUBI can guarantee a minimum accuracy resolution.
### Fraction Simplification
Set `SPARKUBI_SIMPLIFY`: precision threshold triggering fraction simplification to reduce significant digits (`100` default). 
> Half precision is a sensible default because the precision of two multiplied integers is approximately the sum of their precision. An operation applied to numbers below this threshold will be safe from rounding or overflow.
- `-1` means none to exclude any fraction simplification (barely used) 

Note: this value also excludes decimal simplification usually applied at all times to optimize cached powers of ten.
- set above precision to only exclude heavier simplifications lowering precision (rarely used)
- set between 0 and precision to include any type of simplification above threshold (common usage)
### Overflow
Set `SPARKUBI_RESCALE`: by default (`true`), SparkUBI automatically handles the rounded result of a precision overflow.

Set `false` if you'd rather error out when a number doesn't fit within specified precision.
### Profiling Logs
Set `SPARKUBI_PROFILING`, `false` default.

`true` activates _profiling_ INFO logs: measure precision and computation times in individual sub-operations to fine tune SparkUBI code. 
> You could activate profiling if you're looking for empirical data helping to balance computation costs and accuracy loss.

Note: this is not a benchmark.
> The amount of generated logs can be significant and could slow down processing, measurements are best interpreted relatively.

