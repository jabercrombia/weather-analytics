#!/usr/bin/env python3
"""Seed weather-data index with sample data spanning the last 7 days."""

import json
import random
import subprocess
import sys
from datetime import datetime, timedelta

ES_URL = "http://localhost:9200"
INDEX = "weather-data"


def wait_for_es():
    import time
    for i in range(30):
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", f"{ES_URL}"],
            capture_output=True, text=True
        )
        if result.stdout.strip() == "200":
            print("Elasticsearch is ready.")
            return
        print(f"Waiting for Elasticsearch... ({i + 1}/30)")
        time.sleep(2)
    print("ERROR: Elasticsearch did not become ready in time.")
    sys.exit(1)


def seed():
    docs = []
    now = datetime.utcnow().replace(minute=0, second=0, microsecond=0)

    # 7 days of data every 3 hours
    random.seed(42)
    for h in range(7 * 24, 0, -3):
        ts = now - timedelta(hours=h)
        docs.append({
            "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S"),
            "temperature": round(60 + random.uniform(-10, 25), 1),
            "humidity":    round(50 + random.uniform(-20, 30), 1),
            "rain":        round(random.uniform(0, 0.5), 2),
            "wind_speed":  round(random.uniform(2, 20), 1)
        })

    # Last 12 hours hourly
    for h in range(12, 0, -1):
        ts = now - timedelta(hours=h)
        docs.append({
            "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S"),
            "temperature": round(65 + random.uniform(-5, 15), 1),
            "humidity":    round(55 + random.uniform(-15, 25), 1),
            "rain":        round(random.uniform(0, 0.3), 2),
            "wind_speed":  round(random.uniform(3, 15), 1)
        })

    bulk_body = ""
    for doc in docs:
        bulk_body += json.dumps({"index": {"_index": INDEX}}) + "\n"
        bulk_body += json.dumps(doc) + "\n"

    result = subprocess.run(
        ["curl", "-s", "-X", "POST", f"{ES_URL}/_bulk",
         "-H", "Content-Type: application/x-ndjson",
         "--data-binary", bulk_body],
        capture_output=True, text=True
    )
    resp = json.loads(result.stdout)
    if resp.get("errors"):
        print("ERROR: Some documents failed to index.")
        sys.exit(1)

    print(f"Seeded {len(resp.get('items', []))} documents into {INDEX}.")


if __name__ == "__main__":
    wait_for_es()
    seed()
