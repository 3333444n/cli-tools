#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage:"
    echo "  rembg path/to/image.jpg    # Process single image"
    echo "  rembg path/to/folder       # Process all images in folder"
    exit 1
fi

# Remove trailing slash if present
path="${1%/}"

# Check if it's a file
if [ -f "$path" ]; then
    dir=$(dirname "$path")
    filename=$(basename "$path")
    name="${filename%.*}"

    echo "Processing: $filename"
    docker run --platform linux/amd64 --rm -v "$dir:/data" danielgatis/rembg i "/data/$filename" "/data/nobg-${name}.png"
    echo "Done! Saved as: $dir/nobg-${name}.png"

# Check if it's a directory
elif [ -d "$path" ]; then
    echo "Processing images in: $path"
    echo "---"

    count=0
    for img in "$path"/*.{jpg,jpeg,png,JPG,JPEG,PNG,webp,WEBP}; do
        [ -f "$img" ] || continue
        filename=$(basename "$img")
        name="${filename%.*}"

        echo "Processing: $filename"
        docker run --platform linux/amd64 --rm -v "$path:/data" danielgatis/rembg i "/data/$filename" "/data/nobg-${name}.png"
        ((count++))
    done

    echo "---"
    echo "Done! Processed $count images in $path"
else
    echo "Error: '$path' is not a valid file or directory"
    exit 1
fi
