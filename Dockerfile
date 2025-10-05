# ===========================
# Builder stage (x86_64)
# ===========================
# Use x86_64 Debian to run the ViewPower installer
FROM --platform=linux/amd64 debian:bookworm-slim AS builder

# Install dependencies for installer
RUN apt update && apt install -y wget tar && rm -rf /var/lib/apt/lists/*

# Download and extract installer
WORKDIR /build
RUN wget -c https://www.power-software-download.com/viewpower/ViewPower_linux_x64_text.tar.gz
RUN tar -xvzf ViewPower_linux_x64_text.tar.gz
RUN rm ViewPower_linux_x64_text.tar.gz

# Make installer executable
RUN chmod +x ./ViewPower_linux_x64_text.sh

# Copy silent install config file
COPY response.varfile /build/response.varfile

# Run installer automatically (x86_64)
RUN ./ViewPower_linux_x64_text.sh -q -varfile /build/response.varfile

# Pre-installed ViewPower is now in /opt/ViewPower inside builder
# ===========================
# Runtime stage (ARM64)
# ===========================
# Use ARM64 Debian for runtime
FROM debian:bookworm-slim AS runtime

# Install ARM64 dependencies + QEMU for possible x86 emulation
RUN apt update && \
    apt install -y sudo curl qemu-user-static binfmt-support openjdk-17-jre && \
    rm -rf /var/lib/apt/lists/* 

ENV INSTALL4J_JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64

# Copy from builder
COPY --from=builder /opt/ViewPower /opt/ViewPower

WORKDIR /opt/ViewPower

# ---------------------------
# Test execution
# ---------------------------
RUN ./upsMonitor start && sleep 60 && ./upsMonitor stop

# Prepare default data
RUN mkdir -p /opt/ViewPower/default_data && \
    cp -a /opt/ViewPower/config /opt/ViewPower/default_data/config && \
    cp -a /opt/ViewPower/datas /opt/ViewPower/default_data/datas && \
    cp -a /opt/ViewPower/datalog /opt/ViewPower/default_data/datalog && \
    cp -a /opt/ViewPower/log /opt/ViewPower/default_data/log

# Add shutdown script
COPY ./shutdown.sh /usr/local/bin/shutdown.sh
RUN chmod +x /usr/local/bin/shutdown.sh

# Volume for event trigger
VOLUME ["/ups-events"]

# Add entrypoint
COPY ./entrypoint /opt/ViewPower/entrypoint
RUN chmod +x /opt/ViewPower/entrypoint
ENTRYPOINT ["./entrypoint"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sSf http://localhost:15178 || exit 1