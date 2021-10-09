package d3centr.sparkubi

import java.math.{BigInteger, MathContext}

import scala.language.implicitConversions
import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.catalyst.expressions.Expression
import Conf.{MC, Simplify}

object Typecast {

    type SE = Seq[Expression]

    def BD(n: String) = BigDecimal(n, MC)
    def BD(n: BigInteger) = BigDecimal(n, MC)
    def BD(mc: MathContext, n: BigInteger) = BigDecimal(n, mc)

    val BD2 = BD("2")
    val BD10 = BD("10")
    val One = "1e0b0"

    val integer = "[-0-9]+"
    val sci = s"($integer)e($integer)"
    val ubi = sci + """b(\d+)"""

    val fractionPattern = """^([-0-9eb]+)/([-0-9eb]+)$""".r
    val ubiPattern = s"""^${ubi}$$""".r
    val sciPattern = s"""^${sci}$$""".r
    val intPattern = s"""^($integer)$$""".r
    val decPattern = s"""^(${integer}\\.\\d+)$$""".r
    val doublePattern = s"""^(${integer}\\.?\\d*E${integer})$$""".r

    // Spark code generation pointer
    val S2FName = "d3centr.sparkubi.Typecast.stringToFraction"
    implicit def stringToFraction(s: UTF8String): Fraction = 
        if (s == null) null else { 
            val str = s.toString
            str match {
                case fractionPattern(numerator, denominator) => 
                    Fraction(Simplify, numerator, denominator)

                case "" => null

                case _ => Fraction(str, One)
            }
        }

    implicit def stringToFraction(s: String): Fraction = {
        stringToFraction(UTF8String.fromString(s))
    }

    implicit def stringToUbi(s: String): UBI = s match {

        case ubiPattern(integer, scale, bits) => 
            UBI(BD(integer), scale.toInt, bits.toInt)

        case sciPattern(integer, scale) =>
             UBI(BD(integer), scale.toInt, 0)

        case intPattern(integer) =>
            UBI(BD(integer), 0, 0)

        case decPattern(dec) =>
            val n = BD(dec)
            UBI(BD(n.bigDecimal.unscaledValue), n.scale, 0)

        case doublePattern(double) => 
            val n = BD(double)
            UBI(BD(n.bigDecimal.unscaledValue), n.scale, 0)

    }

    implicit def fractionToString(f: Fraction): String =  f match {

        case Fraction(UBI(numInt, numScale, numBits), 
                      UBI(denInt, denScale, denBits)) => 

        s"${numInt}e${numScale}b${numBits}/${denInt}e${denScale}b${denBits}"

        case null => ""

    }

    implicit def fractionToUTF8String(f: Fraction): UTF8String =
        UTF8String.fromString(fractionToString(f))

    implicit def ubiToFraction(n: UBI): Fraction = Fraction(n, One)

}

