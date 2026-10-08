#include "ra_badge_sets.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define RA_BADGE_SETS_PATH_MAX 512

static void marker_path(char* buf, size_t n, const char* ra_dir, uint32_t game_id) {
	snprintf(buf, n, "%s/badge_sets/%u.txt", ra_dir, game_id);
}

bool RA_BadgeSets_covers(const char* ra_dir, uint32_t game_id,
						 const char** names, size_t count) {
	if (!ra_dir || game_id == 0 || !names)
		return false;

	char path[RA_BADGE_SETS_PATH_MAX];
	marker_path(path, sizeof(path), ra_dir, game_id);
	FILE* f = fopen(path, "rb");
	if (!f)
		return false;

	fseek(f, 0, SEEK_END);
	long size = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (size <= 0) {
		fclose(f);
		return false;
	}
	char* data = malloc((size_t)size + 1);
	if (!data) {
		fclose(f);
		return false;
	}
	size_t got = fread(data, 1, (size_t)size, f);
	fclose(f);
	data[got] = '\0';

	// split into lines in place
	size_t line_count = 0;
	for (size_t i = 0; i < got; i++)
		if (data[i] == '\n')
			line_count++;
	char** lines = malloc((line_count + 1) * sizeof(char*));
	if (!lines) {
		free(data);
		return false;
	}
	size_t n = 0;
	char* p = data;
	while (*p) {
		char* nl = strchr(p, '\n');
		if (nl)
			*nl = '\0';
		size_t len = strlen(p);
		if (len && p[len - 1] == '\r')
			p[--len] = '\0';
		if (len)
			lines[n++] = p;
		if (!nl)
			break;
		p = nl + 1;
	}

	bool covered = true;
	for (size_t i = 0; i < count && covered; i++) {
		if (!names[i] || !names[i][0])
			continue;
		bool found = false;
		for (size_t j = 0; j < n && !found; j++)
			found = strcmp(lines[j], names[i]) == 0;
		covered = found;
	}

	free(lines);
	free(data);
	return covered;
}

void RA_BadgeSets_write(const char* ra_dir, uint32_t game_id,
						const char** names, size_t count) {
	if (!ra_dir || game_id == 0 || !names)
		return;

	char dir[RA_BADGE_SETS_PATH_MAX];
	snprintf(dir, sizeof(dir), "%s/badge_sets", ra_dir);
	mkdir(dir, 0755);

	char path[RA_BADGE_SETS_PATH_MAX];
	char tmp[RA_BADGE_SETS_PATH_MAX + 8];
	marker_path(path, sizeof(path), ra_dir, game_id);
	snprintf(tmp, sizeof(tmp), "%s.tmp", path);

	FILE* f = fopen(tmp, "wb");
	if (!f)
		return;
	bool ok = true;
	for (size_t i = 0; i < count && ok; i++) {
		if (names[i] && names[i][0])
			ok = fprintf(f, "%s\n", names[i]) > 0;
	}
	if (fclose(f) != 0)
		ok = false;
	if (!ok || rename(tmp, path) != 0)
		remove(tmp);
}

void RA_BadgeSets_invalidate(const char* ra_dir, uint32_t game_id) {
	if (!ra_dir || game_id == 0)
		return;
	char path[RA_BADGE_SETS_PATH_MAX];
	marker_path(path, sizeof(path), ra_dir, game_id);
	remove(path);
}
