#!/bin/sh

[ -z "$*" ] && printf "Search an anime: " && read -r query || query=$*
query=$(printf "%s" "$query" | tr " " "+")
choice=$(curl -s "https://aniwatch.to/search?keyword=$query" | sed -nE 's_.*href="(.*)\?ref=search" title="([^"]*)".*_\1|\2_p' | fzf -1 -d "\|" --with-nth 2..)
anime_id=$(printf "%s" "$choice" | sed -nE "s_.*-([0-9]+)\|.*_\1_p")
anime_name=$(printf "%s" "$choice" | cut -d"|" -f2)

episodes_links=$(curl -s "https://aniwatch.to/ajax/v2/episode/list/$anime_id" | tr "<|>" "\n" | sed -nE 's_.*data-id=\\"([0-9]*)\\".*_\1_p')
episodes_number=$(printf "%s\n" "$episodes_links" | wc -l | tr -d "[:space:]")

[ "$episodes_number" -eq 0 ] && printf "No episodes found\n" && exit 1
[ "$episodes_number" -gt 1 ] && printf "Choose an episode number between 1 and %s: " "$episodes_number" && read -r episode_number
[ -z "$episode_number" ] && episode_number="$episodes_number"

episode_id=$(printf "%s\n" "$episodes_links" | sed -n "${episode_number}p")
source_id=$(curl -s "https://aniwatch.to/ajax/v2/episode/servers?episodeId=$episode_id" | tr "<|>" "\n" | sed -nE 's_.*data-id=\\"([^"]*)\\".*_\1_p' | head -1)
embed_link=$(curl -s "https://aniwatch.to/ajax/v2/episode/sources?id=$source_id" | sed -nE "s_.*\"link\":\"([^\"]*)\".*_\1_p")

# get the juicy links
parse_embed=$(printf "%s" "$embed_link" | sed -nE "s_(.*)/embed-(2|4|6)/e-([0-9])/(.*)\?k=1\$_\1\t\2\t\3\t\4_p")
provider_link=$(printf "%s" "$parse_embed" | cut -f1)
embed_type=$(printf "%s" "$parse_embed" | cut -f2)
e_number=$(printf "%s" "$parse_embed" | cut -f3)
source_id=$(printf "%s" "$parse_embed" | cut -f4)

json_data=$(curl -s "${provider_link}/embed-${embed_type}/ajax/e-${e_number}/getSources?id=${source_id}" -H "X-Requested-With: XMLHttpRequest")

json_key="file"
encrypted=$(printf "%s" "$json_data" | tr "{}" "\n" | sed -nE "s_.*\"${json_key}\":\"([^\"]*)\".*_\1_p" | grep "\.m3u8")
if [ -n "$encrypted" ]; then
    video_link=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_.*\"${json_key}\":\"([^\"]*)\".*_\1_p" | head -1)
else
    json_key="sources"
    encrypted=$(printf "%s" "$json_data" | tr "{}" "\n" | sed -nE "s_.*\"${json_key}\":\"([^\"]*)\".*_\1_p")
    embed_type="6"
    enikey=$(curl -s "https://github.com/enimax-anime/key/blob/e${embed_type}/key.txt" | sed -nE "s@.*rawLines\":\[\"([^\"]*)\".*@\1@p" |
        sed 's/\[\([0-9]*\),\([0-9]*\)\]/\1-\2/g;s/\[//g;s/\]//g;s/,/ /g')

    encrypted_video_link=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_.*\"sources\":\"([^\"]*)\".*_\1_p" | head -1)

    final_key=""
    tmp_encrypted_video_link="$encrypted_video_link"
    for key in $enikey; do
        start="${key%-*}"
        start=$((start + 1))
        end="${key#*-}"
        key=$(printf "%s" "$encrypted_video_link" | cut -c"$start-$end")
        final_key="$final_key$key"
        tmp_encrypted_video_link=$(printf "%s" "$tmp_encrypted_video_link" | sed "s/$key//g")
    done

    # ty @CoolnsX for helping me with figuring out how to implement aes in openssl
    video_link=$(printf "%s" "$tmp_encrypted_video_link" | base64 -d |
        openssl enc -aes-256-cbc -d -md md5 -k "$final_key" 2>/dev/null | sed -nE "s_.*\"file\":\"([^\"]*)\".*_\1_p")
fi
subs=$(printf "%s" "$json_data" | tr "{|}" "\n" | sed -nE "s_\"file\":\"(.*\.vtt)\".*_\1_p" | sed 's/:/\\:/g' | tr "\n" ":" | sed 's/:$//')

[ -z "$video_link" ] && exit 1
[ -n "$subs" ] && mpv --sub-files="$subs" --force-media-title="$anime_name - Ep: $episode_number" "$video_link" && exit 0
mpv "$video_link" --force-media-title="$anime_name - Ep: $episode_number"
