# Live poster and cinematic march

Original animation: user-supplied `wings_over_malta_live_poster (1).mp4` (17 October 2026), SHA-256 `2fdeed1a6f783a0342619a13dd4564dec443bc5374c55a1d6a885674b941cf84`. Source dimensions 834×1112, 24 fps, approximately 5.09 seconds. The original decoded forward-only Theora conversion had 121 frames / 5.041667 seconds.

Current `malta_poster.ogv` is a **240-frame, 10-second forward-and-return cycle** derived from those frames: indices 0…120, then 119…1. Both turning endpoints appear once; the next cycle continues from 1 to 0 rather than snapping from the very different final aircraft pose to the first. Motion reverses in the return half; this is an edited loop of the supplied footage, not newly generated endless forward flight. Original source artwork, dimensions, portrait framing and 24 fps are preserved; Theora re-encoding is lossy. There is no embedded audio. The first-frame PNG remains a decoder-startup fallback, not a frame displayed at each loop.

Rebuild from the original forward-only clip (do not feed the already edited output back into the tool):

```sh
git show 340ab9c:assets/intro/malta_poster.ogv > /tmp/malta-poster-forward.ogv
python tools/build_poster_loop.py /tmp/malta-poster-forward.ogv assets/intro/malta_poster.ogv
```

The FFmpeg helper preserves the source frame rate explicitly; it validates that the output has one video stream and exactly `2*N-2` frames. The original supplied MP4 can also be its input. Current measured seam comparison at 96×128 greyscale: final-to-first mean absolute luminance difference 0.396/255, versus 20.483/255 in the former forward-only loop. This measures the frame discontinuity, not subjective smoothness or exact pixel preservation.

## Active poster soundtrack

`wings_over_malta_cinematic_march.ogg` is the **unaltered uploaded** `Wings_over_Malta_Cinematic_March.ogg`, supplied 6 November 2026:

- SHA-256 `fcbb2063f18f2678b40f281e3d663ccec8a086afacaeb8fba9f54999f5c58150`.
- Ogg Vorbis, 48.000 seconds, 44.1 kHz, stereo, 738,003 bytes.
- GameIntro preloads it and loops a private AudioStreamPlayer stream through the existing Music bus. Its 48-second playback is independent of the 10-second video cycle.
- The former `malta_poster_audio.ogg` is retained as the historical original-video soundtrack but is **not used by the poster**. Main-menu music remains separate and unchanged.

Artwork and both recordings were supplied by the user; independent provenance/licence verification is not asserted. No remote media dependency exists. The Play button remains a real button integrated inside the poster. See [startup presentation](../../docs/startup-poster.md).
