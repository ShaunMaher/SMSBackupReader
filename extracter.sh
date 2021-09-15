#!/bin/bash

# Dependencies:
#  Ubuntu:
#    jq xmlstarlet python3-pip sqlite3-pcre sqlite3
#    from pip: yq

output=1

while getopts "vd" opt; do
  case $opt in
    v) output=$(( $output + 1 )) ;;
    d) output=5 ;;
    *) usage "-${option} and ${OPTARG}" ;;
  esac
done

ns=""
args=("$@")
for (( i=1; i<="${#args[@]}"; i++ )); do
  shift
  case "${args[$i]}" in
    "parse")
      ns="parse"
      in_file=${args[$i + 1]}
      if [ "${in_file}" == "" ]; then
        echo "You didn't specify a file to parse."
      fi
      shift
      ;;
    "config") ns="config" ;;
    "generate") ns="generate" ;;
    "set")
      if [ "${ns}" == "config" ]; then
        ns="config_set"
        name=${args[$i + 1]}
        value=${args[$i + 2]}
        shift 2
        #echo "update config database: set ${name} ${value}"
      fi
      ;;
    "get")
      if [ "${ns}" == "config" ]; then
        ns="config_get"
        name=${args[$i + 1]}
        shift
        #echo "query config database: get ${name}"
      fi
      ;;
    "clear")
      if [ "${ns}" == "config" ]; then
        ns="config_clear"
        #echo "query config database: get ${name}"
      fi
      ;;
    "html")
      if [ "${ns}" == "generate" ]; then
        ns="generate_html"
        #echo "query config database: get ${name}"
      fi
      ;;
    *) set -- "$@" "$arg"
  esac
done

config_get () {
  sql_query="SELECT value FROM config WHERE ((name = '"$1"') AND (version = (SELECT MAX(version) AS version FROM config WHERE name = '"$1"')))"
  if [ $output -gt 3 ]; then echo "${sql_query}" 1>&2; fi
  return=$(echo "${sql_query}" | sqlite3 "${database_file}")
  if [ $output -gt 3 ]; then echo "${sql_query}: ${return}" 1>&2; fi
  echo "${return}"
}

config_set () {
  sql_query="INSERT INTO config VALUES('"$(date +%s)"', '"$1"', '"$2"');"
  if [ $output -gt 3 ]; then echo "${sql_query}" 1>&2; fi
  echo "${sql_query}" | sqlite3 "${database_file}"
}

config_clear () {
  sql_query="DELETE FROM config;"
  if [ $output -gt 3 ]; then echo "${sql_query}" 1>&2; fi
  echo "${sql_query}" | sqlite3 "${database_file}"
}

config_quick () {
  true
}

attachments_dir="./example-data/attachments/"
database_file="./data/temp"
if [ ! -f "${database_file}" ]; then
  echo "An existing database was not found.  One will be created."
  echo "CREATE TABLE messages(message_time INTEGER, extraction_time INTEGER, sender TEXT, message_json TEXT)" | \
    sqlite3 "${database_file}"
  echo "CREATE TABLE config(version INTEGER, name TEXT, value TEXT)" | \
    sqlite3 "${database_file}"
  echo "CREATE TABLE state(version INTEGER, name TEXT, value TEXT)" | \
    sqlite3 "${database_file}"
fi

my_intl_code=$(config_get "my_intl_code")
if [ "${my_intl_code}" == "" ]; then
  echo "You should set your international dialing code to help normalize the numbers displayed."
  echo "For example, if you live in Australia, run the command \"<TODO:my cmd name> config set my_intl_code 61\""
  my_intl_code="61"
fi

normalize_number () {
  return=$(echo "${1}" | sed "s/\\+${my_intl_code}/0/g")
  if [ $output -gt 2 ]; then echo "Normalized number: '${1}' -> '${return}'" 1>&2; fi
  echo "${return}"
}

