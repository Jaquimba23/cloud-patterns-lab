FROM ubuntu:22.04
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default
COPY app /srv/app
COPY app.conf /etc/nginx/conf.d/app.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
