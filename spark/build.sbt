
ThisBuild / sbtVersion := "1.5.5"
ThisBuild / scalaVersion := "2.12.15"

lazy val settings = Seq(
    unmanagedBase := baseDirectory.value / "../lib",
    javaOptions ++= Seq("-Xms512M", "-Xmx2048M", "-XX:+CMSClassUnloadingEnabled"),
    Test / fork := true,
    Test / parallelExecution := false,
    Test / javaOptions ++= Seq("-Xms6G", "-Xmx6G", "-XX:+CMSClassUnloadingEnabled")
)

lazy val global = project
    .in(file("."))
    .settings(settings)
    .aggregate(
        sparkubi,
        uniswap
    )

lazy val dependencies = Seq(
    "org.apache.spark" %% "spark-core" % "3.2.0" % "provided",
    "org.apache.spark" %% "spark-streaming" % "3.2.0" % "provided",
    "io.delta" %% "delta-core" % "1.1.0" % "provided",
    "com.holdenkarau" %% "spark-testing-base" % "3.2.0_1.1.1" % Test excludeAll(
        ExclusionRule(organization = "org.apache.spark"))
)

lazy val sparkubi = project
    .settings(
        name := "SparkUBI",
        version := "1.0.0",
        settings,
        libraryDependencies += "org.scalatest" %% "scalatest" % "3.0.5" % Test,
        artifactName := { (sv: ScalaVersion, module: ModuleID, artifact: Artifact) =>
            "sparkubi." + artifact.extension },
        Test / envVars := Map("SPARKUBI_PROFILING" -> "false")
    )
  
lazy val uniswap = project
    .settings(
        name := "Uniswap",
        version := "1.0.0",
        settings,
        libraryDependencies ++= dependencies,
        libraryDependencies ++= Seq(
            "org.apache.kafka" % "kafka-clients" % "2.8.0" % "provided"),
        artifactName := { (sv: ScalaVersion, module: ModuleID, artifact: Artifact) =>
            "uniswap." + artifact.extension },
        Test / envVars := Map(
            "DATA_BUCKET" -> "dummy", 
            "DELTA_BUCKET" -> "dummy"),
        Test / javaOptions ++= Seq("-Dspark.driver.blake.epoch=0")
    )

