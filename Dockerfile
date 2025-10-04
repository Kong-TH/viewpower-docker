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

# Run installer automatically (x86_64)
RUN echo -e "o\n/opt/ViewPower\nn\nn\n" | ./ViewPower_linux_x64_text.sh

# Pre-installed ViewPower is now in /opt/ViewPower inside builder
# ===========================
# Runtime stage (ARM64)
# ===========================
# Use ARM64 Debian for runtime
FROM --platform=linux/arm64 debian:bookworm-slim AS runtime

# Install ARM64 dependencies + QEMU for possible x86 emulation
RUN apt update && \
    apt install -y sudo curl qemu-user-static binfmt-support && \
    rm -rf /var/lib/apt/lists/*

# Copy pre-installed ViewPower from x86_64 builder
COPY --from=builder /opt/ViewPower /opt/ViewPower

# Set working directory
WORKDIR /opt/ViewPower

# Copy entrypoint script
COPY ./entrypoint /opt/ViewPower/entrypoint
RUN chmod +x /opt/ViewPower/entrypoint

# Optional: copy shutdown script
COPY ./shutdown.sh /usr/local/bin/shutdown.sh
RUN chmod +x /usr/local/bin/shutdown.sh

# Set volume for trigger files
VOLUME ["/ups-events"]

# Set container entrypoint
ENTRYPOINT ["./entrypoint"]

# Healthcheck (example)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -sSf http://localhost:15178 || exit 1
