/*
 * Discord for Adium
 *
 * Functions patches/0002-Add-helpers-for-the-Adium-plugin.patch adds to libdiscord.c.
 */

#ifndef AD_DISCORD_BRIDGE_H
#define AD_DISCORD_BRIDGE_H

#include <libpurple/libpurple.h>

typedef void (*DiscordAdiumChannelFunc)(const gchar *guild_id, const gchar *guild_name,
                                        const gchar *category_name, gint category_position,
                                        const gchar *channel_id, const gchar *channel_name,
                                        gint channel_position, gpointer user_data);

/* Calls func for every text and announcement channel the user can read, on every server */
void discord_adium_foreach_channel(PurpleConnection *pc, DiscordAdiumChannelFunc func, gpointer user_data);

/* "#channel (Server)" for a server channel, or NULL; free with g_free() */
gchar *discord_adium_get_channel_title(PurpleConnection *pc, const gchar *channel_id);

#endif
