# New update for ViewPower Version 1.04-25210-b1

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

# Install build dependencies for FEX-Emu
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    cmake \
    build-essential \
    clang-16 \
    lld-16 \
    ninja-build \
    python3 \
    python3-pip \
    pkg-config \
    wget \
    libgl1-mesa-dev \
    libfuse2 \
    && update-ca-certificates \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-16 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-16 100 \
    && update-alternatives --set clang /usr/bin/clang-16 \
    && update-alternatives --set clang++ /usr/bin/clang++-16

# Build FEX-Emu from source
ENV CC=/usr/bin/clang-16
ENV CXX=/usr/bin/clang++-16

RUN git clone --recursive https://github.com/FEX-Emu/FEX.git /tmp/fex \
    && cd /tmp/fex \
    && git fetch --all \
    && git checkout FEX-2509_1 \
    && git submodule update --init --recursive \
    && sed -i '/add_subdirectory(Source\/Tools)/d' CMakeLists.txt \
    && sed -i '/add_subdirectory(Tools)/d' CMakeLists.txt \
    && find Source/Tools -type f -name 'CMakeLists.txt' -exec sed -i 's/find_package(Qt5.*)//g' {} \; \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DFEX_CORE=ON \
        -DFEX_BUILD_TESTS=OFF \
        -DFEX_BUILD_TOOLS=OFF \
        -DFEX_OPTION_USE_QT=OFF \
        -DFEX_OPTION_ENABLE_GUI=OFF . \
    && cmake --build build \
    && cmake --install build --prefix /usr/local \
    && rm -rf /tmp/fex \
    && apt-get purge -y git cmake build-essential clang-16 lld-16 ninja-build pkg-config \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install runtime dependencies (no Qt needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    libgl1-mesa-dev \
    libfuse2 \
    && rm -rf /var/lib/apt/lists/*

# Install ViewPower
RUN mkdir /install
WORKDIR /install
COPY --from=builder /build/ViewPower_linux_x64_text.sh /install/ViewPower_linux_x64_text.sh

RUN echo "o\n/opt/ViewPower\nn\nn\n" | ./ViewPower_linux_x64_text.sh
RUN rm ViewPower_linux_x64_text.sh

WORKDIR /opt/ViewPower
RUN FEXBash ./upsMonitor start && sleep 60 && FEXBash ./upsMonitor stop

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