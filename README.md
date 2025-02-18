# ViewPower Docker

## Overview
**ViewPowerHTML 1.04-21344** is an advanced UPS management software. It allows remote monitoring and management of multiple UPS devices over a **LAN or INTERNET** connection. It prevents data loss during power outages, enables safe system shutdown, and provides scheduling and analysis features.

## Features
- Monitor and control **multiple UPS devices** over LAN/Internet
- Supports **auto/manual online updates**
- Real-time **UPS status graphs** (voltage, frequency, load, battery level)
- **Safe OS shutdown** to prevent data loss during power failure
- **Alerts & notifications** via alarms, broadcast, email, and mobile messenger
- **Scheduled UPS actions** (power on/off, battery tests, outlet control)
- **Secure remote access** with password protection
- Multi-language support: English, Chinese, French, German, Spanish, Russian, Portuguese, Ukrainian, Italian, Polish, Czech, Turkish

## Ports
- `15178` – Web service port
- `8005` – Web service shutdown port

## Installation
### Using Docker CLI
```bash
docker run -d --name viewpower \
  --privileged \
  -p 15178:15178 \
  -p 8005:8005 \
  -v /path/to/config:/opt/ViewPower/config \
  -v /path/to/datas:/opt/ViewPower/datas \
  -v /path/to/datalog:/opt/ViewPower/datalog \
  -v /path/to/log:/opt/ViewPower/log \
  -v /dev/bus/usb:/dev/bus/usb \
  ggong5/viewpower:latest
```

### Using Docker Compose
Create a `docker-compose.yml` file:
```yaml
services:
  viewpower:
    image: ggong5/viewpower:latest
    ports:
      - "15178:15178"
      - "8005:8005"
    volumes:
      - /path/to/config:/opt/ViewPower/config
      - /path/to/datas:/opt/ViewPower/datas
      - /path/to/datalog:/opt/ViewPower/datalog
      - /path/to/log:/opt/ViewPower/log
      - /dev/bus/usb:/dev/bus/usb
    healthcheck:
      test: ["CMD", "pgrep", "upsMonitor"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    privileged: true
    restart: unless-stopped
```

Then start the container:
```bash
docker-compose up -d
```

## Source Code
[📂 ViewPower Docker GitLab Repository](https://git.kohtnas.com/publicgroup/viewpower-docker)
```bash
   git clone http://kongnet.3bbddns.com:52733/publicgroup/viewpower-docker.git
```


Let me know if you need any modifications! 🚀

