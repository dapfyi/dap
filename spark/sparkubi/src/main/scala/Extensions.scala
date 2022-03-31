package fyi.dap.sparkubi

import org.apache.spark.sql.{SparkSessionExtensions, SparkSessionExtensionsProvider}

class Extensions extends SparkSessionExtensionsProvider {

    override def apply(ext: SparkSessionExtensions): Unit = {

        val unary = Seq(Resolve, Abs, Sign)
        val operators = Seq(Multiply, Divide, Add, Subtract) 
        val aggregates = Seq(Min, Max, Sum, Average)

        (unary ++ operators ++ aggregates).foreach(
            f => ext.injectFunction(f.specs)
        )

    }

}

