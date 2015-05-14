//  AwfulHTMLRendering.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import HTMLReader;

/**
 * Modifies document in-place by adding the "mention" class to the header above a quote if it says "username posted:".
 */
extern void HighlightQuotesOfPostsByUserNamed(HTMLDocument *document, NSString *username);

/**
 * Modifies document in-place by:
     • Turning all non-smiley `<img src=>` elements into `<a data-awful='image'>src</a>` elements (if linkifyNonSmiles == true).
     • Adding .awful-smile to smile elements.
 */
extern void ProcessImgTags(HTMLDocument *document, BOOL linkifyNonSmiles);

/**
 * Modifies document in-place by deleting all elements with the `editedby` class that have no text content.
 */
extern void RemoveEmptyEditedByParagraphs(HTMLDocument *document);

/**
 * Modifies document in-place by removing the `style`, `onmouseover`, and `onmouseout` attributes from `bbc-spoiler` spans.
 */
extern void RemoveSpoilerStylingAndEvents(HTMLDocument *document);

/**
 * Modifies document in-place by replacing Flash-based Vimeo players with HTML5-based players.
 */
extern void UseHTML5VimeoPlayer(HTMLDocument *document);
