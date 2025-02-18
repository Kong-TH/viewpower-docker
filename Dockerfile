FROM debian:bookworm-slim as builder

RUN apt update
RUN apt install wget -y

RUN mkdir /build
WORKDIR /build
RUN wget -c https://www.power-software-download.com/viewpower/ViewPower_linux_x64_text.tar.gz
RUN tar -xvzf ViewPower_linux_x64_text.tar.gz
RUN rm ViewPower_linux_x64_text.tar.gz

FROM debian:bookworm-slim as runtime

RUN mkdir /install
WORKDIR /install
COPY --from=builder /build/ViewPower_linux_x64_text.sh /install/ViewPower_linux_x64_text.sh

RUN apt update
RUN apt install sudo lib32z1 curl -y

RUN echo "o\n/opt/ViewPower\nn\nn\n" | ./ViewPower_linux_x64_text.sh
RUN rm ViewPower_linux_x64_text.sh

WORKDIR /opt/ViewPower
RUN ./upsMonitor start && sleep 10 && ./upsMonitor stop

RUN mkdir -p /opt/ViewPower/default_data
RUN cp -a /opt/ViewPower/config /opt/ViewPower/default_data/config
RUN cp -a /opt/ViewPower/datas /opt/ViewPower/default_data/datas
RUN cp -a /opt/ViewPower/datalog /opt/ViewPower/default_data/datalog
RUN cp -a /opt/ViewPower/log /opt/ViewPower/default_data/log

COPY ./entrypoint /opt/ViewPower/entrypoint
RUN chmod +x ./entrypoint
ENTRYPOINT ["./entrypoint"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sSf http://localhost:15178 || exit 1
