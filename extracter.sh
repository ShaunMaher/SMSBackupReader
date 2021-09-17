#!/bin/bash

# Dependencies:
#  Ubuntu:
#    jq xmlstarlet python3-pip sqlite3-pcre sqlite3
#    from pip: yq

output=1
force=0

while getopts "fdv" opt; do
  case $opt in
    v) output=$(( $output + 1 )) ;;
    d) output=5 ;;
    f) force=1 ;;
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
  echo "CREATE TABLE contacts(version INTEGER, name TEXT, value TEXT)" | \
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

save_contact () {
  local message_contact_name="${1}"
  local orig_sender="${2}"
  local sender="${3}"
  if [ ! "${message_contact_name}" == "" ]; then
    local sql_query="SELECT DISTINCT(name) FROM contacts, json_each(contacts.value) WHERE ((json_each.value LIKE '${orig_sender}') OR (json_each.value LIKE '${sender}'));"
    contact_name=$(sql_query "${sql_query}")
    if [ "${contact_name}" == "" ]; then
      echo "No existing contact found for '${orig_sender}' or '${sender}'."

      # Does a contact with this name already exist?
      sql_count="SELECT COUNT(*) FROM contacts, json_each(contacts.value) WHERE name LIKE '${message_contact_name}';"
      if [ $(sql_query "${sql_count}") -lt 1 ]; then
        echo "No existing contact found for '${message_contact_name}'."
        sql_query="INSERT INTO contacts VALUES("$(date +%s)", '${message_contact_name}', '[ \"${orig_sender}\", \"${sender}\" ]');"
        sql_query "${sql_query}"
      else
        echo "An existing contact exists for '${message_contact_name}'.  This record will be updated with this new number."
        sql_query="SELECT DISTINCT(json_each.value) FROM contacts, json_each(contacts.value) WHERE name LIKE 'Shaun';"
        readarray -t numbers < <(sql_query "${sql_query}")
        local number_array="[ "
        for number in "${numbers[@]}"; do
          number_array="${number_array} ${number}"
        done
        number_array="${number_array} ]"
        sql_query="INSERT INTO contacts VALUES("$(date +%s)", '${message_contact_name}', '${number_array}')"
        echo "${sql_query}"
      fi
    fi
  fi
}

