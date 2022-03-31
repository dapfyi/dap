package fyi.dap.sparkubi

import org.apache.spark.sql.catalyst.expressions.{
    Expression, AttributeReference, Literal, If}
import org.apache.spark.sql.catalyst.trees.UnaryLike
import org.apache.spark.sql.catalyst.expressions.aggregate.DeclarativeAggregate
import org.apache.spark.sql.catalyst.dsl.expressions._
import org.apache.spark.sql.types.{DataType, LongType}
import org.apache.spark.unsafe.types.UTF8String
import Typecast._
import Arithmetic.divide

case class Average(child: Expression) 
    extends DeclarativeAggregate with UnaryLike[Expression] {

    override def nullable: Boolean = true
    override def dataType: DataType = child.dataType

    private lazy val sum = AttributeReference("ubi_sum", child.dataType)()
    private lazy val count = AttributeReference("count", LongType)()

    override lazy val aggBufferAttributes = sum :: count :: Nil

    override lazy val initialValues: Seq[Literal] = Seq(
        /* sum = */ Literal.create(null, child.dataType),
        /* count = */ Literal(0L)
    )

    override lazy val updateExpressions: SE = Seq(
        /* sum = */ AddAgg(sum, child),
        /* count = */ If(child.isNull, count, count + 1L)
    )

    override lazy val mergeExpressions: SE = Seq(
        /* sum = */ AddAgg(sum.left, sum.right),
        /* count = */ count.left + count.right
    )

    override lazy val evaluateExpression = DivideEval(sum, count.cast(child.dataType)) 

    override protected def withNewChildInternal(newChild: Expression) = copy(child=newChild)
}
object Average extends ExpressionCompanion {
    override val specs = makeSpecs("ubi_avg", (child: SE) => this(child.head))
}

case class DivideEval(left: Expression, right: Expression)
    extends NullPassingOperator(left, right) {

    override def symbol: String = "ubiDivideEval"
    override def eval: (Fraction, Fraction) => UTF8String = DivideEval.method

    override def copyDef: Copy = copy

}
object DivideEval {

    def method(sum: Fraction, count: Fraction): UTF8String =
        if(sum == null) UTF8String.fromString("") else divide(sum, count)

}

