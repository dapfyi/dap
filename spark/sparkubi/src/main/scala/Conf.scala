package d3centr.sparkubi

import java.math.{MathContext, RoundingMode}

object Conf {

    val precision = sys.env.getOrElse("SPARKUBI_PRECISION", "200").toInt
    val MC = new MathContext(precision, RoundingMode.HALF_EVEN)

    // do not decode values below 192 bits to guarantee a minimum resolution
    val MinBits = sys.env.getOrElse("SPARKUBI_MIN_BITS", "192").toInt

    /* Precision threshold triggering fraction simplification:
       - "-1" means none to exclude any fraction simplification, incl. decimals 
       - set above precision to only exclude heavier simplifications lowering precision
       - set between 0 and precision to include any type of simplification above threshold
    */
    val Simplify = sys.env.getOrElse("SPARKUBI_SIMPLIFY", "100").toInt

    /* UBI.ubi scale must always be zero for fixed-point arithmetics.
       - true: handle rounded result of precision overflow, i.e.
         add overflown precision to UBI.scale and regularize UBI.ubi to fit an int.
       - false: do not allow rounding, i.e.
         runtime error will be thrown on precision overflow.
    */
    val Rescale = sys.env.getOrElse("SPARKUBI_RESCALE", "true").toBoolean

    // performance and precision logs
    val Profiling = sys.env.getOrElse("SPARKUBI_PROFILING", "false").toBoolean

    Log.info(s"SparkUBI Configuration: $precision Precision, $MinBits MinBits, " +
        s"$Simplify Simplify, $Rescale Rescale, $Profiling Profiling.")

}

