# Set window root path. Default is `$session_root`.
# Must be called before `new_window`.
window_root "$session_root"

# Create new window. If no argument is given, window name will be based on
# layout file name.
new_window "log"

# Split window into panes.
tail="multitail --no-repeat --retry-all --mergeall --mark-change -cS hyperdock"
run_cmd "$tail /var/log/dmesg/current /var/log/dropbear/current /var/log/messages/current"
split_h 50
run_cmd "$tail /var/log/docker/current /var/log/portainer/current"
#run_cmd "multitail --no-repeat --retry-all --mergeall --mark-change -cS hyperdock $(find -L /var/log -name current | grep -E "docker|portainer" | tr "\n" " ")"

# Set active pane.
select_pane 0
