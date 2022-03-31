package fyi.dap.sparkubi

import java.math.BigInteger.ONE
import java.lang.ArithmeticException
import Typecast.{BD, BD2, BD10}
import Cache.{ScalePowers, BitFractions}

object Unary {

    def resolve(f: Fraction): BigDecimal = if (f == null) null else {
        val t0 = System.nanoTime

        val decimals = f.numerator.scale - f.denominator.scale
        val scalingFactor = ScalePowers.getOrElse(decimals, BD10.pow(-decimals))
        val t1 = System.nanoTime

        val bits = f.numerator.bits - f.denominator.bits
        val bitFraction = BitFractions.getOrElse(bits, BD2.pow(bits))
        val t2 = System.nanoTime

        lazy val opString = s"${f.numerator.ubi} / ${f.denominator.ubi} " +
            s"* $scalingFactor / $bitFraction"

        try {

            val child =  // do not call decode to return the most precise result
                f.numerator.ubi / f.denominator.ubi * scalingFactor / bitFraction
            val t3 = System.nanoTime
            Log.unary("resolve", f, t0, t1, t2, t3)
            child

        } catch {

            case e: ArithmeticException => 
                Log.error(s"ArithmeticException attempting to resolve $opString")
                throw e
            case e: Throwable => 
                Log.error(s"Exception attempting to resolve $opString")
                throw e

        }
    }

    /* shift and round fractional bits first for fast display or %
       use with caution: less accurate than resolve
    */
    def resolveBitwise(f: Fraction): Option[BigDecimal] = {
        val t0 = System.nanoTime

        val (num, den) = decode(f)
        val t1 = System.nanoTime

        val decimals = num.scale - den.scale
        val scalingFactor = ScalePowers.getOrElse(decimals, BD10.pow(-decimals))
        val t2 = System.nanoTime

        val child = if(den.ubi.signum == 0) None 
            else Some(num.ubi / den.ubi * scalingFactor)
        val t3 = System.nanoTime

        Log.unary("resolveBitwise", f, t0, t1, t2, t3)
        child
    }

    def decode(f: Fraction): Tuple2[UBI, UBI] = (
        decode(f.numerator), decode(f.denominator)
    )

    /* 
       Rounding Proof:
       round(x/y) = floor(x/y + 0.5) = floor((x + y/2)/y)
       i.e. for y = 2^n, shift-of-n(x + 2^(n-1))
    */
    def decode(ubi: UBI, target: Int = 0): UBI = {
        if (ubi.bits <= target) ubi else {
            val shifts = ubi.bits - target

            val decoded = BD(ubi.ubi.
                bigDecimal.unscaledValue.
                // add half the scaling factor to round
                add(ONE.shiftLeft(shifts - 1)).
                shiftRight(shifts))

            // divide exactly to handle underflow
            if(decoded.signum == 0) {

                val divided = ubi.ubi / BD2.pow(shifts)
                UBI(BD(divided.bigDecimal.unscaledValue), 
                    ubi.scale + divided.scale, 
                    target)

            } else ubi.copy(bits = target, ubi = decoded)
        }
    }

    def abs(f: Fraction) = f match { 
        case Fraction(num, den) => Fraction(
            num.copy(ubi = num.ubi.abs),
            den.copy(ubi = den.ubi.abs))
    }

    def sign(f: Fraction): Int = f match { 
        case Fraction(num, den) if num.ubi.signum == 0 => 0
        case Fraction(num, den) if num.ubi.signum == den.ubi.signum => 1
        case Fraction(num, den) if num.ubi.signum != den.ubi.signum => -1
    }

}

