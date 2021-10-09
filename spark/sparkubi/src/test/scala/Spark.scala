import org.apache.spark.sql.SparkSession
import org.scalatest.{FunSuite, BeforeAndAfterAll}
import d3centr.sparkubi.Extensions

trait Spark extends FunSuite with BeforeAndAfterAll {

    lazy val spark = SparkSession.
        builder.
        master("local[1]").
        withExtensions(new Extensions).
        config("spark.ui.enabled", "false").
        getOrCreate

    override def afterAll: Unit = {
        spark.stop
        SparkSession.clearActiveSession
        SparkSession.clearDefaultSession
    }

    def sql(query: String) = spark.sql("SELECT " + query).first.getString(0)

}

