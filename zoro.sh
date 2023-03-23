#!/bin/sh

images_cache_dir="/tmp/zoro-images"
image_config_path="$HOME/.config/rofi/styles/image-preview.rasi"
test -d "$images_cache_dir" || mkdir "$images_cache_dir"
query=$(printf "" | rofi -dmenu -l 0 -i -p "" -mesg "Search an anime: " | tr ' ' '+')
[ -z "$query" ] && exit 1
anime_list=$(curl -s "https://zoro.to/search?keyword=$query" | sed ':a;N;$!ba;s/\n//g;s/class="dynamic-name"/\n/g' |
	sed -nE 's_.*img data-src="([^"]*)".*href="(.*)\?ref=search".*title="([^"]*)".*_\3\t\2\t\1_p')
printf "%s\n" "$anime_list" | sed -nE "s@.*-([0-9]*)\t(.*)@\1\t\2@p" | while read -r media_id cover_url; do
	curl -s -o "$images_cache_dir/$media_id.jpg" "$cover_url" &
done
wait && sleep 1
IFS='	'
choice=$(printf "%b\n" "$anime_list" | sed -nE "s@(.*)\t(.*)-([0-9]*)\t(.*)@\1\t\2\t\3\t\4@p" | while read -r anime_title _link media_id cover_url; do
	printf "[%s]\t%s \x00icon\x1f%s/%s.jpg\n" "$media_id" "$anime_title" "$images_cache_dir" "$media_id"
done | rofi -dmenu -i -p "" -theme "$image_config_path" -mesg "Select anime" -display-columns 2..)
[ -z "$choice" ] && exit 1
anime_id=$(printf "%s" "$choice" | sed -nE "s_\[([0-9]*)\].*_\1_p")
anime_name=$(printf "%s" "$choice" | cut -f2)

episodes_links=$(curl -s "https://zoro.to/ajax/v2/episode/list/$anime_id" | tr "<|>" "\n" | sed -nE 's_.*data-id=\\"([0-9]*)\\".*_\1_p')
episodes_number=$(printf "%s\n" "$episodes_links" | wc -l | tr -d "[:space:]")

[ "$episodes_number" -eq 0 ] && notify-send "No episodes found\n"
[ "$episodes_number" -eq 0 ] && exit 1
[ "$episodes_number" -gt 1 ] && episode_number=$(rofi -dmenu -i -p "" -mesg "Choose and episode number between 1 and $episodes_number")
[ -z "$episode_number" ] && episode_number="$episodes_number"

episode_id=$(printf "%s\n" "$episodes_links" | sed -n "${episode_number}p")
source_id=$(curl -s "https://zoro.to/ajax/v2/episode/servers?episodeId=$episode_id" | tr "<|>" "\n" | sed -nE 's_.*data-id=\\"([^"]*)\\".*_\1_p' | head -1)
embed_link=$(curl -s "https://zoro.to/ajax/v2/episode/sources?id=$source_id" | sed -nE "s_.*\"link\":\"([^\"]*)\".*_\1_p")

# get the juicy links
parse_embed=$(printf "%s" "$embed_link" | sed -nE "s_(.*)/embed-(4|6)/(.*)\?vast=1\$_\1\t\2\t\3_p")
provider_link=$(printf "%s" "$parse_embed" | cut -f1)
source_id=$(printf "%s" "$parse_embed" | cut -f3)
embed_type=$(printf "%s" "$parse_embed" | cut -f2)

json_data=$(curl -s "${provider_link}/ajax/embed-${embed_type}/getSources?id=${source_id}" -H "X-Requested-With: XMLHttpRequest")
encrypted=$(printf "%s" "$json_data" | sed -nE "s_.*\"encrypted\":([^\,]*)\,.*_\1_p")
case "$encrypted" in
"true")
	key="$(curl -s "https://github.com/enimax-anime/key/blob/e${embed_type}/key.txt" | sed -nE "s_.*js-file-line\">(.*)<.*_\1_p")"
	video_link=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_.*\"sources\":\"([^\"]*)\".*_\1_p" | base64 -d |
		openssl enc -aes-256-cbc -d -md md5 -k "$key" 2>/dev/null | sed -nE "s_.*\"file\":\"([^\"]*)\".*_\1_p" | head -1)
	;;
"false")
	video_link=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_.*\"file\":\"([^\"]*)\".*_\1_p" | head -1)
	;;
esac
subs=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_\"file\":\"(.*\.vtt)\".*_\1_p" | sed 's/:/\\:/g' | tr "\n" ":" | sed 's/:$//')

notify-send -i "$images_cache_dir/$anime_id.jpg" "Playing $anime_name - Ep: $episode_number"
[ -z "$video_link" ] && notify-send "No video link found\n"
[ -z "$video_link" ] && exit 1
[ -n "$subs" ] && mpv --sub-files="$subs" --force-media-title="$anime_name - Ep: $episode_number" "$video_link" && exit 0
mpv "$video_link" --force-media-title="$anime_name - Ep: $episode_number"
