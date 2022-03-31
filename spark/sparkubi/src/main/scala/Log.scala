package fyi.dap.sparkubi

import Conf.Profiling
import org.apache.log4j.Logger

import java.math.BigInteger

object Log {

    val logger = Logger.getRootLogger

    def debug(s: String) = logger.debug(s)
    def info(s: String) = logger.info(s)
    def warn(s: String) = logger.warn(s)
    def error(s: String) = logger.error(s)

    def unary(
        fn: String, 
        arg: Fraction,
        t0: Long,
        t1: Long,
        t2: Long,
        t3: Long
    ): Unit = if(!Profiling) return else logger.info(s"""{
        "fn": "$fn",
        "arg": {
            "num": {
                "p": ${arg.numerator.ubi.precision},
                "b": ${arg.numerator.bits}
            },
            "den": {
                "p": ${arg.denominator.ubi.precision},
                "b": ${arg.denominator.bits}
            }
        },
        "ns": ${System.nanoTime - t0},
        "t1": ${t1 - t0},
        "t2": ${t2 - t1},
        "t3": ${t3 - t2}
    }""".split("\\s+").mkString)

    def stats(
        op: String, 
        num: UBI,
        den: UBI, 
        child: Fraction, 
        t0: Long,
        t1: Long,
        t2: Long,
        t3: Long
    ): Unit = if(!Profiling) return else stats(
        op, 
        Fraction(num, den),
        Fraction.ZERO, 
        child, 
        t0,
        t1,
        t2,
        t3
    )

    def stats(
        op: String, 
        left: Fraction, 
        right: Fraction, 
        child: Fraction, 
        t0: Long,
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
        "ns": ${System.nanoTime - t0},
        "t1": ${if(t1 != -1) t1 - t0 else -1},
        "t2": ${if(t2 != -1) t2 - t1 else -1},
        "t3": ${if(t3 != -1) t3 - t2 else -1}
    }""".split("\\s+").mkString)

    def fn(fn: String, t0: Long, t1: Long): Unit = 
        if(!Profiling) return else logger.info(s"""{"fn":"$fn","""
            + s""""ns":${System.nanoTime - t0},"t1":${t1-t0}}""")

    def fn(fn: String, t0: Long, t1: Long, t2: Long): Unit = 
        if(!Profiling) return else logger.info(s"""{"fn":"$fn","""
            + s""""ns":${System.nanoTime - t0},"t1":${t1-t0},"t2":${t2-t1}}""")

    def scale(fn: String, scale: Int, t0: Long, t1: Long, t2: Long): Unit = 
        if(!Profiling) return else logger.info(s"""{"fn":"$fn","scale":$scale,"""
            + s""""ns":${System.nanoTime - t0},"t1":${t1-t0},"t2":${t2-t1}}""")

    def gcd(gcd: BigInteger, searchTs: Long, t1: Long): Unit = 
        if(!Profiling) return else logger.info(
            s"""{"gcd":$gcd,"search":${searchTs - t1},"""
            + s""""compute":${System.nanoTime - searchTs}}""")

}

