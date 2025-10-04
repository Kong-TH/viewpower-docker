# ===========================
# Build Stage
# ===========================
# Use ARM64 Debian slim as base
FROM --platform=linux/arm64 debian:bookworm-slim as builder

# Install basic tools, wget and tar
RUN apt update && apt install -y wget tar qemu-user-static binfmt-support && rm -rf /var/lib/apt/lists/*

# Create build directory and download ViewPower installer
RUN mkdir /build
WORKDIR /build
RUN wget -c https://www.power-software-download.com/viewpower/ViewPower_linux_x64_text.tar.gz
RUN tar -xvzf ViewPower_linux_x64_text.tar.gz
RUN rm ViewPower_linux_x64_text.tar.gz

# ===========================
# Runtime Stage
# ===========================
# Use ARM64 Debian slim as runtime
FROM --platform=linux/arm64 debian:bookworm-slim as runtime

# Install dependencies and QEMU for x86_64 emulation
RUN apt update && \
    apt install -y sudo curl qemu-user-static binfmt-support && \
    rm -rf /var/lib/apt/lists/*

# Create install directory
RUN mkdir /install
WORKDIR /install

# Copy installer from build stage
COPY --from=builder /build/ViewPower_linux_x64_text.sh /install/ViewPower_linux_x64_text.sh

# Make installer executable
RUN chmod +x ./ViewPower_linux_x64_text.sh

# Run installer automatically using QEMU (simulate x86_64 environment)
RUN echo -e "o\n/opt/ViewPower\nn\nn\n" | ./ViewPower_linux_x64_text.sh

# Remove installer to save space
RUN rm ViewPower_linux_x64_text.sh

# Set working directory to installed ViewPower
WORKDIR /opt/ViewPower

# Make all binaries executable
RUN find . -type f -name "*.sh" -exec chmod +x {} \;

# Setup QEMU wrapper for all x86_64 binaries automatically
# This allows running ViewPower binaries without prepending 'qemu-x86_64' each time
ENV QEMU_LD_PREFIX=/usr/x86_64-linux-gnu
COPY --from=builder /usr/bin/qemu-x86_64-static /usr/bin/

# Start and stop upsMonitor using QEMU to initialize default data
RUN qemu-x86_64 ./upsMonitor start && sleep 60 && qemu-x86_64 ./upsMonitor stop

# Backup default configuration and data
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

# Set volume for trigger files
VOLUME ["/ups-events"]

# ===========================
# Add entrypoint
# ===========================
COPY ./entrypoint /opt/ViewPower/entrypoint
RUN chmod +x /opt/ViewPower/entrypoint
# Use QEMU to run entrypoint automatically in x86_64 mode
ENTRYPOINT ["qemu-x86_64", "./entrypoint"]

# ===========================
# Health Check
# ===========================
# Check if web server responds on default port
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sSf http://localhost:15178 || exit 1