parse () {
  local in_file_full=$(readlink -f "${1}")
  local in_file_name=$(basename "${in_file_full}")

  local sql_count="SELECT COUNT(*) FROM state WHERE (name = 'parsed_file' AND value = '${in_file_full}');"
  local existing_count=$(echo "${sql_count}" | sqlite3 "${database_file}")
  if [ $existing_count -gt 0 ]; then
    if [ $force -eq 0 ]; then
      echo "Skipping '${in_file_name}' as it has been parsed previously.  Add '-f' to the command line to force re-parsing."
      return
    fi
  fi

  echo "Parsing file ${in_file_name}"
  sms_count=$(cat "${in_file_full}" | xmlstarlet sel -t -v "count(/smses/sms)" 2>/dev/null)
  echo "Processing $sms_count SMS messages"
  for (( i=1; i<=$sms_count; i++ )); do
    local message=$(cat "${in_file_full}" | xmlstarlet sel -t -c "/smses/sms[$i]" 2>/dev/null)
    local safe_json=$(printf "${message}" | xq | sed "s/'/\&#39;/g")
    local message_date=$(echo "${safe_json}" | jq -r '.sms["@date"]' | awk '{print int($1/1000)}')
    local message_contact_name=$(echo "${safe_json}" | jq -r '.sms["@contact_name"]' | grep -i -v "(Unknown)")
    local orig_sender=$(echo "${safe_json}" | jq -r '.sms["@address"]')
    local sender=$(normalize_number "${orig_sender}")

    save_contact "${message_contact_name}" "${orig_sender}" "${sender}"

    if [ $output -gt 4 ]; then echo "${safe_json}" | jq -C '.'; fi
    sql_count="SELECT COUNT(*) FROM messages WHERE HEX(SHA3(message_json)) = HEX(SHA3('${safe_json}'))"
    if [ $(sql_query "${sql_count}") -lt 1 ]; then
      sql_insert="INSERT INTO messages VALUES (${message_date}, "$(date +%s)", '${sender}', '${safe_json}');"
      sql_query "${sql_insert}"
    else
      echo "  Not inserting duplicate message into database"
    fi
  done

  mms_count=$(cat "${in_file_full}" | xmlstarlet sel -t -v "count(/smses/mms)" 2>/dev/null)
  echo "Processing ${mms_count} MMS messages"
  for (( i=1; i<=$mms_count; i++ )); do
    message=$(cat "${in_file_full}" | xmlstarlet sel -t -c "/smses/mms[$i]" 2>/dev/null)
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

      if [ $output -gt 4 ]; then echo "${safe_json}" | jq -C '.'; fi
      local message_date=$(echo "${safe_json}" | jq -r '.mms["@date"]' | awk '{print int($1/1000)}')
      local orig_sender=$(echo "${safe_json}" | jq -r '.mms["@address"]')
      local sender=$(normalize_number "${orig_sender}")
      local message_contact_name=$(echo "${safe_json}" | jq -r '.mms["@contact_name"]' | grep -i -v "(Unknown)")

      save_contact "${message_contact_name}" "${orig_sender}" "${sender}"

      sql_count="SELECT COUNT(*) FROM messages WHERE HEX(SHA3(message_json)) = HEX(SHA3('${safe_json}'))"
      if [ $(sql_query "${sql_count}") -lt 1 ]; then
        sql_insert="INSERT INTO messages VALUES (${message_date}, "$(date +%s)", '${sender}', '${safe_json}');"
        sql_query "${sql_insert}"
      else
        echo "  Not inserting duplicate message into database"
      fi
    done
  done
  sql_insert="INSERT INTO state VALUES ("$(date +%s)", 'parsed_file', '${in_file_full}');"
  echo "${sql_insert}" | sqlite3 "${database_file}"
}

# A rather inellegant way of convincing the "date" utility to give us the
#  unixtime that a given month started
month_start () {
  local return=$(date --date="$(date --date="@${1}" "+1-%b-%Y 00:00:00")" +%s)
  echo $return
}

# A rather inellegant way of convincing the "date" utility to give us the
#  unixtime that a given month ends using a loop to slowly feel our way towards
#  the month end.
month_end () {
  local this_month=$(date --date="@${1}" "+%b")
  local next_month="${this_month}"
  local i=$1
  while [ "${next_month}" == "${this_month}" ]; do
    i=$(( $i + 86400 ))
    next_month=$(date --date="@${i}" "+%b")
    #echo ${next_month}
  done
  next_month=$(month_start $i)
  echo $(( ${next_month} - 1 ))
}

# Still inellegant.  Work out the start and end times of all the months within
#  a given date range
generate_months () {
  local return=""
  local this_month=$(date --date="@${1}" "+%B %Y")
  local next_month="${this_month}"
  local i=$1
  echo "$(month_start $i)|$(month_end $i)|${next_month}"
  while [ $i -lt $2 ]; do
    while [ "${next_month}" == "${this_month}" ]; do
      i=$(( $i + 86400 ))
      next_month=$(date --date="@${i}" "+%B %Y")
      #echo ${next_month}
    done
    if [ $i -lt $2 ]; then
      echo "$(month_start $i)|$(month_end $i)|${next_month}"
    fi

    i=$(( $i + 86400 ))
    this_month=$(date --date="@${i}" "+%B %Y")
    local next_month="${this_month}"
  done
}

