# Supplied live poster

Source: user-supplied `wings_over_malta_live_poster (1).mp4` (17 October 2026).
SHA-256: `2fdeed1a6f783a0342619a13dd4564dec443bc5374c55a1d6a885674b941cf84`.
834 × 1112, 24 fps, approximately 5.09 seconds. Artwork and soundtrack are supplied by the user; no independent provenance/licence verification is asserted.

`malta_poster.ogv` is the complete supplied clip transcoded to Godot's built-in Theora/Vorbis format. `malta_poster.png` is its unmodified first frame, displayed beneath the decoder as a startup fallback. The original MP4 is not required at runtime. No remote video/texture dependency is introduced.

Reproduce with FFmpeg (replace INPUT with the supplied source path):

```sh
ffmpeg -i INPUT -c:v libtheora -q:v 7 -pix_fmt yuv420p -c:a libvorbis -q:a 4 malta_poster.ogv
ffmpeg -i INPUT -frames:v 1 malta_poster.png
```

The Play control is a real Godot button layered inside the displayed poster, rather than baked into the video. See [startup presentation](../../docs/startup-poster.md).
