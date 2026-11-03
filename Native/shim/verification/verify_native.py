import json
import platform
import statistics
import sys
from pathlib import Path


def decode_wxf(data):
    position = 2
    assert data[:2] == b"8:"

    def take(count):
        nonlocal position
        value = data[position:position + count]
        assert len(value) == count
        position += count
        return value

    def varint():
        value = shift = 0
        while True:
            byte = take(1)[0]
            value |= (byte & 127) << shift
            if byte < 128:
                return value
            shift += 7

    def expression():
        token = take(1)
        if token in (b"s", b"S", b"I"):
            text = take(varint()).decode("utf-8")
            if token == b"I":
                return int(text)
            if token == b"s":
                return {"True": True, "False": False, "Null": None, "List": "List"}[text]
            return text
        if token in (b"C", b"j", b"i", b"L"):
            return int.from_bytes(take({b"C": 1, b"j": 2, b"i": 4, b"L": 8}[token]), "little", signed=True)
        if token == b"A":
            result = {}
            for _ in range(varint()):
                assert take(1) == b"-"
                key = expression()
                result[key] = expression()
            return result
        if token == b"f":
            count = varint()
            assert expression() == "List"
            return [expression() for _ in range(count)]
        raise AssertionError(f"Unexpected WXF token {token!r}")

    result = expression()
    assert position == len(data)
    return result


path = Path(sys.argv[1])
records = []
checks = []
expected = {
    "first": 2**100, "repeated": 2**100, "prepare": None,
    "source-one": 42, "source-two": 7, "recovery": 42, "namespace": 42,
    "unicode": 'α世🙂\n"\\', "list": list(range(20000)),
    "choose-first": 126410606437752, "choose-repeated": 126410606437752,
    "sqrt": 11111, "after-cancel": 42, "after-release": 42,
}
for line in path.read_text(encoding="utf-8").splitlines():
    parts = line.split("\t")
    if parts[0] == "RESULT":
        _, name, elapsed, encoded = parts
        value = decode_wxf(bytes.fromhex(encoded))
        if name == "source-not-leaked":
            assert value["ok"] is False and "localValue" in value["error"], value
        elif name == "cancelled":
            assert isinstance(value["ok"], bool), value
            if value["ok"]:
                assert value["value"] == 42, value
        else:
            assert value == {"ok": True, "value": expected[name]}, (name, value)
        records.append({"Name": name, "Seconds": float(elapsed), "Correct": True})
    elif parts[0] == "CHECK":
        checks.append(parts[1])
    elif parts[0] == "IMPORT":
        startup = float(parts[1])
names = {record["Name"] for record in records}
required = set(expected) - {"choose-first", "choose-repeated", "sqrt"}
assert names >= required | {"source-not-leaked", "cancelled"}, names
assert len([r for r in records if r["Name"] == "repeated"]) == 7
assert set(checks) == {"wait-deadline", "abort-wait", "released-environment"}
result = {
    "System": platform.platform(), "Architecture": platform.machine(),
    "Coverage": "Native LibraryLink shim through standalone C callbacks; no Wolfram kernel",
    "ImportSeconds": startup, "EvaluationsPassed": len(records), "ChecksPassed": len(checks),
    "FirstSeconds": next(r["Seconds"] for r in records if r["Name"] == "first"),
    "SubsequentMedianSeconds": statistics.median(r["Seconds"] for r in records if r["Name"] == "repeated"),
    "Records": records,
}
path.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({k: v for k, v in result.items() if k != "Records"}, indent=2))
