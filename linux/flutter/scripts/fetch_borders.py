"""
دابەزاندنی سنووری ٤ وڵاتەکە و پارێزگاکانی هەرێمی کوردستان لە OpenStreetMap (Nominatim)
و دروستکردنی assets/borders.geojson بۆ ناو ئەپەکە.

بەکارهێنان (لە فۆڵدەری پڕۆژەکە):
    python fetch_borders.py
ئەنجام: assets/borders.geojson
"""
import json, os, time, urllib.parse, urllib.request

QUERIES = [
    ("Iraq", "country", None),
    ("Iran", "country", None),
    ("Syria", "country", None),
    ("Türkiye", "country", None),
    ("Erbil Governorate", "krg", "iq"),
    ("Sulaymaniyah Governorate", "krg", "iq"),
    ("Duhok Governorate", "krg", "iq"),
    ("Halabja Governorate", "krg", "iq"),
]


def fetch(q, cc, threshold):
    params = {
        "q": q, "format": "geojson", "polygon_geojson": 1,
        "polygon_threshold": threshold, "limit": 1, "accept-language": "en",
    }
    if cc:
        params["countrycodes"] = cc
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "kurdistan-map-borders/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def main():
    feats = []
    for q, kind, cc in QUERIES:
        print("دەهێنرێت:", q)
        try:
            data = fetch(q, cc, 0.01 if kind == "country" else 0.002)
            f = data["features"][0]
            if f["geometry"]["type"] not in ("Polygon", "MultiPolygon"):
                print("   !! سنوورەکە نەدۆزرایەوە (تەنها خاڵ)")
                continue
            feats.append({
                "type": "Feature",
                "properties": {"name": q, "kind": kind},
                "geometry": f["geometry"],
            })
        except Exception as ex:
            print("   !! هەڵە:", ex)
        time.sleep(2)  # یاسای Nominatim: ١ داواکاری لە چرکەیەکدا

    os.makedirs("assets", exist_ok=True)
    with open("assets/borders.geojson", "w", encoding="utf-8") as fh:
        json.dump({"type": "FeatureCollection", "features": feats}, fh, ensure_ascii=False)
    size = os.path.getsize("assets/borders.geojson") / 1024
    print(f"تەواو: {len(feats)} سنوور، {size:.0f} KB -> assets/borders.geojson")


if __name__ == "__main__":
    main()