parse () {
  echo "Parsing file ${in_file}"
  sms_count=$(cat "${in_file}" | xmlstarlet sel -t -v "count(/smses/sms)" 2>/dev/null)
  echo "Processing $sms_count SMS messages"
  for (( i=1; i<=$sms_count; i++ )); do
    message=$(cat "${in_file}" | xmlstarlet sel -t -c "/smses/sms[$i]" 2>/dev/null)
    safe_json=$(printf "${message}" | xq | sed "s/'/\&#39;/g")
    message_date=$(echo "${safe_json}" | jq -r '.sms["@date"]' | awk '{print int($1/1000)}')
    sender=$(echo "${safe_json}" | jq -r '.sms["@address"]')
    sender=$(normalize_number "${sender}")
    sql_insert="INSERT INTO messages VALUES (${message_date}, "$(date +%s)", '${sender}', '${safe_json}');"
    sql_count="SELECT COUNT(*) FROM messages WHERE HEX(SHA3(message_json)) = HEX(SHA3('${safe_json}'))"
    existing_count=$(echo "${sql_count}" | sqlite3 "${database_file}")
    if [ $existing_count -lt 1 ]; then
      echo "${sql_insert}" | sqlite3 "${database_file}"
    else
      echo "  Not inserting duplicate message into database"
    fi
  done

  mms_count=$(cat "${in_file}" | xmlstarlet sel -t -v "count(/smses/mms)" "${in_file}" 2>/dev/null)
  echo "Processing ${mms_count} MMS messages"
  for (( i=1; i<=$mms_count; i++ )); do
    message=$(cat "${in_file}" | xmlstarlet sel -t -c "/smses/mms[$i]" 2>/dev/null)
    images=$(echo "${message}" | xmlstarlet sel -t -v "count(/mms/parts/part[@ct=\"image/jpeg\"])" 2>/dev/null)
    echo "  Extracting $images image(s) from message"
    for (( p=1; p<=$images; p++ )); do
      filename=$(mktemp)
      echo "${message}" | \
        xmlstarlet sel -t -v "/mms/parts/part[@ct=\"image/jpeg\"][$p]/@data" | \
        base64 -d >${filename}
      new_name=$(md5sum ${filename} | awk '{print $1}')".jpeg"
      if [ ! -f "attachments/${new_name}" ]; then
        mv "${filename}" "${attachments_dir}/${new_name}"
      fi
      safe_json=$(
        echo "${message}" | \
        xmlstarlet ed -u "/mms/parts/part[@ct=\"image/jpeg\"][$p]/@data" -v "${new_name}" | \
        xq | \
        sed "s/'/\&#39;/g"
      )
      message_date=$(echo "${safe_json}" | jq -r '.mms["@date"]' | awk '{print int($1/1000)}')
      sender=$(echo "${safe_json}" | jq -r '.mms["@address"]')
      sender=$(normalize_number "${sender}")
      sql_count="SELECT COUNT(*) FROM messages WHERE HEX(SHA3(message_json)) = HEX(SHA3('${safe_json}'))"
      sql_insert="INSERT INTO messages VALUES (${message_date}, "$(date +%s)", '${sender}', '${safe_json}');"
      existing_count=$(echo "${sql_count}" | sqlite3 "${database_file}")
      if [ $existing_count -lt 1 ]; then
        echo "${sql_insert}" | sqlite3 "${database_file}"
      else
        echo "  Not inserting duplicate message into database"
      fi
    done
  done
}

generate_html () {
  # To get a list of unique senders
  # SELECT DISTINCT(COALESCE(json_extract(message_json, '$.mms.@address'), COALESCE(json_extract(message_json, '$.sms.@address'), ''))) as sender FROM messages;
  #sql_query="SELECT DISTINCT(COALESCE(json_extract(message_json, '\$.mms.@address'), COALESCE(json_extract(message_json, '\$.sms.@address'), ''))) as sender FROM messages;"
  sql_query="SELECT DISTINCT(sender) as sender FROM messages;"
  while read sender; do
    echo "Generating a view for sender ${sender}"
  done < <(echo "${sql_query}" | sqlite3 "${database_file}")

  sql_query="SELECT MIN(message_time) as max FROM messages;"
  oldest=$(echo "${sql_query}" | sqlite3 "${database_file}")
  sql_query="SELECT MAX(message_time) as max FROM messages;"
  newest=$(echo "${sql_query}" | sqlite3 "${database_file}")
  # A lazy way to generate a list of months between the oldest known message and
  #  the newest.  Start at the oldest date, add one day at a time and have the
  #  "date" command report what month that was.  Then dedup the list.
  for (( i=$oldest; i<=$newest; i+=3600 )); do
    echo "$i "$(date --date="@${i}" "+%B %Y")
  done
}

case "${ns}" in
  parse) parse ;;
  generate_html) generate_html ;;
  config_set) config_set "${name}" "${value}" ;;
  config_get) config_get "${name}" ;;
  config_clear) config_clear ;;
esac
