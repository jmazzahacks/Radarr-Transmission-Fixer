#!/bin/bash

# A simple script for Radarr to run on download completion

# VARIABLES
REMOTE="transmission-remote -n USER:PASSWD" #Change USER and PASSWD

ENABLE_RADARR_REFRESH=0 # set 1 if you want radarr to refresh the movie
ENABLE_PLEX_TRASH=0  # set 1 if you want the script to clear plex trash

PLEXTOKEN="PLEX TOKEN" # add plex token if ENABLE_PLEX_TRASH=1
LIBRARY="LIBRARY ID"  # library id of plex
APIKEY="RADARR API KEY" # Radarr API Key

# IPS AND PORTS change as needed
PLEX_IP="127.0.0.1"
PLEX_PORT="32400"
RADARR_IP="127.0.0.1"
RADARR_PORT="7878"

# DONT CHANGE BELOW THIS LINE

# Event type
EVENTTYPE="${radarr_eventtype}"

# Torrent details
TORRENT_ID="${radarr_download_id}"
STORED_FILE="${radarr_moviefile_path}"
ORIGIN_FILE="${radarr_moviefile_sourcepath}"
SOURCEDIR="${radarr_moviefile_sourcefolder}"
MOVIE_ID="${radarr_movie_id}"

printferr() { echo "$@" >&2; }

if [[ "$EVENTTYPE" == "Test" ]]; then
    printferr "Connection Test Successful"
    exit 0
fi

printferr "Processing event type: $EVENTTYPE"

if [ -e "$STORED_FILE" ]; then
    printferr "Processing new download: ${radarr_movie_title}"

    # Remove the torrent from Transmission
    $REMOTE -t "$TORRENT_ID" --remove
    printferr "Torrent ID: $TORRENT_ID removed from Transmission"

    # Delete the original file
    if [ -e "$ORIGIN_FILE" ]; then
        rm -f "$ORIGIN_FILE"
        printferr "Deleted original file: $ORIGIN_FILE"
        
        # Check and remove source directory if empty
        if [ "$(ls -A "$SOURCEDIR")" ]; then
            printferr "Source directory $SOURCEDIR is not empty. Skipping removal."
        else
            rmdir "$SOURCEDIR" && printferr "Removed empty source directory: $SOURCEDIR"
        fi
    else
        printferr "Original file not found: $ORIGIN_FILE"
    fi
else
    printferr "Stored file not found: $STORED_FILE"
fi

# Plex trash cleanup
if [ $ENABLE_PLEX_TRASH -eq 1 ]; then
    printferr "Telling Plex to clean up trash"
    curl -s -X PUT -H "X-Plex-Token: $PLEXTOKEN" http://$PLEX_IP:$PLEX_PORT/library/sections/$LIBRARY/emptyTrash
fi

# Radarr movie rescan
if [ $ENABLE_RADARR_REFRESH -eq 1 ]; then
    printferr "Telling Radarr to rescan movie files for ID: $MOVIE_ID"
    curl -s -H "Content-Type: application/json" -H "X-Api-Key: $APIKEY" -d "{\"name\":\"RefreshMovie\",\"movieIds\":[$MOVIE_ID]}" http://$RADARR_IP:$RADARR_PORT/api/v3/command > /dev/null
fi

printferr "Script processing completed."
