/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

#include "ADGioCompat.h"
#include <CoreServices/CoreServices.h>

/*
 * Stand-in for GIO's g_content_type_guess(): returns the MIME type Launch Services
 * associates with the file's extension (what GIO itself does on OS X).
 */
gchar *
g_content_type_guess(const gchar *filename, const guchar *data, gsize data_size, gboolean *result_uncertain)
{
	gchar *mimetype = NULL;
	const gchar *dot = filename ? strrchr(filename, '.') : NULL;

	(void) data;
	(void) data_size;

	if (dot && dot[1]) {
		CFStringRef ext = CFStringCreateWithCString(NULL, dot + 1, kCFStringEncodingUTF8);
		CFStringRef uti = ext ? UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL) : NULL;
		CFStringRef mime = uti ? UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType) : NULL;
		char buf[256];

		if (mime && CFStringGetCString(mime, buf, sizeof(buf), kCFStringEncodingUTF8))
			mimetype = g_strdup(buf);

		if (mime) CFRelease(mime);
		if (uti) CFRelease(uti);
		if (ext) CFRelease(ext);
	}

	if (result_uncertain)
		*result_uncertain = FALSE;

	return mimetype ? mimetype : g_strdup("application/octet-stream");
}
