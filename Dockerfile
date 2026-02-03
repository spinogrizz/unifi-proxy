FROM nginx:alpine

# Install curl for healthcheck, gawk and jq for stats script
RUN apk add --no-cache curl gawk jq

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/

# Create directories for SSL and guide site
RUN mkdir -p /etc/nginx/ssl /var/www/guide

# Copy guide static site into image
COPY guide/ /var/www/guide/

# Copy stats script and setup cron
COPY scripts/stats.sh /usr/local/bin/stats.sh
RUN chmod +x /usr/local/bin/stats.sh && \
    echo "0 * * * * /usr/local/bin/stats.sh" >> /etc/crontabs/root && \
    echo '{"unique_ips":0,"total_mb":0,"updated":""}' > /var/www/guide/stats.json

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

# Start crond in background, then nginx in foreground
CMD crond && nginx -g "daemon off;"
