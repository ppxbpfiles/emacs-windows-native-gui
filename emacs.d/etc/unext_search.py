# -*- coding: utf-8 -*-
"""
U-NEXT 検索ヘルパースクリプト
Emacs から呼び出され、U-NEXTの公式内部GraphQLエンドポイントを検索して
作品リスト（ID、タイトル、見放題判定、キャッチコピー）をJSON形式で返します。
"""
import sys
import json

# Windows の標準出力を UTF-8 に固定
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def search_unext(query):
    try:
        from curl_cffi import requests
    except ImportError:
        print(json.dumps([{"error": "curl_cffi がインストールされていません"}], ensure_ascii=False))
        return

    headers = {
        "Origin": "https://video.unext.jp",
        "Referer": "https://video.unext.jp/",
        "apollographql-client-name": "cosmo",
        "apollographql-client-version": "v128.0-prod-08a1458",
        "content-type": "application/json"
    }

    params = {
        "operationName": "cosmo_allFreewordSearch",
        "variables": json.dumps({
            "query": query,
            "page": 1,
            "pageSize": 20,
            "videoSortOrder": "RECOMMEND",
            "bookSortOrder": "RECOMMEND",
            "includePositionPlayLive": True
        }),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": "e972baff0299d3cf64a3eaec1f9387500dadeabfe994041f98003bf42d614bb9"
            }
        })
    }

    try:
        r = requests.get(
            "https://cc.unext.jp/",
            params=params,
            headers=headers,
            impersonate="chrome",
            timeout=10
        )
        if r.status_code != 200:
            print(json.dumps([], ensure_ascii=False))
            return

        data = r.json()
        titles = data.get("data", {}).get("webfront_videoFreewordSearch", {}).get("titles", [])
        results = []
        for v in titles:
            sid = v.get("id")
            title = v.get("titleName")
            if not sid or not title:
                continue

            badges = [b.get("id") for b in v.get("paymentBadgeList", []) if isinstance(b, dict)]
            is_svod = "SVOD" in badges

            catchphrase = v.get("catchphrase") or ""
            catchphrase = " ".join(catchphrase.split())

            results.append({
                "id": sid,
                "title": title,
                "svod": is_svod,
                "catchphrase": catchphrase
            })

        print(json.dumps(results, ensure_ascii=False))
    except Exception as e:
        print(json.dumps([], ensure_ascii=False))

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else ""
    if q.strip():
        search_unext(q.strip())
    else:
        print(json.dumps([], ensure_ascii=False))
