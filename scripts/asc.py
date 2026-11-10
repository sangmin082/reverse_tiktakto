#!/usr/bin/env python3
"""App Store Connect API로 배포 준비를 자동화한다.

- 번들 ID가 없으면 등록한다.
- 앱 레코드가 있는지 확인한다(애플이 API로 앱 생성을 막아 두어 이것만은 웹에서 한 번 만들어야 한다).
- TestFlight에 올라간 가장 큰 빌드 번호 + 1을 다음 빌드 번호로 정한다.

환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def token():
    with open(os.environ["ASC_KEY_PATH"]) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, path, params=None, body=None):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as res:
            return json.load(res)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        sys.exit(f"::error::App Store Connect API {method} {path} 실패 ({e.code}): {detail}")


def ensure_bundle_id(identifier, name):
    found = call("GET", "/v1/bundleIds", {"filter[identifier]": identifier, "limit": 200})["data"]
    if any(b["attributes"]["identifier"] == identifier for b in found):
        print(f"번들 ID 있음: {identifier}")
        return
    ascii_name = "".join(ch for ch in name if ch.isascii() and (ch.isalnum() or ch == " ")).strip()
    call("POST", "/v1/bundleIds", body={"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier,
        "name": ascii_name or identifier.split(".")[-1],
        "platform": "IOS",
    }}})
    print(f"번들 ID 등록함: {identifier}")


def find_app(identifier):
    apps = call("GET", "/v1/apps", {"filter[bundleId]": identifier})["data"]
    return next((a for a in apps if a["attributes"]["bundleId"] == identifier), None)


def next_build_number(app_id, minimum):
    builds = call("GET", "/v1/builds", {"filter[app]": app_id, "sort": "-version", "limit": 1})["data"]
    latest = max((int(b["attributes"]["version"]) for b in builds if b["attributes"]["version"].isdigit()), default=0)
    return max(latest + 1, minimum)


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(text + "\n")
    print(text)


def output(name, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as f:
            f.write(f"{name}={value}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--min-build", type=int, default=1)
    args = parser.parse_args()

    ensure_bundle_id(args.bundle_id, args.name)

    app = find_app(args.bundle_id)
    if app is None:
        summary(
            "## App Store Connect에 앱을 한 번 만들어 주세요\n\n"
            "애플이 API로 앱 생성을 허용하지 않아 이 단계만 웹에서 해야 합니다(약 1분).\n\n"
            "1. https://appstoreconnect.apple.com/apps 에서 **+ → 신규 앱**\n"
            "2. 아래 값을 그대로 입력\n\n"
            f"| 항목 | 값 |\n|---|---|\n| 플랫폼 | iOS |\n| 이름 | {args.name} |\n"
            f"| 기본 언어 | 한국어 |\n| 번들 ID | {args.bundle_id} |\n| SKU | {args.bundle_id} |\n"
            "| 사용자 액세스 | 전체 액세스 |\n\n"
            "3. 이 워크플로를 다시 실행하세요."
        )
        sys.exit(f"::error::App Store Connect에 {args.bundle_id} 앱이 없습니다. 실행 요약(Summary)의 안내를 따라 주세요.")

    build = next_build_number(app["id"], args.min_build)
    print(f"앱 ID {app['id']}, 다음 빌드 번호 {build}")
    output("app_id", app["id"])
    output("build_number", build)


if __name__ == "__main__":
    main()
