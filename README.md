# rollerblades
Distribution tool

Rollerblades can be used to download and publish git repo content as tar.gz archives.
These tar archives can be signed by rollerblades, so that clients can verify them against a distributed public key.

# setup
make a dir called 'cfg' and 'repos'
in 'cfg', make a file called 'repos.txt'. Add your repo names here.

in 'cfg', make a file called 'settings.txt'. Rollerblades will source this files and expect some vars to be set here.
You can reference variables used internally by rollerblades.sh, such as SCRIPT_DIR and CFG_DIR in settings.

'settings.txt' sample
```# How often repos are downloaded and deployed
SLEEP_TIME=5m

# Where to store archives
OUTPUT_DIR=/home/christer/www

# Optional content that will be inserted at the beginning of index.html in the output directory
MOTD=/home/christer/rollerblades_motd.txt

# Signing configuration
SIGNING=true
SIGNING_PRIVATE_KEY="$CFG_DIR/rollerblades.key"
SIGNING_PUBLIC_KEY="$CFG_DIR/rollerblades.pub"

# Git clone prefix/suffix
CLONE_PREFIX=git@github.com:chr1573r
CLONE_SUFFIX=.git
```
