// Toggle spoilers on tap.
$(function() {
  $('body').on('click', '.bbc-spoiler', function(event) {
    var target = $(event.target);
    var spoiler = target.closest('.bbc-spoiler');
    var isLink = target.closest('a, [data-awful-linkified-image]').length > 0;
    var isSpoiled = spoiler.hasClass('spoiled');
    if (!(isLink && isSpoiled)) {
      spoiler.toggleClass('spoiled');
    }
    if (isLink && !isSpoiled) {
      event.preventDefault();
    }
  });
});

// CGRectFromString-formatted bounding rect of an element, for passing back to Objective-C.
function rectOfElement(element) {
  var rect = $(element).offset();
  var origin = [rect.left - window.pageXOffset, rect.top - window.pageYOffset].join(",");
  var size = [rect.width, rect.height].join(",");
  return "{{" + origin + "},{" + size + "}}";
}
