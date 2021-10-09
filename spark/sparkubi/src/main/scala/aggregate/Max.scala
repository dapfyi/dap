package d3centr.sparkubi

import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.catalyst.expressions.{Expression, AttributeReference, Literal}
import org.apache.spark.sql.catalyst.trees.UnaryLike
import org.apache.spark.sql.catalyst.expressions.aggregate.DeclarativeAggregate
import org.apache.spark.sql.types.DataType
import Typecast._
import Arithmetic.scale

case class Max(child: Expression) 
    extends DeclarativeAggregate with UnaryLike[Expression] {

    override def nullable: Boolean = true
    override def dataType: DataType = child.dataType

    private lazy val max = AttributeReference("ubi_max", child.dataType)()
    override lazy val aggBufferAttributes: Seq[AttributeReference] = max :: Nil
    override lazy val evaluateExpression: AttributeReference = max

    override lazy val initialValues: Seq[Literal] = Seq(Literal.create(null, child.dataType))
    override lazy val updateExpressions: SE = Seq(Greatest(max, child))
    override lazy val mergeExpressions: SE = Seq(Greatest(max.left, max.right))

    override protected def withNewChildInternal(newChild: Expression) = copy(child=newChild)
}
object Max extends ExpressionCompanion { 
    override val specs = makeSpecs("ubi_max", (child: SE) => this(child.head))
}

case class Greatest(left: Expression, right: Expression) 
    extends NullPassingOperator(left, right) {

    override def symbol: String = "ubiGreatest"
    override def eval: (Fraction, Fraction) => UTF8String = Greatest.method

    override def copyDef: Copy = copy

}
object Greatest extends Comparator {

    def method(buffer: Fraction, child: Fraction): UTF8String = 
        if(buffer == null) child else if(child == null) buffer else {
            val (comparableBuffer, comparableChild) = comparableNumerators(buffer, child)
            if (scale(comparableChild) > scale(comparableBuffer)) child else buffer
        }

}

