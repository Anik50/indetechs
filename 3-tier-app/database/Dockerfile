FROM busybox:1.36 AS init
WORKDIR /init
COPY init.sql ./10-init.sql

FROM postgres:16-alpine
COPY --from=init /init/10-init.sql /docker-entrypoint-initdb.d/10-init.sql
