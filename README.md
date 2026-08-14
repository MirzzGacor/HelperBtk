# PRODUCT REQUIREMENTS DOCUMENT (PRD)

**Project Name:** Project Sandbox-Rust  
**Target Platform:** Windows Desktop (.exe)  
**Document Version:** 1.1.0  
**Core Language:** Rust (Client & Server)  

## 1. Executive Summary & Vision
Project Sandbox-Rust is a high-performance 2D tile-based multiplayer sandbox desktop game. Developed entirely in Rust, it delivers a zero-Garbage-Collection runtime capable of sustaining high-concurrency multiplayer connections at a stable 30 TPS tick rate.

## 2. Tech Stack
- **Client:** Rust, Bevy Engine (ECS), wgpu
- **Server:** Rust, Tokio Async Runtime, Renet (UDP) / Tungstenite (WS)
- **Database Layer:** PostgreSQL (SQLx), Redis (In-Memory Cache)
- **Deployment:** UpCloud VPS

## 3. Functional Specifications
- **World System:** 100x60 tile grid, 3-layer depth (Background, Foreground, Overlay).
- **Physics:** Authoritative server-side AABB collision with a maximum 3.0-tile reach radius.
- **Farming Engine:** Passive growth calculations via Unix Timestamps.
- **Territory System:** Small, Big, and World Lock access-control matrices.

## 4. Anti-Cheat Architecture
- Native compiled `.exe` execution to mitigate memory injection.
- Server-authoritative movement validation and raycast verification.
- Network packet burst throttling.

## 5. Roadmap
- **M1:** Bevy Engine baseline & AABB physics.
- **M2:** Tokio networking & movement sync.
- **M3-M4:** DB integration, World mutation, Seed splicing.
- **M5:** Economy, World Locks, UI, `.exe` packaging.
- **M6:** Bot stress testing (1,000+ connections) & Beta release.
