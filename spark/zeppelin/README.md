_Apache Zeppelin on DaP clusters is an aborted experiment unless the project upgrades to Java 11._

# Test
- Update `templates/zeppelin-server.yaml`.
- Install Zeppelin `./install.sh --app zeppelin`.
- Access UI `kubectl port-forward svc/zeppelin-server 8080:80`.
- Run `spark.sql("SELECT CAST(pow(2, 96) AS decimal(38,0))").show` in a notebook cell.

## Failure
- `java.lang.NoSuchMethodError: java.nio.ByteBuffer.flip()Ljava/nio/ByteBuffer;`: 

Missing method in Zeppelin Java 8 release, incompatible with Java 11 Spark distribution.

