#ifndef __EMBEDDED_LYRICS_H__
#define __EMBEDDED_LYRICS_H__

#include <stdbool.h>

// Read lyrics embedded in an audio file:
//   MP3        ID3v2.3/2.4 SYLT (millisecond timestamps) or USLT
//   FLAC       Vorbis comment LYRICS / UNSYNCEDLYRICS / SYNCEDLYRICS
//   Ogg, Opus  the same Vorbis comments
//   M4A        the iTunes ©lyr atom
// Returns malloc'd UTF-8 text (caller frees) or NULL when the file has none.
// Synced lyrics come back as LRC ("[mm:ss.cc]line") with *synced set; plain
// lyrics come back as-is with *synced cleared. A timed variant is preferred
// over a plain one when a file carries both.
char* EmbeddedLyrics_read(const char* filepath, bool* synced);

// True when text holds at least one LRC "[mm:ss" timestamped line.
bool EmbeddedLyrics_isLrc(const char* text);

#endif
