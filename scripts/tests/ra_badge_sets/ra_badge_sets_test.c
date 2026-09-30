// Host test for workspace/all/common/ra_badge_sets.c: the per-game marker
// that lets minarch skip checking every badge file at game launch (#132).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "ra_badge_sets.h"

static int failures = 0;
#define CHECK(cond, msg)                \
	do {                                \
		if (cond)                       \
			printf("ok   - %s\n", msg); \
		else {                          \
			printf("FAIL - %s\n", msg); \
			failures++;                 \
		}                               \
	} while (0)

int main(int argc, char** argv) {
	if (argc < 2) {
		fprintf(stderr, "usage: %s <scratch dir>\n", argv[0]);
		return 2;
	}
	const char* ra = argv[1];

	const char* set[] = {"12345", "67890", "00042"};
	const char* subset[] = {"00042", "", "12345"};
	const char* more[] = {"12345", "99999"};

	CHECK(!RA_BadgeSets_covers(ra, 7, set, 3), "no marker: not covered");

	RA_BadgeSets_write(ra, 7, set, 3);
	CHECK(RA_BadgeSets_covers(ra, 7, set, 3), "written set is covered");
	CHECK(RA_BadgeSets_covers(ra, 7, subset, 3), "subset in any order, empty names ignored");
	CHECK(!RA_BadgeSets_covers(ra, 7, more, 2), "a name not in the marker is not covered");
	CHECK(!RA_BadgeSets_covers(ra, 8, set, 3), "markers are per game");
	CHECK(!RA_BadgeSets_covers(ra, 0, set, 3), "game id 0 never covered");

	// a prefix of a listed name must not match (whole-line compare)
	const char* prefix[] = {"1234"};
	CHECK(!RA_BadgeSets_covers(ra, 7, prefix, 1), "prefix of a listed name is not covered");

	// CRLF-edited marker still parses
	char path[512];
	snprintf(path, sizeof(path), "%s/badge_sets/9.txt", ra);
	FILE* f = fopen(path, "wb");
	fputs("12345\r\n67890\r\n", f);
	fclose(f);
	const char* two[] = {"67890", "12345"};
	CHECK(RA_BadgeSets_covers(ra, 9, two, 2), "CRLF marker parses");

	RA_BadgeSets_invalidate(ra, 7);
	CHECK(!RA_BadgeSets_covers(ra, 7, set, 3), "invalidated marker no longer covers");

	snprintf(path, sizeof(path), "%s/badge_sets/7.txt.tmp", ra);
	f = fopen(path, "rb");
	CHECK(f == NULL, "no temp file left behind");
	if (f)
		fclose(f);

	return failures ? 1 : 0;
}
