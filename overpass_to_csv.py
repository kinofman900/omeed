#!/usr/bin/env python3
"""
Overpass JSON -> places.csv  (بۆ هاوردەکردن بۆ خشتەی places لە Supabase)

هەنگاوەکان:
1) بچۆ بۆ https://overpass-turbo.eu و ئەم کۆدە لێ بدە و Run بکە:

[out:json][timeout:600];
(
  area["ISO3166-1"="IQ"][admin_level=2];
  area["ISO3166-1"="IR"][admin_level=2];
  area["ISO3166-1"="SY"][admin_level=2];
  area["ISO3166-1"="TR"][admin_level=2];
)->.a;
node["place"~"^(city|town)$"](area.a);
out body;

2) Export > "raw OSM data" > دابەزاندنی فایلی JSON (بۆ نموونە export.json)
3) ئەم سکریپتە ڕابکێشە:
       python overpass_to_csv.py export.json places.csv
4) لە Supabase > Table Editor > places > Insert > Import data from CSV
   (places.csv هەڵبژێرە. ستوونی id لە CSV نییە و خۆکار دروست دەبێت)

داتاکە لە OpenStreetMap ـەوەیە (ODbL)، بۆیە ناوی سەرچاوە لەسەر نەخشەکە دەمێنێتەوە.
"""
import csv
import json
import sys

KIND = {"city": "city", "town": "town", "village": "village", "hamlet": "village"}
FIELDS = ["osm_id", "kind", "lat", "lng", "name", "name_ckb", "name_ku",
          "name_ar", "name_en", "population"]


def to_int(v):
    try:
        return int(str(v).replace(",", "").split()[0])
    except Exception:
        return ""


def main(src, dst):
    with open(src, encoding="utf-8") as f:
        data = json.load(f)

    seen = set()
    rows = []
    for el in data.get("elements", []):
        if el.get("type") != "node":
            continue
        tags = el.get("tags", {})
        lat, lon = el.get("lat"), el.get("lon")
        if lat is None or lon is None:
            continue
        osm_id = el.get("id")
        if osm_id in seen:
            continue
        seen.add(osm_id)

        name = tags.get("name") or tags.get("name:ckb") or tags.get("name:en") or ""
        if not name:
            continue

        rows.append({
            "osm_id": osm_id,
            "kind": KIND.get(tags.get("place"), "other"),
            "lat": lat,
            "lng": lon,
            "name": tags.get("name", ""),
            "name_ckb": tags.get("name:ckb", ""),
            "name_ku": tags.get("name:ku", ""),
            "name_ar": tags.get("name:ar", ""),
            "name_en": tags.get("name:en", ""),
            "population": to_int(tags.get("population", "")),
        })

    with open(dst, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)

    with_ckb = sum(1 for r in rows if r["name_ckb"])
    print(f"{len(rows)} شوێن نووسرا بۆ {dst}")
    print(f"ئەوانەی ناوی سۆرانییان هەیە: {with_ckb}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("بەکارهێنان: python overpass_to_csv.py export.json places.csv")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])