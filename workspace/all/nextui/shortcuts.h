#ifndef SHORTCUTS_H
#define SHORTCUTS_H

#include "types.h"
#include <stdbool.h>

#define MAX_SHORTCUTS 12
// Pinned tools at most, so Home shows every one: 9 while a game is pinned (three columns of 3 squares), 8 with none (two
// columns of 4)
#define MAX_PINNED_TOOLS 9
#define MAX_PINNED_TOOLS_NO_GAMES 8

// Initialize shortcuts (call in Menu_init)
void Shortcuts_init(void);

// Cleanup shortcuts (call in Menu_quit)
void Shortcuts_quit(void);

// Check if a shortcut exists for the given path (without SDCARD_PATH prefix)
int Shortcuts_exists(const char* path);

// Whether the entry can be pinned now: fewer than MAX_SHORTCUTS pins and, for a tool, fewer tools than the tool cap
bool Shortcuts_canAdd(Entry* entry);

// Add a shortcut for the given entry (refused when Shortcuts_canAdd says no)
void Shortcuts_add(Entry* entry);

// Remove a shortcut for the given entry
void Shortcuts_remove(Entry* entry);

// A pinned item moved (a renamed collection): re-point the pin at new_path (SD-relative, like Shortcuts_exists) in
// place, so the pins keep their order; new_name (or NULL to keep it) is the stored display name. False if not pinned.
bool Shortcuts_replacePath(const char* old_path, const char* new_path, const char* new_name);

// Check if inside Tools folder
int Shortcuts_isInToolsFolder(const char* path);

// Get shortcuts count
int Shortcuts_getCount(void);

// Get shortcut path at index (without SDCARD_PATH prefix)
char* Shortcuts_getPath(int index);

// Get shortcut name at index
char* Shortcuts_getName(int index);

// Validate and clean up stale shortcuts (returns 1 if any were removed)
int Shortcuts_validate(void);

// Extract PAK basename from path (e.g., "/path/to/Retroarch.pak" -> "Retroarch")
// Returns pointer to static buffer, caller should copy if needed
char* Shortcuts_getPakBasename(const char* path);

#endif // SHORTCUTS_H
