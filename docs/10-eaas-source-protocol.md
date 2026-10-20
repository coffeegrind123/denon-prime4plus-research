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