message_to_html () {
  local message_json="${1}"
  local sender_friendly_name="${2}"
  local type=$(echo "${message_json}" | jq -r 'keys_unsorted[]')
  case $type in
    "mms") return=$(mms_to_html "${message_json}" "${sender_friendly_name}") ;;
    "sms") return=$(sms_to_html "${message_json}" "${sender_friendly_name}") ;;
  esac
  echo "${return}"
}

mms_to_html () {
  local message_json="${1}"
  local sender_friendly_name="${2}"
  local message_date=$(date --date="@$(echo "${message_json}" | jq -r '.mms["@date"]' | awk '{print int($1/1000)}')")
  local message_body=$(echo "${message_json}" | jq -r '.mms.parts[] | map(select(.["@ct"] | match("text/plain"))) | map(.["@text"]) | .[]')
  readarray -t images < <(echo "${message_json}" | jq -r '.mms.parts[] | map(select(.["@ct"] | match("image/jpeg"))) | map(.["@data"]) | .[]')
  for image in "${images[@]}"; do
    if [ ! "${message_body}" == "" ]; then message_body="${message_body}<br/>"; fi
    message_body="${message_body}<img src=\"../example-data/attachments/${image}\"/><br/>"
  done
  local sender_number=$(normalize_number $(echo "${message_json}" | jq -r '.sms["@address"]'))

  #echo "<div class=\"message\"><div class=\"message_header\">SMS: ${message_date}</div><div class=\"message_body\">" >>"${export_file}"
  #echo "<pre>${message_json}</pre>" >>"${export_file}"
  #echo "</div></div>" >>"${export_file}"

  cat "themes/${template_name}/mms_message.html" | \
    message_date="${message_date}" \
    message_body="${message_body}" \
    message_json="${message_json}" \
    message_type="${message_type}" \
    sender_friendly_name="${sender_friendly_name}" \
    sender_number="${sender_number}" \
    envsubst
}

sms_to_html () {
  local message_json="${1}"
  local sender_friendly_name="${2}"
  local message_date=$(date --date="@$(echo "${message_json}" | jq -r '.sms["@date"]' | awk '{print int($1/1000)}')")
  local message_body=$(echo "${message_json}" | jq -r '.sms["@body"]' | awk '{print $0"<br/>"}')
  local message_type="type"$(echo "${message_json}" | jq -r '.sms["@type"]')
  local sender_number=$(normalize_number $(echo "${message_json}" | jq -r '.sms["@address"]'))

  #echo "<div class=\"message\"><div class=\"message_header\">SMS: ${message_date}</div><div class=\"message_body\">" >>"${export_file}"
  #echo "<pre>${message_json}</pre>" >>"${export_file}"
  #echo "</div></div>" >>"${export_file}"

  cat "themes/${template_name}/sms_message.html" | \
    message_date="${message_date}" \
    message_body="${message_body}" \
    message_json="${message_json}" \
    message_type="${message_type}" \
    sender_friendly_name="${sender_friendly_name}" \
    sender_number="${sender_number}" \
    envsubst
}

sql_query() {
  local query=$(echo "${1}" | envsubst)
  if [ $output -gt 3 ]; then echo "sql_query: '${query}'" 1>&2; fi
  return=$(echo "${query}" | sqlite3 "${database_file}")
  if [ $output -gt 4 ]; then echo "sql_query: '${query}' returned '${return}'" 1>&2; fi
  echo "${return}"
}

