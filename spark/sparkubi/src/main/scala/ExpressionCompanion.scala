package d3centr.sparkubi

import org.apache.spark.sql.catalyst.FunctionIdentifier
import org.apache.spark.sql.catalyst.expressions.ExpressionInfo
import org.apache.spark.sql.catalyst.analysis.FunctionRegistry.FunctionBuilder

trait ExpressionCompanion {
    val specs: Tuple3[FunctionIdentifier, ExpressionInfo, FunctionBuilder]

    def makeSpecs(name: String, builder: FunctionBuilder) = (
        FunctionIdentifier(name),
        new ExpressionInfo(this.getClass.getCanonicalName, name),
        builder
    )
}

