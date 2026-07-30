# Serviio 2.5 — Synology DSM 7 Package

Builds a [Serviio 2.5](http://serviio.org) SPK package for Synology DSM 7.x.x

## Compatibility

- **Tested on**: DS718+ running DSM 7.3.1
- Should in theory run on versions 7.x.x

## Build

```bash
chmod +x build.sh
./build.sh
```

On first run this downloads Serviio 2.5 and Eclipse Temurin 11 JRE into `.cache/` and builds `Serviio-2.5-xxxx.spk`. Subsequent runs use the cached downloads.

Alternatively a pre-built package can be downloaded from Releases.

## Install

1. In Synology, open **Package Center → Manual Install**
2. Upload Serviio SPK package
3. Click **Next**
4. Click **Agree**
5. Check **Run after installation** and click **Done**

Serviio is available at `http://<NAS-IP>:23423/console/#/app/welcome`.

## Granting Serviio access to your media

Serviio runs as its own DSM system user `Serviio`

For each shared folder you want to serve, in **File Station**:

1. Right-click the folder → **Properties** → **Permission** → **Create**
2. Under **User or group**, select `Serviio`
3. Grant **Read** permissions
4. Click done

### Choosing folders in Serviio

To see your shared folders, go to **/** → **volume1**

Click on your folder and then click **OK**

## What this package changes from the original Serviio 2.5 Linux release

| File | Change |
|---|---|
| `config/serviio.properties` | `ffmpeg_executable` set to `/usr/bin/ffmpeg` (DSM ships FFmpeg at that path) |
| `config/log4j2.xml` | Log path redirected to the writable data directory (`/volume1/@appdata/Serviio/log/`) |

Everything else is the unmodified Serviio 2.5 Linux release bundled with a JRE.