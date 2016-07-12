FROM alpine:3.4
RUN apk --no-cache add bash openssh

RUN mkdir -p /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_*key*

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh

VOLUME /etc/ssh
VOLUME /keys

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]

