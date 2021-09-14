#!/bin/bash

in_file="./sms-20210911002715.xml"
tmp_file=$(mktemp)
cp "${in_file}" "${tmp_file}"

mms_count=$(xpath -e "count(/smses/mms)" "${in_file}" 2>/dev/null)
echo ${mms_count}
for (( i=0; i<=$mms_count; i++ )); do
  images=$(xpath -e "count(/smses/mms[$i]/parts/part[@ct=\"image/jpeg\"])" "${in_file}" 2>/dev/null)
  echo $images
  for (( p=1; p<=$images; p++ )); do
    filename=$(mktemp)
    xpath -q -e "/smses/mms[$i]/parts/part[@ct=\"image/jpeg\"][$p]/@data" "${in_file}" |\
      sed 's/ data="//g' |\
      sed 's/"$//g' |\
      base64 -d >${filename}
    new_name=$(md5sum ${filename} | awk '{print $1}')".jpeg"
    if [ ! -f "attachments/${new_name}" ]; then
      mv "${filename}" "attachments/${new_name}"
    fi
    xmlstarlet ed -u "/smses/mms[$i]/parts/part[@ct=\"image/jpeg\"][$p]/@data" -v "${new_name}" "${tmp_file}" >"${tmp_file}.new"
    mv "${tmp_file}.new" "${tmp_file}"
  done
done

cp "${tmp_file}" "${in_file}.stripped.xml"
