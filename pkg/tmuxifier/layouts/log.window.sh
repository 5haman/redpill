# Set window root path. Default is `$session_root`.
# Must be called before `new_window`.
window_root "$session_root"

# Create new window. If no argument is given, window name will be based on
# layout file name.
new_window "log"

# Split window into panes.
tail="multitail --no-repeat --mergeall"
color="-cS hyperdock"
ln -sf /var/log/klogd/current /var/log/dmesg
run_cmd "$tail $color /var/log/dmesg $color /var/log/messages"
split_h 50
run_cmd "$tail $color /var/log/docker/current"

# Set active pane.
select_pane 0
