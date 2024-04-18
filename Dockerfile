# Start from the existing working base image
#FROM existdb/existdb:6.0.1
FROM --platform=linux/amd64 wsalesky/srophe-base:1.0.1

# Copy over all the files you need 
COPY autodeploy/*.xar /exist/autodeploy/
COPY conf/*.xml /exist/etc/webapp/WEB-INF/
COPY conf/controller-config.xml /exist/etc/webapp/WEB-INF/
COPY conf/collection.xconf.init /exist/etc/
COPY conf/exist-webapp-context.xml /exist/etc/jetty/webapps/
COPY conf/conf.xml /exist/etc/conf.xml
#COPY build/entrypoint.sh /entrypoint.sh

EXPOSE 8080 8443

ENV JAVA_TOOL_OPTIONS \
-Dfile.encoding=UTF8 \
-Dsun.jnu.encoding=UTF-8 \
-Djava.awt.headless=true \
-Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
-Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
-Dlog4j.configurationFile=/exist/etc/log4j2.xml \
-Dexist.home=/exist \
-Dexist.configurationFile=/exist/etc/conf.xml \
-Djetty.home=/exist \
-Dexist.jetty.config=/exist/etc/jetty/standard.enabled-jetty-configs \
-XX:+UseG1GC \
-XX:+UseStringDeduplication \
-XX:+UseContainerSupport \
-XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
-XX:+ExitOnOutOfMemoryError \
-XX:-HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath=/exist/heapDump/exist-memory-dump.hprof \
-XX:InitiatingHeapOccupancyPercent=70

HEALTHCHECK CMD [ "java", \
"org.exist.start.Main", "client", \
"--no-gui",  \
"--user", "guest", "--password", "guest", \
"--xpath", "system:get-version()" ]


ENTRYPOINT [ "java", \
"org.exist.start.Main"]

CMD ["jetty" ]
