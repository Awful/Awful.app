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
