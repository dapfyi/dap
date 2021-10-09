package d3centr.sparkubi

import Conf.Profiling
import org.apache.log4j.Logger

object Log {

    val logger = Logger.getRootLogger

    def debug(s: String) = logger.debug(s)
    def info(s: String) = logger.info(s)
    def warn(s: String) = logger.warn(s)
    def error(s: String) = logger.error(s)

    def stats(
        op: String, 
        left: Fraction, 
        child: Fraction, 
        ns: Long,
        t1: Long,
        t2: Long,
        t3: Long
    ): Unit = if(!Profiling) return else stats(
        op, 
        left,
        Fraction.ZERO, 
        child, 
        ns,
        t1,
        t2,
        t3
    )

    def stats(
        op: String, 
        left: Fraction, 
        right: Fraction, 
        child: Fraction, 
        ns: Long,
        t1: Long = -1,
        t2: Long = -1,
        t3: Long = -1
    ): Unit = if(!Profiling) return else logger.info(s"""{
        "op": "$op", 
        "left": {
            "num": {
                "p": ${left.numerator.ubi.precision}, 
                "b": ${left.numerator.bits}
            },
            "den": {
                "p": ${left.denominator.ubi.precision}, 
                "b": ${left.denominator.bits}
            }
        },
        "right": {
            "num": {
                "p": ${right.numerator.ubi.precision}, 
                "b": ${right.numerator.bits}
            },
            "den": {
                "p": ${right.denominator.ubi.precision}, 
                "b": ${right.denominator.bits}
            }
        },
        "child": {
            "num": {
                "p": ${child.numerator.ubi.precision}, 
                "b": ${child.numerator.bits}
            },
            "den": {
                "p": ${child.denominator.ubi.precision}, 
                "b": ${child.denominator.bits}
            }
        },
        "ns": $ns,
        "t1": $t1,
        "t2": $t2,
        "t3": $t3
    }""".split("\\s+").mkString)

}

