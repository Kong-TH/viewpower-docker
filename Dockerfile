#New update for ViewPower Version 1.04-25210-b1

# ===========================
# Build Stage
# ===========================
FROM debian:bookworm-slim as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    curl \
    wget \
    zlib1g \
    tar \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /build
WORKDIR /build
RUN wget -c https://www.power-software-download.com/viewpower/ViewPower_linux_x64_text.tar.gz
RUN tar -xvzf ViewPower_linux_x64_text.tar.gz
RUN rm ViewPower_linux_x64_text.tar.gz

# ===========================
# Runtime Stage (ARM64)
# ===========================
FROM debian:bookworm-slim as runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    curl \
    libusb-1.0-0 \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/fex.deb https://launchpad.net/~fex-emu/+archive/ubuntu/fex/+build/31290640/+files/fex-emu-armv8.2_2509.1~q_arm64.deb \
    && apt-get install -y /tmp/fex.deb \
    && rm /tmp/fex.deb

RUN mkdir /install
WORKDIR /install
COPY --from=builder /build/ViewPower_linux_x64_text.sh /install/ViewPower_linux_x64_text.sh

RUN echo "o\n/opt/ViewPower\nn\nn\n" | ./ViewPower_linux_x64_text.sh
RUN rm ViewPower_linux_x64_text.sh

WORKDIR /opt/ViewPower
RUN ./fex ./upsMonitor start && sleep 60 && ./fex ./upsMonitor stop

RUN mkdir -p /opt/ViewPower/default_data && \
    cp -a /opt/ViewPower/config /opt/ViewPower/default_data/config && \
    cp -a /opt/ViewPower/datas /opt/ViewPower/default_data/datas && \
    cp -a /opt/ViewPower/datalog /opt/ViewPower/default_data/datalog && \
    cp -a /opt/ViewPower/log /opt/ViewPower/default_data/log

# ===========================
# Add shutdown script
# ===========================
COPY ./shutdown.sh /usr/local/bin/shutdown.sh
RUN chmod +x /usr/local/bin/shutdown.sh

# Set volume for trigger file
VOLUME ["/ups-events"]

# ===========================
# Add entrypoint
# ===========================
COPY ./entrypoint /opt/ViewPower/entrypoint
RUN chmod +x /opt/ViewPower/entrypoint
ENTRYPOINT ["./entrypoint"]

# ===========================
# Health Check
# ===========================
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sSf http://localhost:15178 || exit 1