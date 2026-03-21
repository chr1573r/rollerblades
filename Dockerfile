FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    git \
    openssl \
    openssh-client \
    gzip \
    nginx \
    curl \
    librsvg \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create directories
RUN mkdir -p /app /cfg /repos /output /keys /run/nginx

# Copy rollerblades script and frontend assets
COPY rollerblades.sh /app/rollerblades.sh
COPY assets/ /app/assets/
RUN chmod +x /app/rollerblades.sh

# Copy entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy nginx config
COPY nginx.conf /etc/nginx/http.d/default.conf

# Environment variables with defaults
# Signing keys at /keys/ are auto-generated if not mounted
ENV RB_SLEEP_TIME=5m \
    RB_OUTPUT_DIR=/output \
    RB_CFG_DIR=/cfg \
    RB_REPOS_DIR=/repos \
    RB_CLONE_PREFIX=https://github.com \
    RB_CLONE_SUFFIX=.git \
    RB_SIGNING_PRIVATE_KEY=/keys/private.pem \
    RB_SIGNING_PUBLIC_KEY=/keys/public.pem

# Volumes
VOLUME ["/cfg", "/repos", "/output", "/keys"]

# Expose nginx port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/packages.txt || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
