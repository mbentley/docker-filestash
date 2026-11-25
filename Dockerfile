# rebased/repackaged base image that only updates existing packages
FROM mbentley/alpine:latest
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"

# install gosu (to drop privileges)
RUN apk add --no-cache gosu

# cache busting arg; set to the size of the latest binaries so the download only re-runs when they change
ARG FILESTASH_SIZE

RUN mkdir -p /opt/filestash/data &&\
  cd /opt/filestash &&\
  wget -q -O filestash.bin "https://downloads.filestash.app/latest/filestash_linux_$(uname -m).bin" &&\
  chmod +x filestash.bin

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/filestash/filestash.bin"]
