#import "PageListTableViewCell.h"
#import "WPStyleGuide+Posts.h"
#import "WordPress-Swift.h"

@import Gridicons;


static CGFloat const PageListTableViewCellTagLabelRadius = 2.0;
static CGFloat const FeaturedImageSize = 120.0;

@interface PageListTableViewCell()

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;
@property (nonatomic, strong) IBOutlet UILabel *badgesLabel;
@property (strong, nonatomic) IBOutlet CachedAnimatedImageView *featuredImageView;
@property (nonatomic, strong) IBOutlet UIButton *menuButton;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *labelsContainerTrailing;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *leadingContentConstraint;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation PageListTableViewCell {
    CGFloat _indentationWidth;
    NSInteger _indentationLevel;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [self applyStyles];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self applyStyles];
    [self setNeedsDisplay];
}

- (NSDateFormatter *)dateFormatter
{
    if (_dateFormatter == nil) {
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.doesRelativeDateFormatting = YES;
        _dateFormatter.dateStyle = NSDateFormatterNoStyle;
        _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    return _dateFormatter;
}

- (CGFloat)indentationWidth
{
    return _indentationWidth;
}

- (NSInteger)indentationLevel
{
    return _indentationLevel;
}

- (void)setIndentationWidth:(CGFloat)indentationWidth
{
    _indentationWidth = indentationWidth;
    [self updateLeadingContentConstraint];
}

- (void)setIndentationLevel:(NSInteger)indentationLevel
{
    _indentationLevel = indentationLevel;
    [self updateLeadingContentConstraint];
}


#pragma mark - Accessors

- (void)setPost:(AbstractPost *)post
{
    [super setPost:post];
    [self configureTitle];
    [self configureForStatus];
    [self configureBadges];
    [self configureTimeStamp];
    [self configureFeaturedImage];
}

#pragma mark - Configuration

- (void)applyStyles
{
    [WPStyleGuide configureTableViewCell:self];
    [WPStyleGuide configureLabel:self.timestampLabel textStyle:UIFontTextStyleSubheadline];
    [WPStyleGuide configureLabel:self.badgesLabel textStyle:UIFontTextStyleSubheadline];

    self.titleLabel.font = [WPStyleGuide notoBoldFontForTextStyle:UIFontTextStyleHeadline];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    
    self.titleLabel.textColor = [WPStyleGuide darkGrey];
    self.timestampLabel.textColor = [WPStyleGuide grey];
    self.badgesLabel.textColor = [WPStyleGuide darkYellow];
    self.menuButton.tintColor = [WPStyleGuide greyLighten10];
    [self.menuButton setImage:[Gridicon iconOfType:GridiconTypeEllipsis] forState:UIControlStateNormal];

    self.backgroundColor = [WPStyleGuide greyLighten30];
    self.contentView.backgroundColor = [WPStyleGuide greyLighten30];
    
    self.featuredImageView.layer.cornerRadius = PageListTableViewCellTagLabelRadius;
}

- (void)configureTitle
{
    AbstractPost *post = [self.post hasRevision] ? [self.post revision] : self.post;
    self.titleLabel.text = [post titleForDisplay] ?: [NSString string];
}

- (void)configureForStatus
{
    if (self.post.isFailed && !self.post.hasLocalChanges) {
        self.titleLabel.textColor = [WPStyleGuide errorRed];
        self.menuButton.tintColor = [WPStyleGuide errorRed];
    }
}

- (void)updateLeadingContentConstraint
{
    self.leadingContentConstraint.constant = (CGFloat)_indentationLevel * _indentationWidth;
}

- (void)configureBadges
{
    Page *page = (Page *)self.post;

    NSString *badgesString = @"";
    
    if (page.hasPrivateState) {
        badgesString = NSLocalizedString(@"Private", @"Title of the Private Badge");
    } else if (page.hasPendingReviewState) {
        badgesString = NSLocalizedString(@"Pending review", @"Title of the Pending Review Badge");
    }
    
    if (page.hasLocalChanges) {
        if (badgesString.length > 0) {
            badgesString = [badgesString stringByAppendingString:@" · "];
        }
        badgesString = [badgesString stringByAppendingString:NSLocalizedString(@"Local changes", @"Title of the Local Changes Badge")];
    }
    
    self.badgesLabel.text = badgesString;
}

- (void)configureTimeStamp
{
    self.timestampLabel.text = [self.post isScheduled] ? [self.dateFormatter stringFromDate:self.post.dateCreated] : [self.post.dateCreated mediumString];
}

- (void)configureFeaturedImage
{
    Page *page = (Page *)self.post;
    
    BOOL hideFeaturedImage = page.featuredImage == nil;
    self.featuredImageView.hidden = hideFeaturedImage;
    self.labelsContainerTrailing.active = !hideFeaturedImage;
    
    if (!hideFeaturedImage) {
        [self.featuredImageView startLoadingAnimation];

        __weak __typeof(self) weakSelf = self;

        [page.featuredImage imageWithSize:CGSizeMake(FeaturedImageSize, FeaturedImageSize)
                        completionHandler:^(UIImage * _Nullable result, NSError * _Nullable error) {
                            __strong __typeof(weakSelf) strongSelf = weakSelf;
                            [strongSelf.featuredImageView stopLoadingAnimation];
                            
                            if (error == nil) {
                                [strongSelf.featuredImageView setImage:result];
                            }
                        }];
        
    }
}

@end
