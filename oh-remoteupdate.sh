#!/bin/bash
#
# this script needs a config file with the following parameters:
# REMOTE_DIR="<openhab-config-dir>"
# USER=<openhab-username>
# HOST=<openhab-ip-address>
# IPCAM_FIX_URL="<url of ipcam_fix>"
# IPCAM_DYN_URL="<url of ipcam_dyn>"
# MQTT_USER="mqtt username"
# MQTT_PWD="mqtt password"
#

# Setting up a staging area
TEMP_DIR=`mktemp -d`

TARGET=${1:-notspecified}
if [ "${TARGET}" == "notspecified" ]; then
    if [ -f target_env ]; then
        source target_env
    fi
fi
echo "${TARGET}" | grep --extended-regexp "hus1|mnd|mnd-oh2|local" > /dev/null
TARGET_VERIFIED=$?
if [[ ! $TARGET_VERIFIED -eq 0 ]]; then
    echo "Target '${TARGET}' does not exist, exiting!"
    exit 1
fi
CONFIG_FILE="../cool.cfg@${TARGET}"

if [ ! -f $CONFIG_FILE ]; then
  echo "${CONFIG_FILE} doesn't exist"
  exit 1
fi
source $CONFIG_FILE

echo "$CONFIG_FILE sourced"

SSH_CMD='ssh '
LOCAL_DIR="./conf"
CONNECTION="${USER}@${HOST}"

if [ ! -d $LOCAL_DIR/persistence ]; then
  echo "${LOCAL_DIR}/persistence doesn't exist"
  exit 1
fi
if [ ! -d $LOCAL_DIR/rules ]; then
  echo "${LOCAL_DIR}/rules doesn't exist"
  exit 1
fi
if [ ! -d $LOCAL_DIR/sitemaps ]; then
  echo "${LOCAL_DIR}/sitemaps doesn't exist"
  exit 1
fi

echo "Config for the connection: $CONNECTION" >&2

git fetch
git pull

# copy to staging dir
echo "copy to staging dir '$TEMP_DIR': ${LOCAL_DIR}"
rsync -avz --quiet --exclude '.git' "${LOCAL_DIR}" "${TEMP_DIR}"

function replace() {
    langRegex='(.*)=\"(.*)"'
    if [[ ! $1 == \#* ]]; then
        if [[ $1 =~ $langRegex ]]; then
           RE1=${BASH_REMATCH[1]}
           RE2=${BASH_REMATCH[2]}
           RE2=${RE2//[\/]/\\/}
           RE2=${RE2//[\&]/\\&}

           #echo "Executing command: find $TEMP_DIR -type f -print0 | xargs -0 sed -i \"s/@@${RE1}@@/${RE2}/g\""
           echo "Replacing: ${RE1} with ${RE2}"
           find $TEMP_DIR -type f -print0 | xargs -0 sed -i  "s/@@${RE1}@@/${RE2}/g"
        fi 
    fi 
}

while read p; do
    replace $p
done <$CONFIG_FILE

#cowsay "config ready to be transferred: ${TEMP_DIR}"

echo "Executing: rsync -avz --exclude '.git' -e ${SSH_CMD} \"${TEMP_DIR}/\" ${CONNECTION}:\"${REMOTE_DIR}\""
rsync -avz --exclude '.git' -e $SSH_CMD "$TEMP_DIR/" ${CONNECTION}:${REMOTE_DIR}

#ssh ${CONNECTION} 'bash -s' < link-addons.sh


#rm -rf $TEMP_DIR
