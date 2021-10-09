import java.math.{MathContext, RoundingMode, BigInteger}
import org.apache.spark.sql.functions.expr
import d3centr.sparkubi.UBI
import d3centr.sparkubi.Arithmetic.{
    multiply, commonDNE, scale, operate, commonEncoding}
import d3centr.sparkubi.Unary.{resolve, decode}
import d3centr.sparkubi.Fraction
import d3centr.sparkubi.Conf.MC
import d3centr.sparkubi.Typecast._

class PrecisionSuite extends Spark {

    test("multiply overflow") {
        val MC = new MathContext(5, RoundingMode.HALF_EVEN)
        def BD(n: String) = BigDecimal(n, MC)
        val overflow = multiply(UBI(BD("99999"), 0, 0), UBI(BD("10"), 0, 0))
        assert(overflow.ubi.scale == 0)
        assert(overflow.ubi * BD("10").pow(-overflow.scale) == BD("999990"))
    }

    test("operate overflow") {
        val MC = new MathContext(2, RoundingMode.HALF_EVEN)
        def BD(n: String) = BigDecimal(n, MC)
        val overflow = operate(UBI(BD("99"), 0, 0), UBI(BD("1"), 0, 0), _+_, MC)
        assert(overflow.ubi.scale == 0)
        assert(overflow.scale == -1)
    }

    test("encoding overflow") {
        val MC = new MathContext(10, RoundingMode.HALF_EVEN)
        def BD(n: String) = BigDecimal(n, MC)
        // 10 digit number on the edge of precision overflow
        val edgedNumber = BD("8471353169")

        val op1 = UBI(edgedNumber, 0, 0)
        val op2 = UBI(BD("1"), 0, 192)
        // op2 triggers op1 encoding in 192 bits
        val (encodedOp1, _) = commonEncoding(op1, op2, MC)

        // no digit added to Unscaled Big Integer
        assert(encodedOp1.ubi.precision == edgedNumber.precision)
        // overflown precision rounded and added to scale
        assert(encodedOp1.scale == -58)
        assert(encodedOp1.bits == 192)
    }

    test("bitwise decoding") {
        // raise power once more with +1 offset since 2^1 = 2: see assertion below
        assert(BD2.pow(1 + 1).bigDecimal.unscaledValue == BigInteger.TWO.shiftLeft(1))
        assert(decode(UBI(BD2.pow(192 + 1), 0, 192)) == UBI(BD2, 0, 0))
    }

    test("bitwise decoding - partial") {
        assert(decode(UBI(BD2.pow(192), 0, 192), 96) == UBI(BD2.pow(96), 0, 96))
    }

    test("bitwise decoding - round up") {
        assert(decode(UBI(BD("3"), 0, 2)) == UBI(BD("1"), 0, 0))  // 3 / 2^2
    }

    test("bitwise decoding - round down") {
        assert(decode(UBI(BD("5"), 0, 2)) == UBI(BD("1"), 0, 0))  // 5 / 2^2
    }

    test("precision simplification - encoding") {
        val f = Fraction(0, UBI(BD("4"), 0, 193), UBI(BD("1"), 0, 0))
        assert(f == f.copy(numerator = UBI(BD2, 0, 192)))
    }

    test("precision simplification - gcd") {
        val f = Fraction(0, UBI(BD("4"), 0, 0), UBI(BD("20"), 0, 0))
        assert(f == Fraction(UBI(BD("1"), 0, 0), UBI(BD("5"), 0, 0)))
    }

    /* Edge case when bitwise decoding is applied to really small numbers:

       Seq(("1e0b384/2e0b192"), ("1e0b0/1e0b192")).toDF.agg(ubi_sum(value))

       +---------------+
       | ubi_sum(value)|
       +---------------+
       |2e0b192/0e0b192|
       +---------------+

       intermediate result before reducing encoding to 192 bits: 
       (1b576 + 2b192)/2b384

       - 1b576 is discarded when rounding bits to 192
       - 2b384 is also rounded off to 0b192 at this lower encoding level

       In such cases, exact instead of bitwise decoding should be applied.
    */
    test("denominator underflow: sum of small values with high encoding") {
        import spark.implicits._
        val result = Seq(("1e0b384/2e0b192"), ("1e0b0/1e0b192")).toDF.
            agg(expr("ubi_sum(value)")).first.getString(0)
        assert(!result.contains("/0"))
        assert(result.endsWith("e191b192"))  // make sure scale isn't dropped
    }

    /* note truncated precision in first case
       see https://www.scala-lang.org/api/current/scala/math/BigDecimal.html

      scala> BD("5")*BD(i)
      res56: scala.math.BigDecimal = 7.307233517426050516436365261019944E+48

      scala> BD(i)*BD("5")
      res57: scala.math.BigDecimal = 7307233517426050516436365261019944111893619851710

      scala> ((BD("5")*BD(i)).mc.getPrecision, (BD(i)*BD("5")).mc.getPrecision)
      res74: (Int, Int) = (34,49)
    */
    test("method precisions") {
        val multiplyO = multiply("1", "2").ubi
        val commonDNEO = commonDNE("1", "2") match {
            case (den, ln, rn) => Seq(den.ubi, ln.ubi, rn.ubi) }
        val scaleO = scale("1")
        val operateO = operate("1", "2", _+_).ubi
        val resolveO = resolve("1")

        val outputs = commonDNEO ++ Seq(multiplyO, scaleO, operateO, resolveO)
        // BigDecimal.precision != BigDecimal.mc.getPrecision
        val precisions = outputs.map(_.mc.getPrecision).toSet

        assert(precisions.size == 1)
        val precision = precisions.head
        assert(precision > 50 && precision == MC.getPrecision)
    }

}

