package fyi.dap.sparkubi

import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.types.{DataType, DoubleType, IntegerType}
import org.apache.spark.sql.catalyst.expressions.{ 
    Expression, UnaryExpression, NullIntolerant, String2StringExpression}
import org.apache.spark.sql.catalyst.expressions.codegen.{CodegenContext, ExprCode}
import Typecast._

case class Resolve(child: Expression) 
    extends UnaryExpression with String2StringExpression {

    override def prettyName: String = "ubi_resolve"
    override def convert(v: UTF8String): UTF8String = Resolve.method(v)

    override def doGenCode(ctx: CodegenContext, ev: ExprCode): ExprCode = {
        defineCodeGen(ctx, ev, c => s"fyi.dap.sparkubi.Resolve.method($S2FName($c))")
    }

    override protected def withNewChildInternal(newChild: Expression) = 
        copy(child=newChild) 

}
object Resolve extends ExpressionCompanion { 
    override val specs = makeSpecs("ubi_resolve", (child: SE) => this(child.head))
    def method(f: Fraction): UTF8String = UTF8String.fromString(
        if(f == null) "" else Unary.resolve(f).toString
    )
}

case class Abs(child: Expression) extends 
    UnaryExpression with String2StringExpression {

    override def prettyName: String = "ubi_abs"
    override def convert(v: UTF8String): UTF8String = Abs.method(v)

    override def doGenCode(ctx: CodegenContext, ev: ExprCode): ExprCode = {
        defineCodeGen(ctx, ev, c => s"fyi.dap.sparkubi.Abs.method($S2FName($c))")
    }

    override protected def withNewChildInternal(newChild: Expression) = 
        copy(child=newChild) 

}
object Abs extends ExpressionCompanion { 
    override val specs = makeSpecs("ubi_abs", (child: SE) => this(child.head))
    def method(f: Fraction): UTF8String = Unary.abs(f)
}

case class Sign(child: Expression) extends UnaryExpression {

    override def dataType: DataType = IntegerType
    override def prettyName: String = "ubi_sign"

    override protected def nullSafeEval(input: Any): Any =
        Unary.sign(input.asInstanceOf[UTF8String])

    override def doGenCode(ctx: CodegenContext, ev: ExprCode): ExprCode = {
        defineCodeGen(ctx, ev, c => s"fyi.dap.sparkubi.Unary.sign($S2FName($c))")
    }

    override protected def withNewChildInternal(newChild: Expression) = 
        copy(child=newChild) 

}
object Sign extends ExpressionCompanion { 
    override val specs = makeSpecs("ubi_sign", (child: SE) => this(child.head))
}

