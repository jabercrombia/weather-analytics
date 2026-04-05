# Weather Analytics

A local weather analytics stack using Elasticsearch and Grafana, provisioned with Terraform via Docker.

## Stack

| Service         | Version  | Purpose                        |
|-----------------|----------|--------------------------------|
| Elasticsearch   | 8.5.0    | Stores and indexes weather data |
| Grafana         | latest   | Visualizes weather dashboards   |
| Terraform       | -        | Provisions all infrastructure   |
| Docker          | -        | Runs all services as containers |

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) running locally
- [Terraform](https://developer.hashicorp.com/terraform/install) installed

## Getting Started

**1. Clone the repo**
```bash
git clone https://github.com/YOUR_USERNAME/weather-analytics.git
cd weather-analytics
```

**2. Initialize Terraform**
```bash
cd infra
terraform init
```

**3. Provision the stack**
```bash
terraform apply
```

**4. Open Grafana**

Navigate to http://localhost:3001 and log in with `admin` / `admin`.

## Services

| Service       | URL                        |
|---------------|----------------------------|
| Grafana       | http://localhost:3001       |
| Elasticsearch | http://localhost:9200       |

## Elasticsearch Index

Index: `weather-data`

| Field        | Type  |
|--------------|-------|
| timestamp    | date  |
| temperature  | float |
| humidity     | float |
| rain         | float |
| wind_speed   | float |

## Useful Commands

```bash
# Check Elasticsearch health
curl http://localhost:9200

# Query all weather documents
curl http://localhost:9200/weather-data/_search?pretty

# Count documents
curl http://localhost:9200/weather-data/_count

# Insert a document
curl -X POST "http://localhost:9200/weather-data/_doc" \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-04T12:00:00",
    "temperature": 75,
    "humidity": 60,
    "rain": 0.2,
    "wind_speed": 10
  }'

# Tear down all infrastructure
terraform destroy
```

## Project Structure

```
weather-analytics/
├── dashboards/
│   └── weather_dashboard.json       # Grafana dashboard definition
├── infra/
│   ├── main.tf                      # Terraform resources
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboard.yml        # Grafana dashboard provisioning config
│       └── datasources/
│           └── elasticsearch.yml    # Grafana Elasticsearch datasource config
├── .gitignore
├── CLAUDE.md
└── README.md
```