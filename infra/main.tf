terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 2.20.0"
    }
  }
}

# -----------------------------
# Docker network
# -----------------------------
resource "docker_network" "analytics_net" {
  name = "analytics-net"
}

# -----------------------------
# Elasticsearch container
# -----------------------------
resource "docker_container" "elasticsearch" {
  name  = "elasticsearch"
  image = "docker.elastic.co/elasticsearch/elasticsearch:8.5.0"

  networks_advanced {
    name = docker_network.analytics_net.name
  }

  ports {
    internal = 9200
    external = 9200
  }

  mounts {
    target = "/usr/share/elasticsearch/data"
    source = docker_volume.elasticsearch_data.name
    type   = "volume"
  }

  env = [
    "discovery.type=single-node",
    "xpack.security.enabled=false"
  ]

  depends_on = [docker_volume.elasticsearch_data]
}

# -----------------------------
# Elasticsearch volume
# -----------------------------
resource "docker_volume" "elasticsearch_data" {
  name = "elasticsearch-data"
}

# -----------------------------
# Grafana volumes
# -----------------------------
resource "docker_volume" "grafana_data" {
  name = "grafana-data"
}

resource "docker_volume" "grafana_dashboards" {
  name = "grafana-dashboards"
}

resource "docker_volume" "grafana_datasources" {
  name = "grafana-datasources"
}

# -----------------------------
# Copy dashboard JSON into Grafana volume
# -----------------------------
resource "null_resource" "copy_dashboard" {
  depends_on = [docker_volume.grafana_dashboards]

  provisioner "local-exec" {
    command = <<EOT
      DASHBOARD_JSON="${abspath("${path.module}/dashboards/weather_dashboard.json")}"
      if [ ! -f "$DASHBOARD_JSON" ]; then
        echo "ERROR: $DASHBOARD_JSON not found!"
        exit 1
      fi

      echo "Copying weather_dashboard.json into Grafana dashboards volume..."
      docker run --rm \
        -v ${docker_volume.grafana_dashboards.name}:/dashboards \
        -v "$DASHBOARD_JSON":/tmp/weather_dashboard.json:ro \
        alpine sh -c "cp /tmp/weather_dashboard.json /dashboards/weather_dashboard.json"
    EOT
  }
}

# -----------------------------
# Copy datasource YAML into Grafana datasources volume
# -----------------------------
resource "null_resource" "copy_datasource" {
  depends_on = [docker_volume.grafana_datasources]

  provisioner "local-exec" {
    command = <<EOT
      DATASOURCE_YML="${abspath("${path.module}/provisioning/datasources/elasticsearch.yml")}"
      if [ ! -f "$DATASOURCE_YML" ]; then
        echo "ERROR: $DATASOURCE_YML not found!"
        exit 1
      fi

      echo "Copying elasticsearch.yml into Grafana datasources volume..."
      docker run --rm \
        -v ${docker_volume.grafana_datasources.name}:/datasources \
        -v "$DATASOURCE_YML":/tmp/elasticsearch.yml:ro \
        alpine sh -c "cp /tmp/elasticsearch.yml /datasources/elasticsearch.yml"
    EOT
  }
}

# -----------------------------
# Grafana container
# -----------------------------
resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana:latest"

  networks_advanced {
    name = docker_network.analytics_net.name
  }

  ports {
    internal = 3000
    external = 3001
  }

  # Persistent Grafana data
  mounts {
    target = "/var/lib/grafana"
    source = docker_volume.grafana_data.name
    type   = "volume"
  }

  # Mount dashboards folder (volume)
  mounts {
    target = "/etc/grafana/provisioning/dashboards"
    source = docker_volume.grafana_dashboards.name
    type   = "volume"
  }

  # Mount dashboard provisioning YAML (bind mount)
  mounts {
    target = "/etc/grafana/provisioning/dashboards/dashboard.yml"
    source = "${abspath("${path.module}/provisioning/dashboards/dashboard.yml")}"
    type   = "bind"
  }

  # Mount data sources provisioning folder
  mounts {
    target = "/etc/grafana/provisioning/datasources"
    source = docker_volume.grafana_datasources.name
    type   = "volume"
  }

  env = [
    "GF_DASHBOARDS_JSON_ENABLED=true",
    "GF_DASHBOARDS_JSON_PATH=/etc/grafana/provisioning/dashboards"
  ]

  depends_on = [null_resource.copy_dashboard, null_resource.copy_datasource]
}

# -----------------------------
# Elasticsearch index
# -----------------------------
resource "null_resource" "es_index" {
  depends_on = [docker_container.elasticsearch]

  provisioner "local-exec" {
    command = <<EOT
      # Wait until Elasticsearch is ready
      for i in {1..30}; do
        curl -s http://localhost:9200 > /dev/null && break
        echo "Waiting for Elasticsearch..."
        sleep 2
      done

      curl -X PUT "http://localhost:9200/weather-data" \
      -H "Content-Type: application/json" \
      -d '{
        "mappings": {
          "properties": {
            "timestamp": { "type": "date" },
            "temperature": { "type": "float" },
            "humidity": { "type": "float" },
            "rain": { "type": "float" },
            "wind_speed": { "type": "float" }
          }
        }
      }'
    EOT
  }
}

# -----------------------------
# Insert sample document
# -----------------------------
resource "null_resource" "es_sample_doc" {
  depends_on = [null_resource.es_index]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST "http://localhost:9200/weather-data/_doc" \
      -H "Content-Type: application/json" \
      -d '{
        "timestamp": "2026-04-04T12:00:00",
        "temperature": 75,
        "humidity": 60,
        "rain": 0.2,
        "wind_speed": 10
      }'
    EOT
  }
}