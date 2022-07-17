# rollerblades
Distribution tool

# setup
make a dir called 'cfg'
in 'cfg', make a file called 'repos.txt'. Add your repo names here.

in 'cfg', make a file called 'settings.txt'. Rollerblades will source this files and expect some vars to be set here.

'settings.txt' sample
```# How often repos are downloaded and deployed
SLEEP_TIME=5m

# Where to store archives
OUTPUT_DIR=/home/christer/www

# Git clone prefix/suffix
CLONE_PREFIX=git@github.com:chr1573r
CLONE_SUFFIX=.git
```
