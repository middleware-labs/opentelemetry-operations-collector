if command -v systemctl >/dev/null 2>&1; then
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload
    fi
    systemctl enable otelcol-middleware-gpu.service
    if [ -f /etc/otelcol-middleware-gpu/config.yaml ]; then
        if [ -d /run/systemd/system ]; then
            systemctl restart otelcol-middleware-gpu.service
        fi
    fi
fi
