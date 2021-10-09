package blake.uniswap

import org.apache.log4j.Logger

object Log {

    val logger = Logger.getRootLogger
    def info(s: String) = logger.info(s)

}

