#include "../../nextui/tabbg_model.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

// the files the fake card holds
static const char* present[8];

static bool fake_exists(const char* path) {
	for (int i = 0; present[i]; i++)
		if (strcmp(present[i], path) == 0)
			return true;
	return false;
}

static void set_present(const char* a, const char* b) {
	memset(present, 0, sizeof(present));
	present[0] = a;
	present[1] = b;
}

static void console_bg(void) {
	char out[512];
	set_present("/sd/Roms/Game Boy (GB)/.media/bg.png", NULL);
	assert(TabBg_path(TABBG_CONSOLES, "/sd/Roms/Game Boy (GB)", false, fake_exists, out, sizeof(out)));
	assert(strcmp(out, "/sd/Roms/Game Boy (GB)/.media/bg.png") == 0);
	// a trailing slash on the folder path makes no difference
	assert(TabBg_path(TABBG_CONSOLES, "/sd/Roms/Game Boy (GB)/", false, fake_exists, out, sizeof(out)));
	assert(strcmp(out, "/sd/Roms/Game Boy (GB)/.media/bg.png") == 0);
}

static void console_bg_needs_controller_art_off(void) {
	char out[512];
	set_present("/sd/Roms/Game Boy (GB)/.media/bg.png", NULL);
	assert(!TabBg_path(TABBG_CONSOLES, "/sd/Roms/Game Boy (GB)", true, fake_exists, out, sizeof(out)));
}

static void console_without_bg(void) {
	char out[512];
	set_present("/sd/Roms/Game Boy (GB)/.media/bglist.png", NULL); // the old game-list name is not used here
	assert(!TabBg_path(TABBG_CONSOLES, "/sd/Roms/Game Boy (GB)", false, fake_exists, out, sizeof(out)));
}

static void collection_own_bg(void) {
	char out[512];
	set_present("/sd/Collections/.media/Faves.png", "/sd/Collections/.media/bg.png");
	// collections ignore the controller art setting
	assert(TabBg_path(TABBG_COLLECTIONS, "/sd/Collections/Faves.txt", true, fake_exists, out, sizeof(out)));
	assert(strcmp(out, "/sd/Collections/.media/Faves.png") == 0);
}

static void collection_shared_bg(void) {
	char out[512];
	set_present("/sd/Collections/.media/bg.png", NULL);
	assert(TabBg_path(TABBG_COLLECTIONS, "/sd/Collections/Faves.txt", false, fake_exists, out, sizeof(out)));
	assert(strcmp(out, "/sd/Collections/.media/bg.png") == 0);
}

static void collection_name_keeps_inner_dots(void) {
	char out[512];
	set_present("/sd/Collections/.media/01) Best.of.GBA.png", NULL);
	assert(TabBg_path(TABBG_COLLECTIONS, "/sd/Collections/01) Best.of.GBA.txt", false, fake_exists, out,
					  sizeof(out)));
	assert(strcmp(out, "/sd/Collections/.media/01) Best.of.GBA.png") == 0);
}

static void collection_without_bg(void) {
	char out[512];
	set_present("/sd/Collections/.media/Other.png", NULL);
	assert(!TabBg_path(TABBG_COLLECTIONS, "/sd/Collections/Faves.txt", false, fake_exists, out, sizeof(out)));
}

static void rejects_bad_input(void) {
	char out[512], tiny[8];
	set_present("/sd/Roms/GB/.media/bg.png", NULL);
	assert(!TabBg_path(TABBG_CONSOLES, NULL, false, fake_exists, out, sizeof(out)));
	assert(!TabBg_path(TABBG_CONSOLES, "", false, fake_exists, out, sizeof(out)));
	assert(!TabBg_path(TABBG_COLLECTIONS, "Faves.txt", false, fake_exists, out, sizeof(out)));	// no folder
	assert(!TabBg_path(TABBG_CONSOLES, "/sd/Roms/GB", false, fake_exists, tiny, sizeof(tiny))); // truncated
}

int main(void) {
	console_bg();
	console_bg_needs_controller_art_off();
	console_without_bg();
	collection_own_bg();
	collection_shared_bg();
	collection_name_keeps_inner_dots();
	collection_without_bg();
	rejects_bad_input();
	printf("tabbg_model: all tests passed\n");
	return 0;
}
