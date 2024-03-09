# focalboard-ns

---

[![Docker Image CI](https://github.com/Navystack/focalboard-ns/actions/workflows/docker-image.yml/badge.svg)](https://github.com/Navystack/focalboard-ns/actions/workflows/docker-image.yml)<br>
[![Docker Pulls](https://badgen.net/docker/pulls/navystack/focalboard?icon=docker&label=pulls)](https://hub.docker.com/r/navystack/focalboard/)<br>
[![Docker Size](https://badgen.net/docker/size/navystack/focalboard/latest/amd64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/)

---

## Askfront.com
초보자도 자유롭게 질문할 수 있는 포럼을 만들었습니다. <br />
NavyStack의 가이드 뿐만 아니라, 아니라 모든 종류의 질문을 하실 수 있습니다.

검색해도 도움이 되지 않는 정보만 나오는 것 같고, 주화입마에 빠진 것 같은 기분이 들 때가 있습니다.<br />
그럴 때, 부담 없이 질문해 주세요. 같이 의논하며 생각해봅시다.

[AskFront.com (에스크프론트) 포럼](https://askfront.com/?github)

## 폰트 변경
* 폰트 사이즈 변경
* 폰트 변경 (pretendard)

> [!IMPORTANT]
> navystack/focalboard:latest 태그를 사용하시는 경우 <br>
> 앞단에 리버스 프록시 배치하실 분은 반드시 웹소켓 관련 설정을 해줘야 합니다. <br><br>

> [!TIP]
> 따라서 navystack/focalboard:nginx를 사용하시길 추천드립니다. <br>
> 모든 이미지의 빌드 인수 및 파일은 [본 github 레포](https://github.com/NavyStack/focalboard-ns/) 또는 [github public 레포](https://github.com/NavyStack/)에 전부 공개되어있습니다.

> [!TIP]
> 제 레포의 [Traefik](https://github.com/NavyStack/traefik)을 선행하셨다면
> docker-compose-traefik.yml에서 "수정" 이라고 표시된 도메인 수정하시고,
> 나머지도 개인의 환경에 맞게 수정하시고,
> `docker compose -f docker-compose-traefik.yml up -d` 하시면 번거로운 것 없이 바로 올라갑니다.

<br>

| 구분(태그) | 아키텍쳐 |                                                                       용량                                                                        |
| :--------: | :------: | :-----------------------------------------------------------------------------------------------------------------------------------------------: |
|   latest   |  amd64   |  [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/latest/amd64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/)   |
|            |  arm64   |  [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/latest/arm64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/)   |
|   nginx    |  amd64   |   [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/nginx/arm64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/)   |
|            |  arm64   |   [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/nginx/arm64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/)   |
| openresty  |  amd64   | [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/openresty/arm64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/) |
|            |  arm64   | [![Docker Size](https://badgen.net/docker/size/navystack/focalboard/openresty/arm64?icon=docker)](https://hub.docker.com/r/navystack/focalboard/) |

- 멀티 아키텍처 지원 (amd64, arm64(aarch64))
- 멀티 스테이지 빌드로 가볍습니다.
- nginx도 모듈을 따로 빌드해서 이미지로 넘겼습니다.
- Gzip, Brotli 압축 설정되어있고, PageSpeed 모듈은 Standby 입니다.
- 압축은 1024이하는 압축하지 않습니다. <br> (또한 의미 없는 이미지 재압축 안합니다~)
- Nginx 웹소켓 설정 되어있고, 레포에 있는 default.conf는 참고용입니다. <br> Pagespeed 모듈이 필요하다고 생각하시면 수정후에 바인드 하시면 됩니다.
- 기본 설정이 SQLite 입니다. 따라서 한글을 입력하시려면 DB가 필요합니다.
- Nginx는 Mainline, Openresty는 Upstream, Focalboard는 Pull 반영되면 공식 Git 따라갑니다.

## 사용가능한 태그

- `docker pull navystack/focalboard:nginx` (Nginx 포함, 추천, Inner Port 80)

- `docker pull navystack/focalboard:latest` (Go, Inner Port 9000)

- `docker pull navystack/focalboard:openresty` (Openresty, Inner Port 80)

## Step - 1 Git clone으로 다운로드 받기

`git clone https://github.com/NavyStack/focalboard-ns.git`

## Step - 2 docker-compose.yml 수정하기 (mysql)

수정하는 규칙

```docker-compose.yml
  focalboard-db:
    image: mysql:latest
    container_name: focalboard-db # 이 친구가 데이터베이스 서버 주소가 됩니다.
    environment:
      MYSQL_USER: focalboard # 데이터베이스 사용자
      MYSQL_PASSWORD: powerpassword # 데이터 베이스 사용자 비밀번호
      MYSQL_DATABASE: focalboard # 데이터베이스 이름
      MYSQL_ROOT_PASSWORD: powerpassword # 루트 비밀번호
    volumes:
      - focalboard-db:/var/lib/mysql
    restart: unless-stopped
```

## Step - 3 docker-compose.yml 수정한 대로 config.json 수정하기

수정하는 규칙

```config.json
{
  "serverRoot": "http://localhost:8000",
  "port": 8000,
  "dbtype": "mysql",
  "dbconfig": "데이터베이스유저:데이터베이스유저비밀번호@tcp:데이터베이스서버주소:3306)/데이터베이스이름",
  "useSSL": false,
  "webpath": "./pack",
  "filespath": "./data/files",
  "telemetry": true,
  "prometheusaddress": ":9092",
  "session_expire_time": 2592000,
  "session_refresh_time": 18000,
  "localOnly": false,
  "enableLocalMode": true,
  "localModeSocketLocation": "/var/tmp/focalboard_local.socket",
  "enablePublicSharedBoards": true
}
```

## Final 도커 올리기

`docker compose up -d`

## 기타

- DB를 PgSQL로 사용하려면 [공식 Focalboard Github 참고](https://github.com/mattermost/focalboard) <br> (공식 Github 예제는 PgSQL만 있고, Mysql(MariaDB)는 없어서 예제로 작성함)

- 한글 번역은 현재 이미지에만 적용되어있으며, 변경 내용은 [여기에서](https://github.com/NavyStack/focalboard.git) 확인 가능

- Dockerfile은 [여기에서](https://github.com/NavyStack/focalboard-ns.git) 확인가능

- [Dockerhub 바로가기](https://hub.docker.com/r/navystack/focalboard/)

- [QnA 게시판](https://navystack.com/nsboard/)

## TO-DO

- Docker ENV dynamic
- Traefik 설정 예제

## 라이선스

My contributions are licensed under the MIT License <br>
SPDX-License-Identifier: MIT OR GNU AGPLv3

모든 Docker 이미지와 마찬가지로, 여기에는 다른 라이선스(예: 기본 배포판의 Bash 등 포함된 기본 소프의웨어의 직간접적인 종속성)가 적용되는 다른 소프트웨어도 포함될 수 있습니다.
사전 빌드된 이미지 사용과 관련하여, 이 이미지를 사용할 때 이미지에 포함된 모든 소프트웨어에 대한 관련 라이선스를 준수하는지 확인하는 것은 이미지 사용자의 책임입니다.

기타 모든 상표는 각 소유주의 재산이며, 달리 명시된 경우를 제외하고 본문에서 언급한 모든 상표 소유자 또는 기타 업체와의 제휴관계, 홍보 또는 연관관계를 주장하지 않습니다.
