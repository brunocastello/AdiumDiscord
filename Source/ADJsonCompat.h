/*
 * Discord for Adium
 *
 * Force-included into every purple-discord source file.
 *
 * Adium 1.5.10 ships json-glib 0.9.2, whose scanner decodes each \uXXXX escape on its own and
 * aborts (g_assert (g_unichar_validate (uchar))) on the halves of a UTF-16 surrogate pair, which
 * is how JSON escapes emoji. All of purple-discord's parsing goes through
 * json_parser_load_from_data(), so route it through a version that first rewrites those
 * escapes as UTF-8.
 */

#ifndef AD_JSON_COMPAT_H
#define AD_JSON_COMPAT_H

#include <json-glib/json-glib.h>

gboolean ad_json_parser_load_from_data(JsonParser *parser, const gchar *data, gssize length, GError **error);

#define json_parser_load_from_data ad_json_parser_load_from_data

#endif
