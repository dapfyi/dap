package d3centr.sparkubi

import Typecast.BD

case class UBI(ubi: BigDecimal, scale: Int, bits: Int) {
    require(ubi.scale == 0, s"ubi BigDecimal scale is ${ubi.scale} instead of 0")
    def margin = ubi.mc.getPrecision - ubi.precision
}

object UBI {

    def apply(
        rescale: Boolean, 
        ubi: BigDecimal, 
        scale: Int, 
        bits: Int
    ): UBI = if (rescale && ubi.scale < 0) UBI(
        BD(ubi.bigDecimal.unscaledValue), 
        scale + ubi.scale, 
        bits
    ) else UBI(ubi, scale, bits)

}

