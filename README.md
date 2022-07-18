# recDL

recDL is a simple, AV capture application for Blackmagic DeckLink devices.

- __Requirement__: macOS 12.x, 11.x, 10.15, 10.14.
- __Capture Device__: Blackmagic DeckLink devices.
- __Restriction__: Compressed/Synchronized captures are not supported.
- __Framework__: DLABridging + DLABCaptureManager (Embedded)
- __Dependency__: Blackmagic_Desktop_Video_Macintosh (11.4-11.7, 12.0-12.4).
- __Architecture__: Universal binary (x86_64 + arm64)

#### Basic feature
- One click recording
- One click preview for Video/Audio
- Wide 16:9 or Legacy 4:3 screen video
- Multichannel audio (2/8/16 or none)
- Direct transcoding to H264+AAC.mov
- Direct transcoding to ProRes422+AAC.mov

#### Scripting feature
- Basic AppleScript support
- Automated file name creation based on date/time
- Recording limiter support
- AutoQuit support after recording is finished

#### Advanced feature
- YUV422 pixel format processing
- Non square pixel video support
- Strict pixel aspect ratio (e.g. 40:33 for NTSC-DV source)
- Clean aperture (e.g.720x480 <-> 704x480 for NTSC-DV source)
- ColorPrimaries/TransferFunctions/YCbCrMatrices ready
- LPCM Audio format recording support
- Multichannel audio (2 for Stereo, 8 or 16 for discrete)
- SMPTE timecode ready (* Depends on video source - VANC)

#### Development environment
- macOS 12.4 Monterey
- Xcode 13.4.1
- Swift 5.6.1

#### License
- The MIT License

Copyright © 2016-2022年 MyCometG3. All rights reserved.