generate_html () {
  local template_name=$(sql_query "SELECT value FROM config WHERE name = 'template_name' ORDER BY version DESC LIMIT 1;")
  if [ "${template_name}" == "" ]; then
    echo "No template configured.  Using 'default' template." 1>&2
    template_name="default"
    sql_query "INSERT INTO config VALUES ("$(date +%s)", 'template_name', 'default');"
  fi
  if [ $output -gt 1 ]; then echo "Template Name: ${template_name}" 1>&2; fi
  local css=$(cat "themes/${template_name}/styles.css")
  local js=$(cat "themes/${template_name}/scripts.js")

  # To get a list of unique senders
  # SELECT DISTINCT(COALESCE(json_extract(message_json, '$.mms.@address'), COALESCE(json_extract(message_json, '$.sms.@address'), ''))) as sender FROM messages;
  #sql_query="SELECT DISTINCT(COALESCE(json_extract(message_json, '\$.mms.@address'), COALESCE(json_extract(message_json, '\$.sms.@address'), ''))) as sender FROM messages;"
  sql_query="SELECT DISTINCT(sender) as sender FROM messages;"
  readarray -t senders < <(sql_query "${sql_query}")
  for sender in "${senders[@]}"; do
    echo "Generating a view for sender ${sender}"
    sql_query="SELECT MIN(message_time) as max FROM messages;"
    oldest=$(sql_query "${sql_query}")
    sql_query="SELECT MAX(message_time) as max FROM messages;"
    newest=$(sql_query "${sql_query}")

    local sender_friendly_name="Contacts not yet implemented -"

    readarray -t months < <(generate_months $oldest $newest)
    for month in "${months[@]}"; do
      IFS="|" read -ra parts <<< "${month}"
      local mname="${parts[2]}"
      local mend="${parts[1]}"
      local mstart="${parts[0]}"
      echo "$mname"

      export_file="export/${sender} - ${mname}.html"
      #echo "<html><head><title>${sender} - ${mname}</title></head><body>" >"${export_file}"
      cat "themes/${template_name}/header.html" | \
        title="${sender} - ${mname}" \
        css="${css}" \
        js="${js}" \
        envsubst >"${export_file}"

      # On the pages that are dedicated to a single sender, we don't need to
      #  display the sender details on every message.
      echo '
        <style>
          .sender_friendly_name.type1 {
            display: none;
          }
          .sender_number.type1 {
            display: none;
          }

          .header_divider.type1 {
            display: none;
          }
        </style>' >>"${export_file}"

      echo "
        <div class=\"page_heading h1\"><div class=\"contact_dot\">M</div>${sender_friendly_name}<div class=\"page_heading right\">${mname}</div></div>" >>"${export_file}"

      sql_query="SELECT message_time, REPLACE(REPLACE(message_json, X'0D', ''), X'0A', '') as message_json FROM messages WHERE ((sender = '$sender') AND (message_time >= $mstart) AND (message_time <= $mend)) ORDER BY message_time"
      readarray -t messages < <(sql_query "${sql_query}")
      for message in "${messages[@]}"; do
        #echo "${message}"
        IFS="|" read -ra parts <<< "${message}"
        local message_json="${parts[1]}"
        #echo "${message_json}" | jq -C
        message_to_html "${message_json}" "${sender_friendly_name}" >>"${export_file}"
      done

      cat "themes/${template_name}/footer.html" | \
        title="${sender} - ${mname}" \
        css="${css}" \
        envsubst >>"${export_file}"

      # At some future time, this value will be used to work out if the file needs
      #  to be generated at all.  If there are no new message DB entries after this
      #  date then the generated file would be the same as the existing one.
      sql_insert="INSERT INTO state VALUES ("$(date +%s)", 'generated_file', '[ \"${sender}\", \"${mname}\" ]');"
      sql_query "${sql_insert}"
    done
  done

  echo "Generating time based views"
  sql_query="SELECT MIN(message_time) as max FROM messages;"
  oldest=$(sql_query "${sql_query}")
  sql_query="SELECT MAX(message_time) as max FROM messages;"
  newest=$(sql_query "${sql_query}")
  readarray -t months < <(generate_months $oldest $newest)
  for month in "${months[@]}"; do
    echo "${month}"
  done
}

case "${ns}" in
  parse) parse ${in_file};;
  generate_html) generate_html ;;
  config_set) config_set "${name}" "${value}" ;;
  config_get) config_get "${name}" ;;
  config_clear) config_clear ;;
esac
