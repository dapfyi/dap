package fyi.dap.sparkubi

import org.apache.spark.sql.catalyst.expressions.Expression
import org.apache.spark.sql.catalyst.InternalRow
import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.sql.catalyst.expressions.codegen.{
    CodegenContext, ExprCode, CodeGenerator}
import org.apache.spark.sql.catalyst.expressions.codegen.Block._
import Typecast._

abstract class NullPassingOperator(left: Expression, right: Expression) 
    extends UBIOperator(left, right) with Serializable {

    // bypass nullSafeEval
    override def eval(input: InternalRow): Any = {
        val (input1, input2) = (left.eval(input), right.eval(input))
        eval(input1.asInstanceOf[UTF8String], input2.asInstanceOf[UTF8String])
    }

    // override default short circuits on null values for custom method handling
    override protected def doGenCode(ctx: CodegenContext, ev: ExprCode): ExprCode = {

        // original doGenCode transformation of function argument
        val f: (String, String) => String =
            (left, right) => s"$className.method($S2FName($left), $S2FName($right))"
        // follow-up defineCodeGen transformation of function argument
        val ff: (String, String) => String =
            (eval1, eval2) => s"${ev.value} = ${f(eval1, eval2)};"

        val leftGen = left.genCode(ctx)
        val rightGen = right.genCode(ctx)
        val resultCode = ff(leftGen.value, rightGen.value)

        val nullPassingEval = s"""
            ${leftGen.code}
            ${rightGen.code}
            ${ev.isNull} = false;  // resultCode could change nullability
            $resultCode
        """

        ev.copy(code = code"""
            boolean ${ev.isNull} = true;
            ${CodeGenerator.javaType(dataType)} ${ev.value} =
                ${CodeGenerator.defaultValue(dataType)};
            $nullPassingEval
        """)

    }

}

