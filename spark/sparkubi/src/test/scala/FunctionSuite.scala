import org.apache.spark.sql.{DataFrame, Column}
import org.apache.spark.sql.functions.expr
import fyi.dap.sparkubi.Typecast._
import fyi.dap.sparkubi.Unary.resolve

class FunctionSuite extends Spark {

    val i = "1461446703485210103287273052203988822378723970342"
    val I = BD(i)
    val iTimes2 = I * BD2

    test("ubiM operator") {
        val (two, six) = ("2e0/1e0", "6e0b0/1e0b0")
        assert(sql(s"ubiM('$two', '3')") == six)
        assert(sql(s"ubiM('$two', '-3')") == "-" + six)
        assert(sql(s"ubiM('-$two', '-3')") == six)
    }

    test("decimal simplification") {
        assert(sql(s"ubiM('5e4b6/4e0b0', '3e0b0/5e8b6')") == "15e0b6/20e4b6")
    }

    test("ubiD operator") {
        assert(sql(s"ubiD('${i}e18b96', '2/1e8')") == s"${i}e26b96/2e0b0")
    }

    test("ubiA operator") {
        assertOperation(_+_, "ubiA")
    }

    test("ubiS operator") {
        assertOperation(_-_, "ubiS")
    }

    test("numerator encoding") {
        val op1 = "1817498247588271701025599504023987558239373578471353169e0b192/1e0b0"
        val op2 = "127863648095726686335945937931655110372290842288450625e0b188/1e0b0"
        val expected = "-228320121943355280349535502882494207717279898143856831e0b192/1e0b0"
        assert(sql(s"ubiS('$op1', '$op2')") == expected)
    }

    test("ubi_resolve") {
        assert(BD(sql(s"ubi_resolve('${i}e26b96/2e8')")) == 
            BD(i) / BD2 / BD10.pow(26 - 8) / BD2.pow(96))
    }

    test("resolve null") {
        assert(resolve(null) == null)
    }

    test("double pattern") {
       assert(sql("ubi_resolve('8.737221047432324E-4')") == "0.0008737221047432324")
    }

    test("ubi_abs") {
        assert(sql("ubi_abs('-3e1b1/-2')") == "3e1b1/2e0b0")
    }

    test("ubi_sign") {
        assert(spark.sql("SELECT ubi_sign('3/-2')").first.getInt(0) == -1)
        assert(spark.sql("SELECT ubi_sign('0')").first.getInt(0) == 0)
        assert(spark.sql("SELECT ubi_sign('-3/-2')").first.getInt(0) == 1)
        assert(spark.sql("SELECT ubi_sign('3/2')").first.getInt(0) == 1)
    }

    test("ubi_max aggregate") {
        import spark.implicits._
        val max = (BD(i)+BD10).toString
        val df = Seq((BD(i).toString), (max), (null), ((BD(i)+BD2).toString)).toDF
        assert(agg(df, "ubi_max") == max + "e0b0/1e0b0")
    }

    test("ubi_min aggregate") {
        import spark.implicits._
        val min = BD(i).toString
        val df = Seq(
            ((BD(i)+BD10).toString), (min), (null), ((BD(i)+BD2).toString)).toDF
        assert(agg(df, "ubi_min") == min + "e0b0/1e0b0")
    }

    test("ubi_sum aggregate") {
        import spark.implicits._
        val sum = (BD(i) + BD2 + BD10).toString + "e0b0/1e0b0"
        val df = Seq((i), ("2"), (null), ("10")).toDF
        assert(agg(df, "ubi_sum") == sum)
    }

    test("ubi_avg aggregate") {
        import spark.implicits._
        val avg = (BD(i) + BD2 + BD10).toString + "e0b0/3e0b0"
        val df = Seq((i), ("2"), (null), ("10")).toDF
        assert(agg(df, "ubi_avg") == avg)
    }

    test("null sum") {
        import spark.implicits._
        val data: Seq[String] = Seq((null), (null))
        assert(agg(data.toDF, "ubi_sum") == "")
    }

    test("null average") {
        import spark.implicits._
        val data: Seq[String] = Seq((null), (null))
        assert(agg(data.toDF, "ubi_avg") == "")
    }

    def agg(df: DataFrame, name: String) = df.agg(expr(s"$name(value)")).first.getString(0)

    def assertOperation(op: (BigDecimal, BigDecimal) => BigDecimal, ubiOp: String,
        simplifyByGCD: Boolean = false) = {

        val (rightOperand, leftOperand) = (s"${i}e18b96/3", "1/5e10b96")

        /* subtracting left from right operand...
           Common Denominator:                            (5${i}e28b192 - 3) / 15e10b96
           Common Encoding of numerator operands: (5${i}e28 - 3 * 2^192)b192 / 15e10b96
           Let Y be the expression between brackets:                   Yb192 / 15e10b96
        */
        val Y = op(I*BD("5")*BD10.pow(-28), BD("3")*BD2.pow(192))
        /*
          We benchmark BigDecimal numInt in main code with BigInt numInt in test:
          a BigDecimal is rounded beyond max precision.
        */
        // wrap java.math.BigInteger in scala BigInt for / operator
        val numInt = BigInt(Y.bigDecimal.unscaledValue)
        /*
           Simplified decimals, Y.scale (28) / den. scale:  ${numInt}e18b192 / 15e0b96
        */

        val denInt = BigInt(15)
        val (leastNumInt, leastDenInt) = if (simplifyByGCD) {

            // Greatest Common Divisor between numInt and denInt
            val divisor = numInt.gcd(denInt)
            (numInt / divisor, denInt / divisor)

        } else (numInt, denInt)

        val result = sql(s"${ubiOp}('$rightOperand', '$leftOperand')")
        assert(result == s"${leastNumInt}e18b192/${leastDenInt}e0b96")

    }

}

