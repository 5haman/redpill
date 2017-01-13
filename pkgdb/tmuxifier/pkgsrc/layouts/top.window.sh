# Set window root path. Default is `$session_root`.
# Must be called before `new_window`.
window_root "$session_root"

# Create new window. If no argument is given, window name will be based on
# layout file name.
new_window "top"

# Split window into panes.
split_h 49
select_pane 0
run_cmd "iftop -n -i eth0"
split_v 50
run_cmd "iftop -n -i eth1"
select_pane 2
run_cmd "watch iostat -k -d"
split_v 75
run_cmd "htop"
