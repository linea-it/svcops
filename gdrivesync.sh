#!/bin/bash

#
# name: sincroniza_gdrive.sh
# version: 1.0 2022-06-08
# description: script to download/delete videos from gdrive
# author: services at linea dot gov dot br
#
# requirements: a zap on zapier service on lineabrazil account

export PATH=$PATH:$HOME/bin
GBASE="/mnt/videos"
FTMP="/mnt/videos/tmp"
LOGFILE="$GBASE/logs/gdrive-`date +%Y%m%d`.log"

# ID Videos Linea 1RaVrO-FN221aO4bUWxfN630cREzoVrhi

#1zgDI9LkCkO05M1jNAo7-SuDDhcnYsBD7   Bkp_zoom_nic
#1K2luyzDwskdG0GEHmtwpjLxScJ0Vzyge   Bpk_zoom_interno
#1QficdPD5vodCXYqBxV5-bvC5YQYq_Gk6   Bkp_zoom_externo

cd $FTMP

PDIRS="1zgDI9LkCkO05M1jNAo7-SuDDhcnYsBD7:Bkp_zoom_nic 1K2luyzDwskdG0GEHmtwpjLxScJ0Vzyge:Bpk_zoom_interno 1QficdPD5vodCXYqBxV5-bvC5YQYq_Gk6:Bkp_zoom_externo"
#PDIRS="145SBzM9Gh6F3xJla9tcxL8ULcSPQJVME:pasta1"


function download_file_from_gdrive() # download files from gdrive and sync them to a local dir
{
    for p in $PDIRS
    do

        ID_DIR=$(echo $p | cut -d ':' -f 1)
        NAME_DIR=$(echo $p | cut -d ':' -f 2)

        F_IDLIST=$(gdrive list --query " '$ID_DIR' in parents" | awk -F ' ' '{print $1}' | tail -n +2)
        
        for fileid in $F_IDLIST
        do  

            gdrive download $fileid &>> $LOGFILE

            mkdir -p $GBASE/$NAME_DIR

            cp -av *.mp4 *.zip $GBASE/$NAME_DIR

            # armazena arquivos baixados em lista separada
            gdrive info $fileid >> `date +%Y%m%d`.list

        done

    done
}

function del_files_from_gdrive() # delete files synced yesterday
{

    F_IDLIST=$(cat `date --date='1 day ago' +%Y%m%d`.list | grep "Id:" | cut -d ':' -f 2 | sed -e 's/^[ \t]*//')
    
    for fileid in $F_IDLIST
    do

        gdrive delete $fileid &>> $LOGFILE
        
    done
}

function send_notification() # send notification for monitoring
{

    LIST_TODAY=`date +%Y%m%d`.list
    LIST_YESTERDAY=`date --date='1 day ago' +%Y%m%d`.list
    LOGFILE_CONTENT=$(cat $LOGFILE | sed 's/$/\\n/')
    LIST_TODAY_CONTENT=$(cat $LIST_TODAY | sed 's/$/\\n/')
    LIST_YESTERDAY_CONTENT=$(cat $LIST_YESTERDAY | sed 's/$/\\n/')
    SUBJECT="[gdrive] Zoom report syncronization files `date`"
    MSG="
================== LOGS ===================
\n
$LOGFILE_CONTENT
\n\n
================== ARQUIVOS BAIXADOS ===================
\n
$LIST_TODAY_CONTENT
\n\n
================== ARQUIVOS DELETADOS ===================
\n
$LIST_YESTERDAY_CONTENT
"
#echo -e $MSG
echo -e $MSG | mail -s "$SUBJECT" exemplo@exemplo.com

}

download_file_from_gdrive
del_files_from_gdrive
send_notification
