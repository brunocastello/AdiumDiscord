/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

#include "ADJsonCompat.h"
#include <string.h>

/* This file calls the real parser */
#undef json_parser_load_from_data

static gint
hex4(const gchar *p)
{
	gint value = 0;
	gint i;

	for (i = 0; i < 4; i++) {
		gint digit = g_ascii_xdigit_value(p[i]);

		if (digit < 0) {
			return -1;
		}
		value = (value << 4) | digit;
	}

	return value;
}

/*
 * Returns a copy of data with every \uXXXX escape of a UTF-16 surrogate replaced by the UTF-8
 * bytes of the character it encodes (U+FFFD for an unpaired half), or NULL if there are none.
 * Raw UTF-8 is valid inside JSON strings, and json-glib 0.9.2 reads it fine.
 */
static gchar *
fix_surrogate_escapes(const gchar *data, gsize length, gsize *fixed_length)
{
	GString *fixed = NULL;
	gsize copied = 0;
	gsize i = 0;

	while (i < length) {
		gint high, low;
		gunichar ch;
		gsize escape_length;

		if (data[i] != '\\') {
			i++;
			continue;
		}

		/* Skip other escapes whole, so the "u" in "\\u" is not taken for an escape */
		if (i + 1 >= length || data[i + 1] != 'u' || i + 6 > length) {
			i += 2;
			continue;
		}

		high = hex4(data + i + 2);
		if (high < 0xD800 || high > 0xDFFF) {
			i += 6;
			continue;
		}

		ch = 0xFFFD;
		escape_length = 6;

		if (high < 0xDC00 && i + 12 <= length && data[i + 6] == '\\' && data[i + 7] == 'u') {
			low = hex4(data + i + 8);

			if (low >= 0xDC00 && low <= 0xDFFF) {
				ch = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
				escape_length = 12;
			}
		}

		if (fixed == NULL) {
			fixed = g_string_sized_new(length);
		}
		g_string_append_len(fixed, data + copied, i - copied);
		g_string_append_unichar(fixed, ch);

		i += escape_length;
		copied = i;
	}

	if (fixed == NULL) {
		return NULL;
	}

	g_string_append_len(fixed, data + copied, length - copied);
	*fixed_length = fixed->len;

	return g_string_free(fixed, FALSE);
}

gboolean
ad_json_parser_load_from_data(JsonParser *parser, const gchar *data, gssize length, GError **error)
{
	gchar *fixed;
	gsize fixed_length = 0;
	gboolean result;

	if (data == NULL) {
		return json_parser_load_from_data(parser, data, length, error);
	}

	if (length < 0) {
		length = strlen(data);
	}

	fixed = fix_surrogate_escapes(data, length, &fixed_length);
	if (fixed == NULL) {
		return json_parser_load_from_data(parser, data, length, error);
	}

	result = json_parser_load_from_data(parser, fixed, fixed_length, error);
	g_free(fixed);

	return result;
}
