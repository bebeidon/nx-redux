#include "tabbg_model.h"

#include <stdio.h>
#include <string.h>

// Formats into out and keeps it only when it fit and the file is on the card.
static bool tryPath(char* out, size_t size, TabBgExistsFn exists_fn, const char* fmt, int len, const char* dir,
					const char* name) {
	int n = snprintf(out, size, fmt, len, dir, name);
	return n > 0 && (size_t)n < size && exists_fn(out);
}

bool TabBg_path(TabBgKind kind, const char* entry_path, bool controller_art, TabBgExistsFn exists_fn, char* out,
				size_t size) {
	if (!entry_path || !exists_fn || !out || size == 0)
		return false;
	int len = (int)strlen(entry_path);
	while (len > 1 && entry_path[len - 1] == '/')
		len--;
	if (len == 0)
		return false;

	if (kind == TABBG_CONSOLES) {
		if (controller_art)
			return false;
		return tryPath(out, size, exists_fn, "%.*s/.media/%s", len, entry_path, "bg.png");
	}

	// collection: the folder holding the .txt, and the file name without .txt
	const char* slash = NULL;
	for (int i = len - 1; i >= 0; i--) {
		if (entry_path[i] == '/') {
			slash = entry_path + i;
			break;
		}
	}
	if (!slash || slash == entry_path)
		return false;
	int dir_len = (int)(slash - entry_path);
	char name[256];
	int name_len = len - dir_len - 1;
	if (name_len >= 4 && strncmp(slash + 1 + name_len - 4, ".txt", 4) == 0)
		name_len -= 4;
	if (name_len <= 0 || name_len >= (int)sizeof(name) - 4)
		return false;
	snprintf(name, sizeof(name), "%.*s.png", name_len, slash + 1);

	if (tryPath(out, size, exists_fn, "%.*s/.media/%s", dir_len, entry_path, name))
		return true;
	return tryPath(out, size, exists_fn, "%.*s/.media/%s", dir_len, entry_path, "bg.png");
}
