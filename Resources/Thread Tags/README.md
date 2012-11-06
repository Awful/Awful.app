Thread Tags
===========

Awful uses its own set of thread tags that look great on the iPhone and iPad. Our thread tag specialists are [Diabolik900][] and [The Dave][], who are happy to answer any questions.

We've got [quite a collection][thread tag folder], but there are always new tags appearing across the many forums and subforums. We'd love your help to keep on top of things.

## Specifications

Awful's thread tags are 90px by 90px PNG files. (They're "retina" images, so they'll be displayed on the iPhone or iPad at 45 points by 45 points.) Make sure to name the file the same as it's named on the Forums, but with `.png`. For example, the Apple tag is `shsc-apple.gif`, so call yours `shsc-apple.png`. Capitalization matters.

## Getting into the app

Please ask for help if you're uncomfortable with anything in this procedure. Thread tags make us so happy that we'll hold your hand as much as you like, or even just do it for you if you send us the images.

We can push new thread tags out to Awful users without pushing an update to the App Store. Awful checks this repository for new thread tags about once per day.

1. Add your new `.png` files to the Xcode project by dragging them into the `Resources/Thread Tags` group (alongside the other thread tags). Make sure to put a checkmark beside "Copy items into destination group's folder (if needed)".
2. Build the Xcode project. This will regenerate the list of tags that Awful checks daily.
3. Be a dear and run `rake sort_tags` from the Awful directory. It puts the tags in alphabetical order within the Xcode project.
4. Commit all your changes and new files then send a pull request.

[Diabolik900]: http://forums.somethingawful.com/member.php?action=getinfo&userid=113215
[The Dave]: http://forums.somethingawful.com/member.php?action=getinfo&userid=41741
[thread tag folder]: https://github.com/AwfulDevs/Awful/tree/master/Resources/Thread%20Tags
