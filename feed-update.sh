#!/bin/sh

dst_dir=/var/www/html

if [ -s ${dst_dir}/config.php ]; then
  rm -f ${dst_dir}/lock/update_daemon*
  php ${dst_dir}/html/update_daemon2.php
fi
