# Engine EaaS source protocol

## Discovery

Engine's EaaS client sends a request/response discovery datagram on UDP 11224:

```text
45 41 41 53 01 00
```

The source replies:

```text
45 41 41 53 01 01
generated 16-byte token
UTF-16BE hostname string
UTF-8 URL string
UTF-16BE software version string
protocol byte
UTF-16BE extra string
```

The URL has the form:

```text
grpc://HOST:50010
```

Docker hosts must advertise an address reachable from the player. Publishing
UDP 11224 and TCP 50010/50020 is more reliable than host networking on systems
that filter inbound UDP.

## Source running on the player

Engine on 4.3.4 already listens on TCP 50010 at its primary LAN address and at
127.0.0.1. A locally hosted source must not bind `0.0.0.0:50010`.

The working layout is:

1. assign a second IPv4 address to the LAN interface (for example,
   `192.168.4.90/32`);
2. bind the source's gRPC and HTTP listeners only to that address;
3. bind the discovery socket to `0.0.0.0:11224` with `SO_REUSEPORT`;
4. advertise the alias in the discovery URL and set the reply packet's source
   address to the same alias with `IP_PKTINFO`.

The standard ports matter. A discovery reply advertising gRPC 50110 appeared in
the source picker, but activation failed with a generic "No connection" dialog.
Advertising 50010 on the alias made Engine perform `CreateTrust`, `GetLibrary`,
`GetTracks`, and `GetTrack` immediately. HTTP 50020 is then inferred from the
standard gRPC port.

Restrict the gRPC and HTTP endpoints to local interface addresses. The
unauthenticated trust service should not be reachable from other LAN hosts.

## Boot activation on the writable overlay

New unit files written under `/etc/systemd/system` survive a reboot, but this
firmware does not include newly added `multi-user.target.wants` entries or
service drop-ins in the boot transaction until a later `daemon-reload`.
`systemctl is-enabled` can report `enabled` while the service remains inactive
after boot.

Use the existing deterministic `/data/payload/activate.sh` hook. It should
start a `/data` helper in the background, and that helper should wait for:

* systemd to accept `systemctl start`;
* a default route;
* a primary address on the configured LAN interface;
* one successful outbound connectivity check.

Apply the secondary source address only after those checks. Adding it while
Wi-Fi is still completing DHCP can disrupt the boot-time network path. Do not
create an ordering dependency that blocks `engine.service`; Engine discovers
the source on later scans.

## gRPC services

```text
networktrust.v1.NetworkTrustService/CreateTrust
enginelibrary.v1.EngineLibraryService/EventStream
enginelibrary.v1.EngineLibraryService/GetCredentials
enginelibrary.v1.EngineLibraryService/GetLibraries
enginelibrary.v1.EngineLibraryService/GetLibrary
enginelibrary.v1.EngineLibraryService/GetTracks
enginelibrary.v1.EngineLibraryService/GetSearchFilters
enginelibrary.v1.EngineLibraryService/GetTrack
enginelibrary.v1.EngineLibraryService/GetHistoryPlayedTracks
enginelibrary.v1.EngineLibraryService/GetHistorySessions
enginelibrary.v1.EngineLibraryService/PutEvents
enginelibrary.v1.EngineLibraryService/SearchTracks
```

The transport is plaintext gRPC. `CreateTrust` can immediately return a
`CreateTrustResponse.granted` message.

Engine 4.3.4 treats `GetTracks` and `SearchTracks` as server-streaming RPCs.
The client accepts one populated response. Strings must be valid UTF-8 before
protobuf marshaling.

## Library model

`GetLibraries` returns one or more `Library { id, title, logo }` records.
`GetLibrary` returns a tree of `PlaylistMetadata`:

```text
PlaylistMetadata {
  id
  title
  track_count
  repeated PlaylistMetadata playlists
  ListType list_type
}
```

The player renders top-level entries from `GetLibrary` directly. An extra
single "library root" node makes selection less useful, so top-level
categories should be returned directly.

`GetTracks` selects a playlist ID and returns `ListTrack` records:

```text
ListTrack {
  TrackMetadata metadata
  bytes preview_artwork
}
```

Artwork has no URL field. It must be embedded as image bytes.

## Playback

`GetTrack` returns a stable blob URL:

```text
TrackBlob {
  TrackBlobUrl url {
    string url
    uint32 file_size
  }
}
```

Engine accepts a Windows-style logical path and sends it back to the source's
HTTP `/download` endpoint. The HTTP handler must support:

```text
HEAD
GET
Range
206 Partial Content
Content-Length
Content-Range
Accept-Ranges
```

## Testing

A source is externally testable without the player:

1. send `EAAS 01 00` to UDP 11224 and decode the reply;
2. call `GetLibraries`, `GetLibrary`, and `GetTracks` over gRPC;
3. request the first 1024 bytes of a track over HTTP and verify `206`.

On-device validation then confirms the source tile, playlist tree, artwork,
and track list.
