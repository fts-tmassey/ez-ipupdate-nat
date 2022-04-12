#! /bin/bash
# ez-ipupate-nat.sh : Use ez-ipupdate to update FQDN with public IP
# (C) 2022 Timothy J. Massey
# License:  GPL 2.0 or newer

CACHE_FILE="/tmp/hostname.ez-ipupdate-nat.cache"
PUBLIC_IP_URL="icanhazip.com"

# Echo only if user specifies Verbose output
vecho() {
    if [[ -n ${OPT_VERBOSE} ]]; then echo "${1}"; fi
}

# Check and process parameters
DEFAULT_CACHE_FILE=${CACHE_FILE}
while getopts "c:t:hv" OPT; do
   case ${OPT} in
      "c") # config file path
         CONF_FILE="${OPTARG}"
         ;;
      "t") # cache file
         CACHE_FILE="${OPTARG}"
         ;;
      "h") # display usage
         echo "${0}: -c <config file> [-t <cache file>] [-h] [-v]"
         echo "  -c <config file> : Path to ez-ipupdate config file"
         echo "  -t <cache file>  : Path to IP cache file"
         echo "                      Default: ${DEFAULT_CACHE_FILE}"
         echo "  -h               : Show this help information"
         echo "  -v               : Show verbose information"
         exit;;
      "v") # verbose output
         OPT_VERBOSE="Verbose"
         ;;
      "?") # invalid option
         # getopts was used to pass error to user, so we just need to
         exit;;
    esac
done
if [[ -n "${*:$OPTIND:1}" ]]; then # Look for unprocessed parameters
    echo "${0}: illegal extra parameters -- ${*:$OPTIND:1}"
    exit
fi

# Show user current settings if verbose is enabled
vecho "Verbose output enabled."
vecho "Using config file: ${CONF_FILE}"
vecho "Using cache file: ${CACHE_FILE}"

# Check config variables
if [[ ! -f ${CONF_FILE} ]]; then
    echo "${0}: CONF_FILE not found -- ${CONF_FILE}"
    echo "Exiting."
    exit
fi
if [[ ! -f ${CACHE_FILE} ]]; then
    vecho "The cache file was not found.  Creating an empty file."
    # Using touch to create file caused systemd permissions issue
    echo "Empty">"${CACHE_FILE}"
    if [[ ! -f ${CACHE_FILE} ]]; then
        echo "${0}: The CACHE_FILE could not be created -- ${CACHE_FILE}"
        echo "Exiting."
    fi
fi
PUBLIC_IP="$(curl -s -4 ${PUBLIC_IP_URL})"
vecho "Public IP retrieved:  ${PUBLIC_IP}"
if [[ ! "${PUBLIC_IP}" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
    echo "${0}: PUBLIC_IP is not valid -- ${PUBLIC_IP}"
    echo "Exiting."
    exit
fi

# See if IP needs to be updated
CACHED_IP=$(< "${CACHE_FILE}" )
vecho "Cached IP address:  ${CACHED_IP}"
if [[ "${CACHED_IP}" != "${PUBLIC_IP}" ]]; then
    vecho "Cached IP does not match public IP: update needed."
    # The following command runs the ez-ipupdate command and captures its output
    OUTPUT=$(ez-ipupdate -a "${PUBLIC_IP}" -c "${CONF_FILE}" 2>&1)
    if [[ "${OUTPUT}" == *"<SUCCESS"* ]] || [[ "${OUTPUT}" == *'<ERROR CODE="700"'* ]]; then
        # Update either successful or aleady correct (700); update cache
        vecho "DNS updated successfully: $(echo "${OUTPUT}"|cut -d'<' -f 2|cut -d'>' -f 1)"
        echo "${PUBLIC_IP}">"${CACHE_FILE}"
        if [[ ! -f ${CACHE_FILE} ]] || [[ $(< "${CACHE_FILE}" ) != "${PUBLIC_IP}" ]]; then
            echo "Warning: The cache file was not properly updated!"
        else
            vecho "The cache file was properly updated."
        fi
    else
        echo "The update received an error: $(echo "${OUTPUT}"|cut -d'<' -f 2|cut -d'>' -f 1)"
        echo "  The cache file will not be updated."
        vecho "  The full output from ez-ipudate is:"
        vecho "${OUTPUT}"
    fi
else
    vecho "Cached IP matches the public IP."
fi

vecho "${0}: Done."
exit
