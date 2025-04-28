# --- Stage 1: Build Stage ---
# Use a specific, stable version of the Python Alpine image
FROM python:3.11-alpine AS builder

# Set environment variables to prevent Python from writing pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install build-time OS dependencies needed for compiling Python packages (e.g., cryptography)
# These won't be in the final image.
RUN apk add --no-cache build-base libffi-dev

# Set a working directory
WORKDIR /app

# Create a virtual environment in /opt/venv
RUN python -m venv /opt/venv

# Activate the virtual environment for subsequent RUN commands in this stage
ENV PATH="/opt/venv/bin:$PATH"

# Copy the requirements file into the build stage
# Ensure you have a requirements.txt file next to your Dockerfile
COPY requirements.txt .

# Install Python dependencies using the requirements file
# Use BuildKit cache mount to speed up subsequent builds if requirements haven't changed.
# --no-cache-dir is still useful to ensure the cache isn't stored *within* the layer itself.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# --- Stage 2: Final Runtime Stage ---
# Use the same minimal base image
FROM python:3.11-alpine

# Set environment variables like in the build stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install only essential runtime OS dependencies (e.g., libffi is needed by cryptography)
RUN apk add --no-cache libffi

# Create a non-root user and group specifically for the application
RUN addgroup -S vdirsyncer && adduser -S vdirsyncer -G vdirsyncer

# Copy the virtual environment containing vdirsyncer and its dependencies from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Create standard directories for vdirsyncer config and status data within the user's home directory
# Ensure these directories are owned by the non-root user so it can write to them.
# These directories are intended to be mount points for volumes at runtime.
RUN mkdir -p /home/vdirsyncer/.config/vdirsyncer /home/vdirsyncer/.local/share/vdirsyncer/status && \
    chown -R vdirsyncer:vdirsyncer /home/vdirsyncer/.config /home/vdirsyncer/.local

# Switch execution context to the non-root user for security
USER vdirsyncer

# Set the working directory to the user's home directory
WORKDIR /home/vdirsyncer

# Add the virtual environment's bin directory to the PATH for the vdirsyncer user
ENV PATH="/opt/venv/bin:$PATH"

# Set the entrypoint to the vdirsyncer command
# Allows running the container like `docker run <image> sync`
ENTRYPOINT ["vdirsyncer"]

# Set a default command (e.g., display help message) if no command is provided to `docker run`
CMD ["--help"]
