package d3centr.sparkubi

import java.math.BigInteger
import Typecast.BD
import Unary.decode
import Conf.{MinBits, Profiling}

case class Fraction(numerator: UBI, denominator: UBI)

object Fraction { 

    val ZERO = Fraction(UBI(BD("0"), 0, 0), UBI(BD("1"), 0, 0))

    def apply(threshold: Int, num: UBI, den: UBI): Fraction = {
        if (threshold > -1) simpleFraction(num, den, threshold)
        else Fraction(num, den)
    }

    def simpleFraction(num: UBI, den: UBI, threshold: Int): Fraction = {
        val t0 = System.nanoTime

        // simplifications lowering precision: encoding & GCD
        val (simpleNum, simpleDen, t1) = 
            if (num.ubi.precision >= threshold || 
                den.ubi.precision >= threshold) {

                val (lowNum, lowDen) = (decode(num, MinBits), decode(den, MinBits)) 
                val t1 = System.nanoTime

                if (lowNum.ubi.precision >= threshold || 
                    lowDen.ubi.precision >= threshold) {

                    val gcdInt = lowNum.ubi.bigDecimal.unscaledValue.gcd(
                        lowDen.ubi.bigDecimal.unscaledValue)
                    val searchTs = System.nanoTime

                    val t = if(gcdInt.equals(BigInteger.ONE)) 
                        (lowNum, lowDen, t1) else { 

                        val gcd = BD(gcdInt)
                        ( lowNum.copy(ubi = lowNum.ubi / gcd), 
                          lowDen.copy(ubi = lowDen.ubi / gcd), t1 )

                    }
                    if(Profiling) 
                        Log.info(s"""{"gcd":$gcdInt,"search":${searchTs - t1},"""
                        + s""""compute":${System.nanoTime - searchTs}}""")
                    t

                 } else (lowNum, lowDen, t1)

            } else (num, den, System.nanoTime)
        val t2 = System.nanoTime

        // simplification always applied unless all disabled: scale
        val scales = Seq(simpleNum, simpleDen).map(_.scale).sorted
        val (numScale, denScale) = if (simpleNum.scale == scales.head) 
            (0, simpleDen.scale - simpleNum.scale) else 
            (simpleNum.scale - simpleDen.scale, 0)
        val t3 = System.nanoTime

        val f = Fraction(
            simpleNum.copy(scale = numScale),
            simpleDen.copy(scale = denScale))
        Log.stats("SF", Fraction(num, den), f, System.nanoTime - t0, 
            t1 - t0, t2 - t1, t3 - t2)
        f
    }

}

