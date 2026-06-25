function bin-chmod
    set -l bin_dir $HOME/.config/bin

    if not test -d $bin_dir
        echo "bin-chmod: $bin_dir not found" >&2
        return 1
    end

    for f in $bin_dir/*
        if test -f $f
            chmod +x $f
            echo "chmod +x $f"
        end
    end
end