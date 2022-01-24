import java.sql.Date
import spark.sql

def addPartitions(table: String, tomorrow: Date) = {

    val latest = sql(s"SHOW PARTITIONS $table").
        withColumn("date", split('partition, "=")(1)).
        agg(max('date)).first.getString(0)
    val first = if (latest == null) "CURRENT_DATE" else s"to_date('$latest')"

    val missingDates: Seq[Date] = 
        sql(s"SELECT sequence($first, to_date('$tomorrow'))").
        first.getSeq(0).drop(1)

    missingDates.map(date =>
        sql(s"ALTER TABLE $table ADD IF NOT EXISTS PARTITION (date='$date')")
    )

}

try {

    println("BLAKE ~ uniswap partition updates")
    val tomorrow = sql("SELECT date_add(CURRENT_DATE, 1)").first.getDate(0)

    addPartitions("uniswap.rated_swaps", tomorrow)
    addPartitions("uniswap.day_swaps", tomorrow)
    
    println("BLAKE ~ uniswap partitions updated")
    System.exit(0)

} catch {

    case error: Throwable =>
        println(s"Abnormal termination: $error")
        System.exit(1)

}

