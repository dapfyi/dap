package fyi.dap.sparkubi

import org.apache.spark.sql.catalyst.expressions.Expression
import org.apache.spark.unsafe.types.UTF8String
import Arithmetic.{multiply, divide, add, subtract}
import Typecast._

case class Multiply(left: Expression, right: Expression) 
    extends UBIOperator(left, right) {

    override def symbol: String = "ubim"
    override def eval: (Fraction, Fraction) => UTF8String = Multiply.method

    override def copyDef: Copy = copy 
}
object Multiply extends ExpressionCompanion { 
    override val specs = makeSpecs("ubim", (args: SE) => this(args(0), args(1)))
    def method(left: Fraction, right: Fraction): UTF8String = multiply(left, right)
}

case class Divide(left: Expression, right: Expression) 
    extends UBIOperator(left, right) {

    override def symbol: String = "ubid"
    override def eval: (Fraction, Fraction) => UTF8String = Divide.method

    override def copyDef: Copy = copy 
}
object Divide extends ExpressionCompanion { 
    override val specs = makeSpecs("ubid", (args: SE) => this(args(0), args(1)))
    def method(left: Fraction, right: Fraction): UTF8String = divide(left, right)
}

case class Add(left: Expression, right: Expression) 
    extends UBIOperator(left, right) {

    override def symbol: String = "ubia"
    override def eval: (Fraction, Fraction) => UTF8String = Add.method

    override def copyDef: Copy = copy 
}
object Add extends ExpressionCompanion { 
    override val specs = makeSpecs("ubia", (args: SE) => this(args(0), args(1)))
    def method(left: Fraction, right: Fraction): UTF8String = add(left, right)
}

case class Subtract(left: Expression, right: Expression) 
    extends UBIOperator(left, right) {

    override def symbol: String = "ubis"
    override def eval: (Fraction, Fraction) => UTF8String = Subtract.method

    override def copyDef: Copy = copy
}
object Subtract extends ExpressionCompanion {
    override val specs = makeSpecs("ubis", (args: SE) => this(args(0), args(1)))
    def method(left: Fraction, right: Fraction): UTF8String = subtract(left, right)
}

