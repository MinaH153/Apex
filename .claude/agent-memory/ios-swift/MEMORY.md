# iOS Agent Memory

## Project Structure
- Xcode project: `/Users/joshuahenein/Apex/ios/Apex.xcodeproj/`
- App sources: `/Users/joshuahenein/Apex/ios/Apex/`
- Groups: Supabase/, Views/, Models/
- Package dependency: supabase-swift (branch: main)
- Deployment target: iOS 17.0

## Build
- Available simulator: `iPhone 17 Pro` (no iPhone 16 available)
- Build command: `cd /Users/joshuahenein/Apex/ios && xcodebuild -scheme Apex -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

## pbxproj ID Convention
- Uses A1000XXX hex IDs
- Last used: A100002C (Models group)
- Next available: A100002D

## Supabase Swift SDK
- Class renamed to `SupabaseManager` to avoid conflict with `Supabase.SupabaseClient`
- Auth state changes: `for await (event, session) in client.auth.authStateChanges`
- Events: `.signedIn`, `.signedOut`
- Realtime: `client.realtimeV2.channel(...)`, `.postgresChange(InsertAction.self, ...)`

## Supabase Config
- Local dev URL: http://127.0.0.1:54321
- Anon key: demo key (supabase-demo)
