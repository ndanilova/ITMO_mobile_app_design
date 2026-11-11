import json
import os
from pathlib import Path
from urllib.request import Request, urlopen


base_url = os.environ.get("SALDO_API_URL", "http://127.0.0.1:18080")


def post(path, body=b""):
    request = Request(
        f"{base_url}{path}",
        data=body,
        headers={"Content-Type": "text/csv"},
    )
    with urlopen(request, timeout=5) as response:
        return json.load(response)


sample = Path(__file__).resolve().parent.parent / "server" / "sample.csv"
report = sample.read_bytes()
with urlopen(f"{base_url}/sample.csv", timeout=5) as response:
    assert response.read() == report

preview = post("/imports", report)
assert preview["trades"] == [
    {"id": "trade-1", "amount": "1250.50"},
    {"id": "trade-2", "amount": "-100.25"},
], preview
assert post(f"/imports/{preview['id']}/confirm") == {"confirmed": True}
assert post("/imports", report) == {**preview, "confirmed": True}
with urlopen(f"{base_url}/portfolio/trades", timeout=5) as response:
    portfolio = json.load(response)
assert all(trade in portfolio["trades"] for trade in preview["trades"]), portfolio

operation = {"title": "Продукты", "note": "Проверка API", "amount": "−125,50 ₽"}
request = Request(
    f"{base_url}/operations",
    data=json.dumps(operation).encode(),
    headers={"Content-Type": "application/json"},
)
with urlopen(request, timeout=5) as response:
    assert response.status == 201
    saved = json.load(response)
assert saved == {**operation, "id": saved["id"]}
with urlopen(f"{base_url}/operations", timeout=5) as response:
    assert saved in json.load(response)["operations"]
