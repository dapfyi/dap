package d3centr.sparkubi

import java.math.MathContext

import Conf.{MC, Rescale, Simplify}
import Typecast.{BD, BD2, BD10}
import Cache.ScalePowers

object Arithmetic {

    def multiply(left: UBI, right: UBI): UBI = UBI(Rescale,
        left.ubi * right.ubi, 
        left.scale + right.scale, 
        left.bits + right.bits)

    def multiply(left: Fraction, right: Fraction): Fraction = {
        val t0 = System.nanoTime
        val child = Fraction(Simplify,
            multiply(left.numerator, right.numerator),
            multiply(left.denominator, right.denominator))
        Log.stats("M", left, right, child, t0)
        child
    }

    def divide(left: Fraction, right: Fraction) = {
        val t0 = System.nanoTime
        val child = Fraction(Simplify,
            multiply(left.numerator, right.denominator),
            multiply(left.denominator, right.numerator))
        Log.stats("D", left, right, child, t0)
        child
    }

    def add(left: Fraction, right: Fraction) = {
        val t0 = System.nanoTime
        val (ln, rn, denominator) = commonDNE(left, right)
        val t1 = System.nanoTime
        val numerator = operate(ln, rn, _+_)
        val t2 = System.nanoTime
        val child = Fraction(Simplify, numerator, denominator)
        val t3 = System.nanoTime
        Log.stats("A", left, right, child, t0, t1, t2, t3)
        child
    }

    def subtract(left: Fraction, right: Fraction) = {
        val t0 = System.nanoTime
        val (ln, rn, denominator) = commonDNE(left, right)
        val t1 = System.nanoTime
        val numerator = operate(ln, rn, _-_)
        val t2 = System.nanoTime
        val child = Fraction(Simplify, numerator, denominator)
        val t3 = System.nanoTime
        Log.stats("S", left, right, child, t0, t1, t2, t3)
        child
    }

    def commonDNE(  // common Denominator & Numerator Encoding
        left: Fraction, right: Fraction): Tuple3[UBI, UBI, UBI] = {

        if (left.denominator == right.denominator) {

            val (ln, rn) = commonEncoding(left.numerator, right.numerator)

            (ln, rn, left.denominator)

        } else {

            val denominator = multiply(left.denominator, right.denominator)

            val (ln, rn) = commonEncoding(
                multiply(left.numerator, right.denominator),
                multiply(right.numerator, left.denominator)
            )

            (ln, rn, denominator)

        }
    }

    def commonEncoding(left: UBI, right: UBI, 
        mc: MathContext = MC): Tuple2[UBI, UBI] = {

        if (left.bits == right.bits) (left, right) else {

            val sortedBits = Seq(left, right).map(_.bits).sorted
            if(left.bits == sortedBits.head) {

                val rightBitEncodedLeftInt = BD(mc,
                    left.ubi.bigDecimal.unscaledValue.shiftLeft(right.bits - left.bits)
                )
                ( UBI(Rescale, rightBitEncodedLeftInt, left.scale, right.bits), right )

            } else { 

                val leftBitEncodedRightInt = BD(mc,
                    right.ubi.bigDecimal.unscaledValue.shiftLeft(left.bits - right.bits)
                )
                ( left, UBI(Rescale, leftBitEncodedRightInt, right.scale, left.bits) )

            }
        }
    }

    def scale(ubi: UBI): BigDecimal = {
        val t0 = System.nanoTime
        val child = scale(ubi.ubi, ubi.scale)
        val t1 = System.nanoTime
        Log.fn("scale", t0, t1)
        child
    }
    def scale(ubi: BigDecimal, scale: Int): BigDecimal = {
        val t0 = System.nanoTime
        // BD10.pow(-scale) is expensive, use cache outside edge cases
        val factor = ScalePowers.getOrElse(scale, BD10.pow(-scale))
        val t1 = System.nanoTime
        val child = ubi * factor
        val t2 = System.nanoTime
        Log.scale("scale2", scale, t0, t1, t2)
        child
    }

    def operate(left: UBI, right: UBI, op: (BigDecimal, BigDecimal) => BigDecimal, 
        mc: MathContext = MC): UBI = {
        val t0 = System.nanoTime
        val result = op(scale(left), scale(right))
        val t1 = System.nanoTime
        val child = UBI(
            Rescale, 
            BD(mc, result.bigDecimal.unscaledValue), 
            result.scale, 
            left.bits
        ) 
        val t2 = System.nanoTime
        Log.fn("operate", t0, t1, t2)
        child
    }

}

