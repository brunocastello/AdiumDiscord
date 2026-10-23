/*
 * Discord for Adium
 *
 * Force-included into every purple-discord source file.
 *
 * Adium 1.5.10 ships glib 2.38 without GIO; purple-discord only needs it for
 * g_content_type_guess() when sending a file, so ADGioCompat.c provides that one function.
 */

#ifndef AD_GIO_COMPAT_H
#define AD_GIO_COMPAT_H

#include <glib.h>

gchar *g_content_type_guess(const gchar *filename, const guchar *data, gsize data_size, gboolean *result_uncertain);

#endif
