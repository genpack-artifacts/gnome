#!/bin/sh
set -e

# Gentoo's pipewire packaging documents that, on systemd systems, PipeWire
# user units should be enabled explicitly for each desktop user (or via
# systemctl --global for all users), so we apply that recommended setup here.

systemctl --global enable pipewire.socket pipewire-pulse.socket
systemctl --global --force enable wireplumber.service
systemctl --global disable pipewire-media-session.service || true
