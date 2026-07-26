# ============================================================
# ytdlp.fish — обгортка yt-dlp для завантаження mp3
# ============================================================
function ytdlp
    set -l link $argv[1]
    if test -z "$link"
        echo "No link provided"
        return 1
    end

    yt-dlp -f "ba" -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail \
    --download-archive "$HOME/yt-dlp/archive.txt" \
    -P "$HOME/yt-dlp/" \
    -o "%(artist)s - %(title)s.%(ext)s" \
    "$link"
end
