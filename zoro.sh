#!/bin/sh

[ -z "$*" ] && printf "Search an anime: " && read -r query || query=$*
query=$(printf "%s" "$query" | tr " " "+")
anime_info=$(curl -s "https://zoro.to/search?keyword=$query"|sed -nE 's_.*href="(.*)\?ref=search" title="([^"]*)".*_\1|\2_p')
choice=$(printf "%s" "$anime_info"|fzf -d "\|" --with-nth 2..)
anime_id=$(printf "%s" "$choice"|cut -d"|" -f1|grep -o "[0-9]*$")
anime_name=$(printf "%s" "$choice" | cut -d"|" -f2)

# episodes_list=$(curl -s "https://zoro.to/ajax/v2/episode/list/$anime_id"|grep -Eo 'title=\\"(.+?)\\".+?href=\\"(.+?)\\"'|
#   sed -En 's_.*title=\\"([^\"]*)\\".*href=\\"([^\"]*)\\"_\1|\2_p')
episodes_list=$(curl -s "https://zoro.to/ajax/v2/episode/list/$anime_id"|grep -Eo 'href=\\"([^\\"]*)\\"'|grep -v "javascript"|sed -En 's_href=\\"(.*)\\"_\1_p')
# episode_names=$(printf "%s" "$episodes_list"|cut -d'|' -f1)
episodes_links=$(printf "%s" "$episodes_list"|cut -d'|' -f2)

episodes_number=$(printf "%s\n" "$episodes_links"|wc -l|tr -d "[:space:]")

[ "$episodes_number" -eq 0 ] && printf "No episodes found\n" && exit 1 || [ "$episodes_number" -eq 1 ]
[ "$episodes_number" -gt 1 ] && printf "Choose an episode number between 1 and %s: " "$episodes_number" && read -r episode_number # && episode_name=$(printf "%s" "$episode_names"|sed -n "$episode_number"p)
[ -z "$episode_number" ] && episode_number="$episodes_number" # && episode_name=$(printf "%s" "$episode_names"|sed -n "$episode_number"p)

episode_id=$(printf "%s\n" "$episodes_links"|sed -n "${episode_number}p"|grep -o '[^=]*$')
source_id=$(curl -s "https://zoro.to/ajax/v2/episode/servers?episodeId=$episode_id"|sed -En 's_data-id=\\"([^"]*)\\".*_\1_p'|grep -o '[^"]*$'|tr -d "[:space:]")
link=$(curl -s "https://zoro.to/ajax/v2/episode/sources?id=$source_id")
rapid_link=$(printf "%s" "$link"|sed -En 's_.*"link":"([^"]*)".*_\1_p')
rapid_id=$(printf "%s" "$link"|sed -En 's_.*"link":"(.*)6/(.*)\?z=".*_\2_p')

domain="aHR0cHM6Ly9yYXBpZC1jbG91ZC5ydTo0NDM."
key=$(curl -s "$rapid_link" -e "https://zoro.to"|sed -En "s_.*recaptchaSiteKey = '([^']*)',.*_\1_p")
vtoken=$(curl -s "https://www.google.com/recaptcha/api.js?render=$key"|sed -En "s_.*po.src='.*/(.*)/recaptcha.*_\1_p")
recaptcha_token=$(curl -s "https://www.google.com/recaptcha/api2/anchor?ar=1&hl=en&size=invisible&cb=cs3&k=${key}&co=${domain}&v=${vtoken}"|
  sed -En 's_.*id="recaptcha-token" value="([^"]*)".*_\1_p')

token=$(curl -s "https://www.google.com/recaptcha/api2/reload?k=${key}" \
    -d "v=${vtoken}" \
    -d "k=${key}" \
    -d "c=${recaptcha_token}" \
    -d "co=${domain}" \
    -d "sa=" \
    -d "reason=q" \
    |sed -En 's_[^"]*"([^"]*)","([^"]*)".*_\2_p')

json=$(curl -s "https://rapid-cloud.ru/ajax/embed-6/getSources?id=$rapid_id&_token=$token")
video_link=$(printf "%s" "$json"|tr "{|}" "\n"|sed -En 's_"file":"([^"]*).*_\1_p'|head -n1)
subs=$(printf "%s" "$json"|tr "{|}" "\n"|sed -En 's_"file":"([^"]*).*_\1_p'|grep "cc.zorores"|sed 's/:/\\:/g'|tr "\n" ":"|sed 's/:$//')

[ -z "$video_link" ] && printf "No video link found\n" && exit 1
[ -n "$subs" ] && mpv --sub-files="$subs" --force-media-title="$anime_name - Ep: $episode_number" "$video_link" ||
  mpv "$video_link" --force-media-title="$anime_name - Ep: $episode_number"


