log() {
    echo $'\e['"1;31m$(date "+%Y-%m-%d %H:%M:%S") [$(basename $0)] ${@}"$'\e[0m' 
}
