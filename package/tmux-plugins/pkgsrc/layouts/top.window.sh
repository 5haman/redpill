# Set window root path. Default is `$session_root`.
# Must be called before `new_window`.
window_root "$session_root"

# Create new window. If no argument is given, window name will be based on
# layout file name.
new_window "top"

# Split window into panes.
split_h 49
select_pane 0
run_cmd "iptraf-ng -i all"
select_pane 1
run_cmd "watch -t iostat -D"
split_v 90
run_cmd "htop"
