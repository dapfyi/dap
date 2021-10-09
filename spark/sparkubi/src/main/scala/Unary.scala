package d3centr.sparkubi

import java.math.BigInteger.ONE
import java.lang.ArithmeticException
import Typecast.{BD, BD2, BD10}

object Unary {

    def resolve(f: Fraction): BigDecimal = if (f == null) null else {
        val decimals = f.numerator.scale - f.denominator.scale
        val scalingFactor = BD10.pow(-decimals)

        val bits = f.numerator.bits - f.denominator.bits
        val bitFraction = BD2.pow(bits)

        lazy val opString = s"${f.numerator.ubi} / ${f.denominator.ubi} " +
            s"* $scalingFactor / $bitFraction"

        try {
            // do not call decode to return the most precise decimal number
            f.numerator.ubi / f.denominator.ubi * scalingFactor / bitFraction
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
        val (num, den) = decode(f)
        val decimals = num.scale - den.scale
        val scalingFactor = BD10.pow(-decimals)
        if(den.ubi.signum == 0) None 
        else Some(num.ubi / den.ubi * scalingFactor)
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

