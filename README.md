# Cross-Platform Multi-Sensor Telemetry & Diagnostic Console

A Production-Grade, Multi-Pillar military radar


- FRONTEND: Flutter (Linux/Cross-Platform) with custom painters for oscilloscope rendering. -
- CONCURRENCY: Non-Blocking network socket ingestion handled via background Dart Isolates. -
- BACKEND CORE: High-Performance C shared library (`libcorrelator.so`) compiled with `-03` optimization for Hamming distance calculations and ECG metric filtering. -
- DATA SOURCE: Python UDP Server broadcasting structured 32-bit integer payloads. -

---

# PROJECT STRUCTURE #
