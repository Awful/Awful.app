//  ComposeTextViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
@protocol AwfulComposeCustomView;
@protocol AwfulComposeTextViewControllerDelegate;

@interface ComposeTextViewController : AwfulViewController <UITextViewDelegate>

/**
 * The composition text view. Set its text or attributedText property as appropriate.
 */
@property (readonly, strong, nonatomic) UITextView *textView;

/**
 * The button that submits the composition when tapped. Set its title property.
 */
@property (readonly, strong, nonatomic) UIBarButtonItem *submitButtonItem;

/**
 * The button that cancels the composition when tapped. Set its title as appropriate.
 */
@property (readonly, strong, nonatomic) UIBarButtonItem *cancelButtonItem;

/**
 * Tells a reasonable responder to become first responder.
 */
- (void)focusInitialFirstResponder;

/**
 * Refreshes the submit button's enabled status.
 */
- (void)updateSubmitButtonItem;

/**
 * Returns YES when the submission is valid and ready, otherwise NO. The default is to return YES when the textView is nonempty.
 */
@property (readonly, assign, nonatomic) BOOL canSubmitComposition;

/**
 * Called just before submission, offering a chance to confirm whether the submission should continue. The default implementation immediately allows submission.
 *
 * @param handler A block to call after determining whether submission should continue, which takes as a parameter YES if submission should continue or NO otherwise.
 */
- (void)shouldSubmitHandler:(void(^)(BOOL ok))handler;

/**
 * Returns a description of the process of submission, such as "Posting…".
 */
@property (readonly, copy, nonatomic) NSString *submissionInProgressTitle;

/**
 * Do the actual work of submitting the composition. The default implementation raises an exception.
 *
 * @param composition       The composition with upload images having been replaced by appropriate textual equivalents.
 * @param completionHandler A block to call once submission is complete; the block takes a single parameter, either YES on success or NO if submission failed.
 */
- (void)submitComposition:(NSString *)composition completionHandler:(void(^)(BOOL success))completionHandler;

/**
 * Called when the cancel button is tapped and no submission is in progress. The default implementation simply informs the delegate; overridden implementations can do so directly or call super as desired.
 */
- (void)cancel;

/**
 * A view that perches atop the textView, housing additional fields like a "Subject" field or a thread tag picker.
 */
@property (strong, nonatomic) UIView <AwfulComposeCustomView> *customView;

@property (weak, nonatomic) id <AwfulComposeTextViewControllerDelegate> delegate;

@end

@protocol AwfulComposeCustomView <NSObject>

@property (assign, nonatomic) BOOL enabled;

/**
 * Returns a responder that should be the initial first responder when the AwfulComposeTextViewController first appears, instead of its textView. The default is nil, meaning the textView becomes first responder as usual.
 */
@property (readonly, strong, nonatomic) UIResponder *initialFirstResponder;

@end

@protocol AwfulComposeTextViewControllerDelegate <NSObject>

/**
 * Sent to the delegate when composition is either submitted or cancelled.
 *
 * @param success   YES if the submission was successful, otherwise NO.
 * @param keepDraft YES if the view controller should be kept around, otherwise NO.
 */
- (void)composeTextViewController:(ComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft;

@end
