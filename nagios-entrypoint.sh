#!/bin/bash
set -e
    
# Add custom config to nagios.cfg if not already present
if ! grep -q "cfg_file=/opt/nagios/etc/objects/nodejs-api.cfg" /opt/nagios/etc/nagios.cfg; then
  echo "cfg_file=/opt/nagios/etc/objects/nodejs-api.cfg" >> /opt/nagios/etc/nagios.cfg
  echo "Custom Node.js API config added to Nagios"
fi
    
# Verify config before starting
/opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
    
# Start Nagios using original entrypoint
exec /usr/local/bin/start_nagios
