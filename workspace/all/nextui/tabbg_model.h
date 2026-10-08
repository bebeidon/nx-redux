#ifndef TABBG_MODEL_H
#define TABBG_MODEL_H

#include <stdbool.h>
#include <stddef.h>

// The user's own background for the selected row of a main-menu List tab, from the card's .media folders.
typedef enum {
	TABBG_CONSOLES,	   // entry_path: the console folder, e.g. /mnt/SDCARD/Roms/Game Boy (GB)
	TABBG_COLLECTIONS, // entry_path: the collection file, e.g. /mnt/SDCARD/Collections/Faves.txt
} TabBgKind;

typedef bool (*TabBgExistsFn)(const char* path);

// Writes the background to show into out and returns true, or returns false for none (the global bg.png then):
//   Consoles:    <console>/.media/bg.png, only while controller_art is off (the controller or logo owns the
//                right side otherwise)
//   Collections: <Collections>/.media/<file name without .txt>.png, else <Collections>/.media/bg.png
bool TabBg_path(TabBgKind kind, const char* entry_path, bool controller_art, TabBgExistsFn exists_fn, char* out,
				size_t size);

#endif
