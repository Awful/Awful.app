Customizing the Posts View in Awful
===================================

The posts view in Awful is styled using Cascading Style Sheets. You can tell
Awful to use your own stylesheet by placing .css files here. If you need any
help, come visit the thread:
http://forums.somethingawful.com/showthread.php?threadid=3510131

If you place a file called "default.css" in this folder, it gets used for every
thread in every forum you visit. It's added after our built-in defaults.css,
which you can find here:
https://github.com/AwfulDevs/Awful/blob/master/Resources/Posts%20View/default.css

And that's not all! You can tell Awful to use your stylesheet only in certain
forums. For example, notice that the URL for YOSPOS is:
http://forums.somethingawful.com/forumdisplay.php?forumid=219
If you place a file called "default-219.css" here, it will be used for all
threads in YOSPOS, but not for any other threads.

Finally, if "Dark mode" is enabled in Awful's settings, the files "dark.css" and
"dark-219.css" (for example) are used if you place them here.
