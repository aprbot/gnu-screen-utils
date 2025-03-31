

./entrypoint.sh 'type screen'


source variables.sh

source screen-utils.sh

type screen

screen -mdS p-f bash -c 'while true; do env | grep "^ss"; sleep 20; echo; done'

screen -r p-f

