<?php
/**
 * Following configration file will be updated in the wordpress folder in runtime 
 *
 * Following configurations: Azure Database for MySQL server settings, Table Prefix,
 * Secret Keys, WordPress Language, and ABSPATH. 
 * 
 * wp-config.php  file is used during the installation.
 * Copy the wp-config file to wordpress folder.
 *
 */

// ** Azure Database for MySQL server settings - You can get the following details from Azure Portal** //
/** Database name for WordPress */
define('DB_NAME', '{{ wp_db_name }}');

/** username for MySQL database */
define('DB_USER', '{{ wp_db_user }}');

/** password for MySQL database */
define('DB_PASSWORD', '{{ wp_db_password }}');

/** Azure Database for MySQL server hostname */
define('DB_HOST', '{{wp_db_server_name}}');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

/**
 * Authentication Unique Keys and Salts.
 * You can generate unique keys and salts at https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service
 * You can change these at any point in time to invalidate all existing cookies.
 */

{{ wp_salt.stdout }}

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each a unique prefix.
 * Only numbers, letters, and underscores are allowed.
 */
$table_prefix  = 'wp_';

/**
 * WordPress Localized Language, defaults language is English.
 *
 * A corresponding MO file for the chosen language must be installed to wp-content/languages. 
 */
define('WPLANG', '');

/**
 * For developers: Debugging mode for WordPress.
 * Change WP_DEBUG to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG in their development environments.
 */
define('WP_DEBUG', false);

/** Disable Automatic Updates Completely */
define( 'AUTOMATIC_UPDATER_DISABLED', {{auto_up_disable}} );

/** Define AUTOMATIC Updates for Components. */
define( 'WP_AUTO_UPDATE_CORE', {{core_update_level}} );

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
  define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');

/** Avoid FTP credentails. */
define('FS_METHOD','direct');