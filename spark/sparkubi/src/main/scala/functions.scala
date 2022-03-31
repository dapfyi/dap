package fyi.dap.sparkubi

import org.apache.spark.sql.Column
import org.apache.spark.sql.catalyst.expressions.aggregate.DeclarativeAggregate

object functions {

    private def withDeclarativeAggregate(
        func: DeclarativeAggregate,
        isDistinct: Boolean = false): Column = {
        new Column(func.toAggregateExpression(isDistinct))
    }

    def ubim(left: Column, right: Column): Column = 
        new Column(Multiply(left.expr, right.expr))

    def ubid(left: Column, right: Column): Column = 
        new Column(Divide(left.expr, right.expr))

    def ubia(left: Column, right: Column): Column = 
        new Column(Add(left.expr, right.expr))

    def ubis(left: Column, right: Column): Column = 
        new Column(Subtract(left.expr, right.expr))

    def ubi_resolve(ubi: Column): Column = new Column(Resolve(ubi.expr))

    def ubi_abs(ubi: Column): Column = new Column(Abs(ubi.expr))

    def ubi_sign(ubi: Column): Column = new Column(Sign(ubi.expr))

    def ubi_min(ubi: Column): Column = withDeclarativeAggregate { Min(ubi.expr) }

    def ubi_max(ubi: Column): Column = withDeclarativeAggregate { Max(ubi.expr) }

    def ubi_sum(ubi: Column): Column = withDeclarativeAggregate { Sum(ubi.expr) }

    def ubi_avg(ubi: Column): Column = withDeclarativeAggregate { Average(ubi.expr) }

}

