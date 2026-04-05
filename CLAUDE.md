# Weather Analytics

A local weather analytics stack provisioned with Terraform using Docker containers.

## Stack

- **Elasticsearch 8.5.0** — stores weather data in the `weather-data` index
- **Grafana (latest)** — visualizes weather data via pre-provisioned dashboards
- **Docker** — all services run as containers on the `analytics-net` network
- **Terraform** — provisions and manages all infrastructure via the `kreuzwerker/docker` provider

## Project Structure

```
weather-analytics/
├── dashboards/
│   └── weather_dashboard.json       # Grafana dashboard definition
├── infra/
│   ├── main.tf                      # All Terraform resources
│   ├── provisioning/
│   │   ├── dashboards/
│   │   │   └── dashboard.yml        # Grafana dashboard provisioning config
│   │   └── datasources/
│   │       ├── datasource.yml       # Grafana Elasticsearch datasource config
│   │       └── elasticsearch.yml    # Alternative datasource config
│   └── terraform.tfstate            # Terraform state (local backend)
```

## Services

| Service       | Port | URL                        |
|---------------|------|----------------------------|
| Elasticsearch | 9200 | http://localhost:9200       |
| Grafana       | 3001 | http://localhost:3001       |

## Elasticsearch Index

Index: `weather-data`

Fields:
- `timestamp` — date
- `temperature` — float
- `humidity` — float
- `rain` — float
- `wind_speed` — float

## Common Commands

```bash
# Initialize Terraform (first time)
cd infra && terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply

# Tear down
terraform destroy

# Check Elasticsearch health
curl http://localhost:9200

# Query weather data
curl http://localhost:9200/weather-data/_search

# Insert a document manually
curl -X POST "http://localhost:9200/weather-data/_doc" \
  -H "Content-Type: application/json" \
  -d '{"timestamp": "2026-04-04T12:00:00", "temperature": 75, "humidity": 60, "rain": 0.2, "wind_speed": 10}'
```

## Known Issues

- The Grafana container uses a bind mount for `dashboard.yml` — the absolute path must exist on the host at `infra/provisioning/dashboards/dashboard.yml` before `terraform apply`.
- Grafana datasources are mounted via a Docker volume; the Elasticsearch datasource config (`elasticsearch.yml`) must be copied into the volume separately or provisioned via an additional `null_resource`.
- `xpack.security.enabled=false` is set on Elasticsearch — this is intentional for local development only.