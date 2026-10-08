#include "tag_meta.h"
#include <stdlib.h>
#include <string.h>
#include <strings.h>

// Cap the decoded picture block: covers are well under a few MB and the value
// comes from an untrusted file on a small-RAM handheld.
#define TAG_PICTURE_MAX_BYTES (8 * 1024 * 1024)

static const struct {
	const char* key;
	TagField field;
} vorbis_keys[] = {
	{"TITLE", TAG_FIELD_TITLE},
	{"ARTIST", TAG_FIELD_ARTIST},
	{"ALBUM", TAG_FIELD_ALBUM},
	{"ALBUMARTIST", TAG_FIELD_ALBUM_ARTIST},
	{"ALBUM ARTIST", TAG_FIELD_ALBUM_ARTIST},
	{"METADATA_BLOCK_PICTURE", TAG_FIELD_PICTURE},
};

static int is_space(char c) {
	return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

TagField TagMeta_vorbisField(const char* comment, size_t len, const char** value, size_t* value_len) {
	if (!comment || !value || !value_len)
		return TAG_FIELD_NONE;
	const char* eq = memchr(comment, '=', len);
	if (!eq)
		return TAG_FIELD_NONE;
	size_t key_len = (size_t)(eq - comment);

	TagField field = TAG_FIELD_NONE;
	for (size_t i = 0; i < sizeof(vorbis_keys) / sizeof(vorbis_keys[0]); i++) {
		if (strlen(vorbis_keys[i].key) == key_len && strncasecmp(comment, vorbis_keys[i].key, key_len) == 0) {
			field = vorbis_keys[i].field;
			break;
		}
	}
	if (field == TAG_FIELD_NONE)
		return TAG_FIELD_NONE;

	const char* start = eq + 1;
	const char* end = comment + len;
	while (start < end && is_space(*start))
		start++;
	while (end > start && (is_space(end[-1]) || end[-1] == '\0'))
		end--;
	if (start == end)
		return TAG_FIELD_NONE;

	*value = start;
	*value_len = (size_t)(end - start);
	return field;
}

static int base64_value(char c) {
	if (c >= 'A' && c <= 'Z')
		return c - 'A';
	if (c >= 'a' && c <= 'z')
		return c - 'a' + 26;
	if (c >= '0' && c <= '9')
		return c - '0' + 52;
	if (c == '+')
		return 62;
	if (c == '/')
		return 63;
	return -1;
}

// Decode base64, skipping whitespace and stopping at '=' padding.
// Returns the decoded byte count, or 0 on an invalid character.
static size_t base64_decode(const char* in, size_t len, uint8_t* out, size_t out_cap) {
	uint32_t acc = 0;
	int bits = 0;
	size_t n = 0;
	for (size_t i = 0; i < len && in[i] != '='; i++) {
		if (is_space(in[i]))
			continue;
		int v = base64_value(in[i]);
		if (v < 0)
			return 0;
		acc = (acc << 6) | (uint32_t)v;
		bits += 6;
		if (bits >= 8) {
			bits -= 8;
			if (n >= out_cap)
				return 0;
			out[n++] = (uint8_t)(acc >> bits);
		}
	}
	return n;
}

static uint32_t read_be32(const uint8_t* p) {
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

uint8_t* TagMeta_decodeBlockPicture(const char* base64, size_t len, const uint8_t** image,
									size_t* image_size, uint32_t* type) {
	if (!base64 || !image || !image_size || !type)
		return NULL;

	size_t cap = len / 4 * 3 + 3;
	if (cap > TAG_PICTURE_MAX_BYTES)
		return NULL;
	uint8_t* block = malloc(cap);
	if (!block)
		return NULL;
	size_t size = base64_decode(base64, len, block, cap);

	// type(4) mime_len(4) mime desc_len(4) desc width/height/depth/colors(16) data_len(4) data
	if (size < 8)
		goto fail;
	uint32_t pic_type = read_be32(block);
	uint32_t mime_len = read_be32(block + 4);
	size_t pos = 8;
	if (mime_len > size - pos || size - pos - mime_len < 4)
		goto fail;
	pos += mime_len;
	uint32_t desc_len = read_be32(block + pos);
	pos += 4;
	if (desc_len > size - pos || size - pos - desc_len < 20)
		goto fail;
	pos += desc_len + 16;
	uint32_t data_len = read_be32(block + pos);
	pos += 4;
	if (data_len == 0 || data_len > size - pos)
		goto fail;

	*type = pic_type;
	*image = block + pos;
	*image_size = data_len;
	return block;

fail:
	free(block);
	return NULL;
}
