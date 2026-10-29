# v23 draft — not released

Target actual v22 b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e. Draft Rust and translation packet only; no runnable Windows builder yet. Do not inject or run this draft on the user's project.

User reached Taiyo pool dialogue, selected baseball, and saw Japanese entry 179; preceding page 178 describes May special practice. Remaining 177–347 cover all club tutorial endings including eight clubs and go-home, both selectors 0/1 (342 entries). Draft translations require final source review and native fit verification.

Club Building omission identified in MGBGG04.BZZ member 3 second TIM at 0xf800, SHA 986dd8a53fd8fb51ccf8dd603262badde1b06bb39b00f060a21b71ffe7a3e053. Earlier v22 only changed the first TIM in this member. All nine HUD club cells are source-bound by upstream diary_header/club_consumer.rs (64x20, not 24 high).

Remaining work: compile/test v23, inspect preview colors and layout, build full disc fixture and sector/readback verification, generate standalone PowerShell wrapper from v22 with exact backup/restore and actual v22 input guard, publish final instructions. Current draft is NOT validated and must not be described as ready. v21 record reconstruction passed locally using Nimbus Sans; v22 fixture reconstruction was started. Use /tmp for Cargo target (workspace target produced linker failures); CARGO_BUILD_JOBS=1, CARGO_PROFILE_DEV_DEBUG=0, CARGO_INCREMENTAL=0, cargo test --lib. Local PowerShell execution was blocked in earlier session; use direct Rust testing plus static wrapper checks.
