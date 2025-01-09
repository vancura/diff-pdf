FROM ubuntu:24.04

ENV XDG_RUNTIME_DIR=/tmp/runtime-root \
    DISPLAY=:99 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    DEBIAN_FRONTEND=noninteractive

# Install initial requirements
RUN apt-get update && apt-get install -y file procps curl gpg software-properties-common

# Setup NodeJS repository
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update

# Install base system utilities
RUN apt-get install -y nodejs bash git jq jo xz-utils wget

# Install build tools
RUN apt-get install -y make automake g++

# Install PDF-related packages
RUN apt-get install -y libpoppler-glib-dev poppler-utils

# Install X11 and graphics packages
RUN apt-get install -y libwxgtk3.2-dev xvfb

# Install Mesa and OpenGL packages
RUN apt-get install -y x11-utils mesa-utils mesa-utils-extra libopengl0 x11-xserver-utils libgl1-mesa-dri libglu1-mesa llvm-runtime libllvm15 mesa-opencl-icd # libgl1-mesa-glx

# Setup runtime directory
RUN mkdir -p /tmp/runtime-root && chmod 0700 /tmp/runtime-root

# Install Apify CLI
RUN npm -g install apify-cli

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build the tool
RUN chmod +x bootstrap && ./bootstrap && ./configure && make && make install

COPY .actor/ .actor/

ENTRYPOINT [".actor/actor.sh"]
