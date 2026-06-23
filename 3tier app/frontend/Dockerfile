FROM busybox:1.36 AS assets
WORKDIR /site
COPY index.html ./index.html

FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=assets /site/index.html /usr/share/nginx/html/index.html
EXPOSE 8080
USER 101
