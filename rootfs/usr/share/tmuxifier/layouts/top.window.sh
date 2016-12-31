# Set window root path. Default is `$session_root`.
# Must be called before `new_window`.
window_root "$session_root"

# Create new window. If no argument is given, window name will be based on
# layout file name.
new_window "top"

# Split window into panes.
split_h 50
select_pane 0
run_cmd "htop"
split_v 65
run_cmd "watch -t pstree"
select_pane 2
run_cmd "watch -t iostat -k -d -c -z"
split_v 65
run_cmd "iftop -n -i eth0"
split_v 50
run_cmd "iftop -n -i eth1"

# Set active pane.
select_pane 0
