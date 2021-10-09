package d3centr.sparkubi

import Arithmetic.{commonEncoding, multiply}

trait Comparator {

    def comparableNumerators(buffer: Fraction, child: Fraction): Tuple2[UBI, UBI] =
        if (buffer.denominator == child.denominator)
            commonEncoding(buffer.numerator, child.numerator)
        else commonEncoding(
            multiply(buffer.numerator, child.denominator),
            multiply(child.numerator, buffer.denominator))

}

