#!/bin/bash
apt-get remove -y --purge $(dpkg --get-selections | grep deinstall | awk '{ print $1; }')
