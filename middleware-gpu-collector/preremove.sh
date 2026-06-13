if [ "$1" != "1" ]; then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop otelcol-middleware-gpu.service
        systemctl disable otelcol-middleware-gpu.service
    fi
fi
