# Chronos

**Time-travel file browser for macOS.**

Chronos silently watches your folders and records every file change. Then lets you browse back in time — see what any folder looked like at any past moment. File went missing? Renamed? Deleted? Just drag the timeline and find it.

## What it does

- **Watches** — Uses macOS FSEvents to track create / modify / rename / remove in real-time
- **Remembers** — Stores every event in a local SQLite database (WAL mode, crash-safe)
- **Time-travels** — Drag the timeline to see folder state at any past moment
- **Finds** — Shows deleted files in red, newly created in green, modified in blue

## Architecture

```
FSEvents (macOS)
    |
    v
FileSystemMonitor  --DispatchQueue("chronos.fsevents")-->
    |
    v
HistoryDatabase (actor, SQLite WAL)
    |-- events table: path, name, parent_path, event_type, timestamp, size, inode
    |-- idx_parent, idx_timestamp for fast snapshot queries
    |
    v
HistoryBrowser (@MainActor) <-- SwiftUI -- TimelineView
```

## Build

```bash
swift build -c release
```

Or use the build script:
```bash
bash .github/build_app.sh
```

## Run

```bash
swift run
```

## Stack

- Swift 5.9 + SwiftUI
- SQLite3 (built-in on macOS)
- FSEvents (CoreServices)
- No external dependencies

## License

MIT
