# SparkUBI
A Spark extension library to process blockchain integers with arbitrary precision. 

With SparkUBI, you can transform your cluster into a precise off-chain computation engine leveraging the power of Apache Spark.

[[Features](#features)] [[Installation](#installation)] [[Key Concepts](#key-concepts)] [[Spark SQL API](#spark-sql-api)] [[Optimization](#optimization)] [[Configuration](#configuration)]
## Features
- a Spark SQL interface for calculation and aggregation on integers that can't fit in a native type
- fixed-point arithmetic for _absolute_ accuracy: changing scale doesn't impact resolution
- token decimal tracking across operations
- support for fractional bits
- minimized rounding error can only occur in 2 cases: overflow and scaling factor adjustment

SparkUBI operates on fractions of decimal and binary fractions. This gives extra capabilities:
- lossless fraction simplification to speed up calculations
- exact divisions represented as rational numbers

## Installation
Build SparkUBI, make the jar available to your cluster and register it as a Spark extension with the following property: 

`spark.sql.extensions=d3centr.sparkubi.Extensions` 

The same class can also be called to dynamically load SparkUBI in a session builder: 

`SparkSession.withExtensions(new d3centr.sparkubi.Extensions)`
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
### Fractions
A fraction, the underlying number representation, is made of 2 Unscaled Big Integers: a numerator and a denominator. 

In general, the fully detailed string representation of a fraction could be written as `1e8b96/2e0b0`, where: 
- `1` is the numerator Unscaled Big Integer (UBI)
- `8` its number of decimals
- `96` its bit encoding
- similarly for the denominator `2e0b0`, which is exactly equal to `2`. 

Separators `e`, `b` and `/` stand for scientific notation, bits and fraction part delimiter, respectively.
### Naming Conventions

Not to confuse fractions of Unscaled Big Integers and their fractional bits, the latter is referred to as _bit encoding_: a value with _f_ fraction bits is said to be _f_ bit encoded or simply to have _f_ bits, i.e. a 1/2^_f_ scaling factor. 

_Scale_ only refers to decimals as in ERC20 or Java BigDecimal standards.
## Spark SQL API
SQL functions with scala API bindings are implemented as catalyst expressions for performance.

They take string arguments representing either a usual number format like 1, 1.0, 8.24E-4, or a fraction as described in [Key Concepts](#fractions). When passing fractions to SparkUBI functions: bits, denominator and scale can be omitted if integers aren't binary encoded and a 1 denominator or a 0 scale is implied.

In scala, import `d3centr.sparkubi.functions._` to use SparkUBI outside SQL expressions.
- Exact __arithmetic__ functions between 2 fractions: `ubim` multiplication, `ubid` division, `ubia` addition and `ubis` subtraction. 
- __Aggregate__ functions with fraction buffer `ubi_min`, `ubi_max`, `ubi_sum` and `ubi_avg` can be called along Spark defaults.
- Potentially __lossy__ `ubi_resolve` translates a UBI number into a BigDecimal string. Cast its output to your numeric type of choice.
- Other __unary__ functions include `ubi_abs`, the absolute value, and `ubi_sign`, equivalent of BigDecimal.signum applied to a fraction.
### Examples
- `ubid('1e8b96', '2')` in SQL and `ubid(lit("1e8b96"), lit("2"))` in Scala yield the fraction described above
- `CAST(ubi_resolve(column) AS double)` in SQL or `ubi_resolve(column).cast("double")` in Scala, where `column` is of `StringType` with a single value `"2e-1b1"`, return `10.0`: 2 divided by 1 bit and multiplied by 10^-(-1)

## Optimization
### Fractions
Fractions are automatically simplified to contain precision in serial computations.
### Spark Catalyst
Whole-stage code generation compiles multiple expressions in a single function leveraging CPU register data.
### Precision
Tunable precision limits can efficiently control memory and computation costs in different contexts. For instance, calculations on single transactions can be processed with higher accuracy than an aggregation trading it off to scale.
## Configuration
SparkUBI is configured through environment variables. They should be set both on the driver and executors.

For example, you can set `spark.kubernetes.driverEnv.SPARKUBI_PRECISION` and `spark.executorEnv.SPARKUBI_PRECISION` to configure precision through Spark properties on K8s in cluster mode. In client mode, the environment variable should already be set in the driver container.
### Precision
Set `SPARKUBI_PRECISION`: maximum number of digits in an integer (`200` default). 

SparkUBI handles overflow at the cost of rounding errors beyond this threshold.
### Minimum Fractional Bits
Set `SPARKUBI_MIN_BITS`: by default, this value ensures integers are not decoded below `192` bits while dynamically managing precision. 

That's how SparkUBI can guarantee a minimum accuracy resolution.
### Fraction Simplification
Set `SPARKUBI_SIMPLIFY`: precision threshold triggering fraction simplification to reduce significant digits (`100` default). 

Half precision is a sensible default because the precision of two multiplied integers is approximately the sum of their precision. An operation applied to numbers below this threshold will be safe from rounding.
- `-1` means none to exclude any fraction simplification 

This value also excludes decimal simplification usually applied at all times (cheap factorization not impacting precision).
- set above precision to only exclude heavier simplifications lowering precision
- set between 0 and precision to include any type of simplification above threshold
### Overflow
Set `SPARKUBI_RESCALE`: by default (`true`), SparkUBI automatically handles the rounded result of a precision overflow.

Set `false` if you'd rather error out when a number doesn't fit within specified precision.
### Profiling Logs
Set `SPARKUBI_PROFILING`, `false` default.

`true` activates profiling INFO logs: they measure precision and computation times in individual sub-operations to fine tune SparkUBI. You could activate profiling if you're looking for empirical data helping to balance computation costs and accuracy loss. The amount of generated logs can be significant.

