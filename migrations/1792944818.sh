echo "Uninstall the Augment CLI (auggie), which bin/bootstrap no longer installs"

# The prefix bin/bootstrap and Fish give npm, for a run started elsewhere.
export npm_config_prefix="${npm_config_prefix:-$HOME/.node_modules}"
[[ -d $npm_config_prefix/lib/node_modules/@augmentcode/auggie ]] || exit 0
npm uninstall --global @augmentcode/auggie
