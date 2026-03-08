# --- STAGE 1: BUILD ---
FROM dunkelgrau/godot:4.6 AS builder

# Setup build directory
WORKDIR /src
COPY . .
RUN mkdir -p build/linux

# EXPORT: This assumes your export preset is named "Linux"
# If you named it "Server" or "Linux/X11", change it here!
RUN godot --headless --export-release "Linux" build/linux/server.x86_64

# --- STAGE 2: RUN ---
FROM ubuntu:noble

# Minimal libraries for Godot headless
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libfontconfig1 \
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libxrender1 \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the build from the builder
COPY --from=builder /src/build/linux/ /app/
RUN chmod +x /app/server.x86_64

# Expose the default Hub and Dungeon ports (UDP)
EXPOSE 9797/udp
EXPOSE 9798/udp

# Let Kubernetes/CMD provide the flags (--headless -- --hub, etc.)
ENTRYPOINT ["./server.x86_64"]