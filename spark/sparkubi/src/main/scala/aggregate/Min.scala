package d3centr.sparkubi

import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.catalyst.expressions.{Expression, AttributeReference, Literal}
import org.apache.spark.sql.catalyst.trees.UnaryLike
import org.apache.spark.sql.catalyst.expressions.aggregate.DeclarativeAggregate
import org.apache.spark.sql.types.DataType
import Typecast._
import Arithmetic.scale

case class Min(child: Expression) 
    extends DeclarativeAggregate with UnaryLike[Expression] {

    override def nullable: Boolean = true
    override def dataType: DataType = child.dataType

    private lazy val min = AttributeReference("ubi_min", child.dataType)()
    override lazy val aggBufferAttributes: Seq[AttributeReference] = min :: Nil
    override lazy val evaluateExpression: AttributeReference = min

    override lazy val initialValues: Seq[Literal] = Seq(Literal.create(null, child.dataType))
    override lazy val updateExpressions: SE = Seq(Least(min, child))
    override lazy val mergeExpressions: SE = Seq(Least(min.left, min.right))

    override protected def withNewChildInternal(newChild: Expression) = copy(child=newChild)
}
object Min extends ExpressionCompanion { 
    override val specs = makeSpecs("ubi_min", (child: SE) => this(child.head))
}

case class Least(left: Expression, right: Expression) 
    extends NullPassingOperator(left, right) {

    override def symbol: String = "ubiLeast"
    override def eval: (Fraction, Fraction) => UTF8String = Least.method

    override def copyDef: Copy = copy

}
object Least extends Comparator {

    def method(buffer: Fraction, child: Fraction): UTF8String =
        if(buffer == null) child else if(child == null) buffer else {
            val (comparableBuffer, comparableChild) = comparableNumerators(buffer, child)
            if (scale(comparableChild) < scale(comparableBuffer)) child else buffer
        }

}

