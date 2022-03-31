package fyi.dap.sparkubi

import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.types.{DataType, StringType}
import org.apache.spark.sql.catalyst.expressions.{Expression, BinaryOperator}
import org.apache.spark.sql.catalyst.expressions.codegen.{CodegenContext, ExprCode}
import Typecast._

abstract class UBIOperator(left: Expression, right: Expression) 
    extends BinaryOperator with Serializable {

    val className = this.getClass.getCanonicalName.stripSuffix("$")

    def eval: (Fraction, Fraction) => UTF8String
    type Copy = (Expression, Expression) => UBIOperator
    def copyDef: Copy

    override def inputType: DataType = StringType
    override def dataType: DataType = inputType

    override protected def nullSafeEval(left: Any, right: Any): Any =
        eval(left.asInstanceOf[UTF8String], right.asInstanceOf[UTF8String])

    override protected def doGenCode(ctx: CodegenContext, ev: ExprCode): ExprCode = {
        defineCodeGen(ctx, ev, (left, right) => 
            s"$className.method($S2FName($left), $S2FName($right))")
    }

    override protected def withNewChildrenInternal(
        newLeft: Expression, newRight: Expression) = {
        // v1 and v2 are named arguments of Function2 apply method's definition
        copyDef(v1=newLeft, v2=newRight)
    }

}

