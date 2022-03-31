import org.apache.spark.sql.{DataFrame, Column}
import fyi.dap.sparkubi.functions._

class ScalaSQLSuite extends Spark {
    import spark.implicits._

    val Operand1 = "2"
    val Operand2 = "4"

    def str(df: DataFrame): String = df.first.getString(0)

    val operatorDF = Seq((Operand1, Operand2)).toDF
    def arithmetic(fun: (Column, Column) => Column): String =
        str(operatorDF.select(fun('_1, '_2)))

    val aggregateDF = Seq((Operand1), (Operand2)).toDF
    def statistic(fun: Column => Column): String =
        str(aggregateDF.select(fun('value)))

    test("ubim") {
        assert(arithmetic(ubim) == "8e0b0/1e0b0")
    }

    test("ubid") {
        assert(arithmetic(ubid) == "2e0b0/4e0b0")
    }

    test("ubia") {
        assert(arithmetic(ubia) == "6e0b0/1e0b0")
    }

    test("ubis") {
        assert(arithmetic(ubis) == "-2e0b0/1e0b0")
    }

    test("ubi_min") {
        assert(statistic(ubi_min) == "2e0b0/1e0b0")
    }

    test("ubi_max") {
        assert(statistic(ubi_max) == "4e0b0/1e0b0")
    }

    test("ubi_sum") {
        assert(statistic(ubi_sum) == "6e0b0/1e0b0")
    }

    test("ubi_avg") {
        assert(statistic(ubi_avg) == "6e0b0/2e0b0")
    }

    test("ubi_resolve") {
        import spark.implicits._
        val result = Seq(("2e-1b1")).toDF.select(ubi_resolve('value))
        assert(str(result) == "10")
    }

    test("ubi_abs") {
        import spark.implicits._
        val result = Seq(("-1")).toDF.select(ubi_abs('value))
        assert(str(result) == "1e0b0/1e0b0")
    }

    test("ubi_sign") {
        import spark.implicits._
        val result = Seq(("0")).toDF.select(ubi_sign('value))
        assert(result.first.getInt(0) == 0)
    }

}

