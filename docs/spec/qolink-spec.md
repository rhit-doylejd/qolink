# THE QOLINK PROTOCOL

Specification **Version 0.1 (draft)**, 2026-10-25 — QOLink team

---

QOLink sends all traffic as frames. A frame carries either data in one of three
priority classes, or credits.

A frame is an 18-byte envelope around a payload of 1 to 1024 bytes, capped per class:

```
┌─ QOLINK FRAME ───────────────────────────────────────────────────────────┐
│ Byte 0   │ 1   │ 2..3   │ 4   │ 5..12     │ 13..12+n │ 13+n..16+n │ 17+n │
│──────────┼─────┼────────┼─────┼───────────┼──────────┼────────────┼──────│
│ preamble │ SFD │ header │ seq │ timestamp │ payload  │    FCS     │ EFD  │
└──────────────────────────────────────────────────────────────────────────┘
```

All bits are Manchester encoded using the IEEE 802.3 convention: a low-to-high
transition is a **1**.

Between frames the line carries continuous Manchester idle. Every frame starts
with the preamble **0x55**, followed by the SFD. The SFD and EFD are Manchester
code-violation patterns, and the EFD pattern is distinct from the SFD pattern.

The header identifies the frame's class and payload length:

```
┌─ HEADER ─────────────────────────────┐
│          Byte[2]  ..  Byte[3]        │
│──────────────────────────────────────│
│  class  │      length      │  rsvd   │
│   2b    │       11b        │   3b    │
└──────────────────────────────────────┘
```

2-bit class: **b00** Low, **b01** Medium, **b10** High, **b11** Credit  
11-bit payload length  
3-bit reserved

The 8-bit sequence number is counted separately for each class, modulo 256.

A Credit frame's 3-byte payload holds the cumulative credits granted for each data
class.

The frame check sequence is a CRC-32, as defined in IEEE 802.3, computed over the
header, sequence, timestamp and payload.

The sender captures its counter as the SFD is sent and writes that value into the
frame's timestamp field.

A receiver:

1. Ends a frame at the EFD, not by the length field. A frame whose length does
   not match the length field is an error.
2. Stages each frame, and commits it to the FIFO for its class, or to the credit
   counter, only after the FCS and field checks pass.
3. Captures its own counter at the SFD.
