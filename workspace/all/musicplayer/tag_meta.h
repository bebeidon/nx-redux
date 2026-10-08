#ifndef __TAG_META_H__
#define __TAG_META_H__

#include <stddef.h>
#include <stdint.h>

// Picture type of a front cover in ID3 APIC / FLAC PICTURE blocks
#define TAG_PICTURE_FRONT_COVER 3

// Vorbis comment fields the player uses (FLAC, Ogg Vorbis, Opus)
typedef enum {
	TAG_FIELD_NONE = 0,
	TAG_FIELD_TITLE,
	TAG_FIELD_ARTIST,
	TAG_FIELD_ALBUM,
	TAG_FIELD_ALBUM_ARTIST,
	TAG_FIELD_PICTURE, // METADATA_BLOCK_PICTURE (base64 FLAC PICTURE block)
} TagField;

// Classify one "KEY=value" Vorbis comment of len bytes (need not be
// NUL-terminated). Keys match case-insensitively. On a known field, *value and
// *value_len give the value with surrounding whitespace trimmed; an empty value
// is reported as TAG_FIELD_NONE so it never replaces a filename-derived title.
TagField TagMeta_vorbisField(const char* comment, size_t len, const char** value, size_t* value_len);

// Decode a METADATA_BLOCK_PICTURE value of len bytes (a base64-encoded FLAC
// PICTURE block, used by Ogg Vorbis and Opus for cover art).
// Returns a malloc'd buffer owning the decoded block (caller frees) with
// *image/*image_size pointing at the image bytes inside it and *type set to
// the picture type, or NULL if the value is malformed.
uint8_t* TagMeta_decodeBlockPicture(const char* base64, size_t len, const uint8_t** image,
									size_t* image_size, uint32_t* type);

#endif
