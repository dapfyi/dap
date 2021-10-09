package d3centr.sparkubi

import org.apache.spark.sql.catalyst.expressions.{Expression, AttributeReference, Literal}
import org.apache.spark.sql.catalyst.trees.UnaryLike
import org.apache.spark.sql.catalyst.expressions.aggregate.DeclarativeAggregate
import org.apache.spark.sql.types.DataType
import org.apache.spark.unsafe.types.UTF8String
import Typecast._
import Arithmetic.add

case class Sum(child: Expression) 
    extends DeclarativeAggregate with UnaryLike[Expression] {

    override def nullable: Boolean = true
    override def dataType: DataType = child.dataType

    private lazy val sum = AttributeReference("ubi_sum", child.dataType)()
    override lazy val aggBufferAttributes: Seq[AttributeReference] = sum :: Nil
    override lazy val evaluateExpression: AttributeReference = sum

    override lazy val initialValues: Seq[Literal] = Seq(Literal.create(null, child.dataType))
    override lazy val updateExpressions: SE = Seq(AddAgg(sum, child))
    override lazy val mergeExpressions: SE = Seq(AddAgg(sum.left, sum.right))

    override protected def withNewChildInternal(newChild: Expression) = copy(child=newChild)
}
object Sum extends ExpressionCompanion {
    override val specs = makeSpecs("ubi_sum", (child: SE) => this(child.head))
}

case class AddAgg(left: Expression, right: Expression)
    extends NullPassingOperator(left, right) {

    override def symbol: String = "ubiAddAgg"
    override def eval: (Fraction, Fraction) => UTF8String = AddAgg.method

    override def copyDef: Copy = copy

}
object AddAgg {

    def method(buffer: Fraction, child: Fraction): UTF8String =
        if(buffer == null) child else if(child == null) buffer else 
            add(buffer, child)

}

