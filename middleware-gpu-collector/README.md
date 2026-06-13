# Middleware GPU OpenTelemetry Collector

A minimal OpenTelemetry Collector distribution focused on NVIDIA GPU telemetry (DCGM and NVML), exporting to the Middleware platform over OTLP.

# Components

## Receivers

| Component Name | Documentation |
| -------------- | ------------- |
| dcgm | [docs](No docs linked for component) |
| nvml | [docs](No docs linked for component) |
| otlp | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/receiver/otlpreceiver/README.md) |


## Processors

| Component Name | Documentation |
| -------------- | ------------- |
| batch | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor/README.md) |
| cumulativetodelta | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/cumulativetodeltaprocessor/README.md) |
| deltatorate | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/deltatorateprocessor/README.md) |
| memorylimiter | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiterprocessor/README.md) |
| metricstransform | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/metricstransformprocessor/README.md) |
| resourcedetection | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourcedetectionprocessor/README.md) |
| transform | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor/README.md) |


## Exporters

| Component Name | Documentation |
| -------------- | ------------- |
| debug | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/debugexporter/README.md) |
| otlp | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/otlpexporter/README.md) |
| otlphttp | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/otlphttpexporter/README.md) |


## Extensions

| Component Name | Documentation |
| -------------- | ------------- |
| healthcheck | [docs](https://www.github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/healthcheckextension/README.md) |


## Connectors

| Component Name | Documentation |
| -------------- | ------------- |


## Providers

| Component Name | Documentation |
| -------------- | ------------- |
| env | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/confmap/provider/envprovider) |
| file | [docs](https://www.github.com/open-telemetry/opentelemetry-collector/tree/main/confmap/provider/fileprovider) |

