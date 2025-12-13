#!/bin/zsh

# ==================================================
# 1. INPUT FILE (from drag & drop)
# ==================================================
input="$1"

if [[ ! -f "$input" ]]; then
    osascript -e 'display alert "Error: No PDF received. Drag a PDF onto the app icon."'
    exit 1
fi

filename=$(basename "$input")
name="${filename%.*}"
suggested_name="${name}_compressed.pdf"

# ==================================================
# 2. COMPRESSION MENU
# ==================================================
level=$(osascript <<EOF
set choices to {"Very Light (300 DPI)", "Light (200 DPI)", "Medium (150 DPI)", "High (100 DPI)", "Extreme (72 DPI)", "Custom DPI"}
set userChoice to choose from list choices with title "Ghostscript Compression" with prompt "Choose compression level:" default items {"Medium (150 DPI)"}
return userChoice
EOF
)

if [[ "$level" == "false" ]]; then exit 1; fi

case "$level" in
    "Very Light (300 DPI)") dpi=300 ;;
    "Light (200 DPI)") dpi=200 ;;
    "Medium (150 DPI)") dpi=150 ;;
    "High (100 DPI)") dpi=100 ;;
    "Extreme (72 DPI)") dpi=72 ;;
    "Custom DPI")
        dpi=$(osascript <<EOF
set userInput to text returned of (display dialog "Enter DPI (72–300 recommended)" default answer "150")
return userInput
EOF
)
        ;;
esac

# ==================================================
# 3. SAVE-AS DIALOG
# ==================================================
output=$(osascript <<EOF
set outFile to choose file name with prompt "Save compressed PDF as:" default name "$suggested_name"
POSIX path of outFile
EOF
)

if [[ -z "$output" ]]; then exit 1; fi

outdir=$(dirname "$output")
outfile=$(basename "$output")

# ==================================================
# 4. SHOW PROGRESS WINDOW
# ==================================================
osascript <<EOF &
display dialog "Compressing… Please wait." buttons {} giving up after 120 with title "Ghostscript" with icon note
EOF
progress_pid=$!

# ==================================================
# 5. ORIGINAL SIZE
# ==================================================
orig_size=$(stat -f%z "$input")

# ==================================================
# 6. RUN GHOSTSCRIPT (NOW FULL PERMISSION)
# ==================================================
/opt/homebrew/bin/gs 	-sDEVICE=pdfwrite \
   					  	-dCompatibilityLevel=1.4 \
   						-dPDFSETTINGS=/default \
   						-dDownsampleColorImages=true \
   						-dColorImageResolution=$dpi \
   						-dDownsampleGrayImages=true \
   						-dGrayImageResolution=$dpi \
   						-dDownsampleMonoImages=true \
   						-dMonoImageResolution=$dpi \
   						-dNOPAUSE -dQUIET -dBATCH \
   						-sOutputFile="$output" \
   						"$input"

kill "$progress_pid" 2>/dev/null

# ==================================================
# 7. CHECK OUTPUT WORKED
# ==================================================
if [[ ! -f "$output" ]]; then
    osascript -e 'display alert "Compression failed. Ghostscript could not create the output file."'
    exit 1
fi

new_size=$(stat -f%z "$output")
percent=$(echo "scale=1; (1 - $new_size / $orig_size) * 100" | bc -l)
percent=$(printf "%.1f" "$percent")

# ==================================================
# 8. SUCCESS MESSAGE
# ==================================================
osascript <<EOF
display dialog "Compression complete!  
Original: $((orig_size/1024)) KB  
New: $((new_size/1024)) KB  
Reduced: $percent%" buttons {"OK"} with title "Done" with icon note
EOF