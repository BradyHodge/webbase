FROM alpine:3.14

RUN apk add --no-cache nginx git

RUN mkdir -p /var/www/html

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

ENV GIT_URL=""
ENV PORT=80

CMD ["/start.sh"]