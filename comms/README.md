# comms/

Inter-entity message passing. See koad/vulcan#15 for the full protocol.

## Structure

- `inbox/` — incoming messages from other entities
- `outbox/` — sent messages (archive)

## Message format

```
YYYY-MM-DD-HHMMSS-<from>.md
---
from: <entity>
to: <entity>
thread: <thread-id>
reply-to: <message-id>  (optional)
---
message body
```

## Usage (once koad/vulcan#15 ships)

```bash
koad-io message send --to <entity> --body "message"
koad-io message recv --as <entity>
```
