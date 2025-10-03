# New update for ViewPower Version 1.04-25210-b1

# ===========================
# Build Stage
# ===========================
FROM ubuntu:latest AS builder

# Install minimal dependencies for downloading ViewPower
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    tar \
    && rm -rf /var/lib/apt/lists/* 

RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*

# Download and extract ViewPower installer
RUN mkdir /build
WORKDIR /build
RUN wget -c https://www.power-software-download.com/viewpower/ViewPower_linux_x64_text.tar.gz
RUN tar -xvzf ViewPower_linux_x64_text.tar.gz
RUN rm ViewPower_linux_x64_text.tar.gz

# ===========================
# Runtime Stage
# ===========================
FROM ubuntu:latest

# ---------------------------
# Install dependencies for FEX-Emu and ViewPower
# ---------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    libgl1-mesa-dev \
    libfuse2 \
    squashfs-tools \
    zenity \
    lib32z1 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------
# Download and install FEX-Emu arm64 deb packages
# ---------------------------
RUN curl -L -o /tmp/fex-emu.deb \
    "https://blueprints.launchpad.net/~fex-emu/+archive/ubuntu/fex/+build/31290640/+files/fex-emu-armv8.2_2509.1~q_arm64.deb" \
    && curl -L -o /tmp/libfex-emu-dev.deb \
    "https://blueprints.launchpad.net/~fex-emu/+archive/ubuntu/fex/+build/31290640/+files/libfex-emu-armv8.2-dev_2509.1~q_arm64.deb"

# Install FEX-Emu
RUN dpkg -i /tmp/libfex-emu-dev.deb /tmp/fex-emu.deb || apt-get install -y -f
RUN rm /tmp/fex-emu.deb /tmp/libfex-emu-dev.deb

# ---------------------------
# Setup default RootFS for FEX-Emu
# ---------------------------
RUN mkdir -p /root/.fex-emu/RootFS
RUN curl -L -o /root/.fex-emu/RootFS/Ubuntu_22_10.sqsh \
    "https://rootfs.fex-emu.gg/Ubuntu_22_10/2023-05-19/Ubuntu_22_10.sqsh"
ENV FEX_ROOTFS="/root/.fex-emu/RootFS/Ubuntu_22_10.sqsh"

# ---------------------------
# Copy ViewPower installer from build stage
# ---------------------------
RUN mkdir /install
WORKDIR /install
COPY --from=builder /build/ViewPower_linux_x64_text.sh /install/ViewPower_linux_x64_text.sh

# ---------------------------
# Install ViewPower using FEXBash
# ---------------------------
RUN echo "o\n/opt/ViewPower\nn\nn\n" | FEXBash ./ViewPower_linux_x64_text.sh
RUN rm ViewPower_linux_x64_text.sh

# ---------------------------
# Prepare default data and run initial upsMonitor
# ---------------------------
WORKDIR /opt/ViewPower
RUN FEXBash ./upsMonitor start && sleep 60 && FEXBash ./upsMonitor stop

RUN mkdir -p /opt/ViewPower/default_data \
    && cp -a /opt/ViewPower/config /opt/ViewPower/default_data/config \
    && cp -a /opt/ViewPower/datas /opt/ViewPower/default_data/datas \
    && cp -a /opt/ViewPower/datalog /opt/ViewPower/default_data/datalog \
    && cp -a /opt/ViewPower/log /opt/ViewPower/default_data/log

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
