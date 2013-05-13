//
//  CreateAccountAndBlogViewController.m
//  WordPress
//
//  Created by Sendhil Panchadsaram on 5/7/13.
//  Copyright (c) 2013 WordPress. All rights reserved.
//

#import "CreateAccountAndBlogViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "HelpViewController.h"
#import "WordPressComApi.h"
#import "UIView+FormSheetHelpers.h"
#import "WPNUXPrimaryButton.h"
#import "WPWalkthroughTextField.h"
#import "WPAsyncBlockOperation.h"
#import "WPComLanguages.h"
#import "WPWalkthroughGrayOverlayView.h"
#import "SelectWPComLanguageViewController.h"
#import "WPNUXUtility.h"

@interface CreateAccountAndBlogViewController ()<
    UIScrollViewDelegate,
    UITextFieldDelegate,
    UIGestureRecognizerDelegate> {
    UIScrollView *_scrollView;
    
    // Page 1
    UIButton *_cancelButton;
    UIButton *_helpButton;
    UIImageView *_page1Icon;
    UILabel *_page1Title;
    UITextField *_page1EmailText;
    UITextField *_page1UsernameText;
    UITextField *_page1PasswordText;
    WPNUXPrimaryButton *_page1NextButton;
    
    // Page 2
    UIImageView *_page2Icon;
    UILabel *_page2Title;
    UITextField *_page2SiteTitleText;
    UITextField *_page2SiteAddressText;
    UITextField *_page2SiteLanguageText;
    UIImageView *_page2SiteLanguageDropdownImage;
    WPNUXPrimaryButton *_page2NextButton;
    WPNUXPrimaryButton *_page2PreviousButton;
    
    // Page 3
    UIImageView *_page3Icon;
    UILabel *_page3Title;
    UILabel *_page3EmailLabel;
    UILabel *_page3UsernameLabel;
    UILabel *_page3SiteTitleLabel;
    UILabel *_page3SiteAddressLabel;
    UILabel *_page3SiteLanguageLabel;
    WPNUXPrimaryButton *_page3NextButton;
    WPNUXPrimaryButton *_page3PreviousButton;
    UIImageView *_page3FirstLineSeparator;
    UIImageView *_page3SecondLineSeparator;
    UIImageView *_page3ThirdLineSeparator;
    UIImageView *_page3FourthLineSeparator;
    UIImageView *_page3FifthLineSeparator;
    UIImageView *_page3SixthLineSeparator;
    
    NSOperationQueue *_operationQueue;
    
    // This is so if the user pages back and forth we aren't validating each time
    BOOL _page1FieldsValid;
    BOOL _page2FieldsValid;

    BOOL _hasViewAppeared;
    BOOL _keyboardVisible;
    BOOL _savedOriginalPositionsOfStickyControls;
    CGFloat _infoButtonOriginalX;
    CGFloat _cancelButtonOriginalX;
    CGFloat _keyboardOffset;
    
    NSUInteger _currentPage;
    
    UIColor *_confirmationLabelColor;
    
    CGFloat _viewWidth;
    CGFloat _viewHeight;
    
    NSDictionary *_currentLanguage;
}

@end

@implementation CreateAccountAndBlogViewController

CGFloat const CreateAccountAndBlogStandardOffset = 16.0;
CGFloat const CreateAccountAndBlogIconVerticalOffset = 70.0;
CGFloat const CreateAccountAndBlogMaxTextWidth = 289.0;
CGFloat const CreateAccountAndBlogTextFieldWidth = 289.0;
CGFloat const CreateAccountAndBlogTextFieldHeight = 40.0;
CGFloat const CreateAccountAndBlogKeyboardOffset = 132.0;


- (id)init
{
    self = [super init];
    if (self) {
        _confirmationLabelColor = [UIColor colorWithRed:188.0/255.0 green:221.0/255.0 blue:236.0/255.0 alpha:1.0];
        _currentPage = 1;
        _operationQueue = [[NSOperationQueue alloc] init];
        _currentLanguage = [WPComLanguages currentLanguage];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _viewWidth = [self.view formSheetViewWidth];
    _viewHeight = [self.view formSheetViewHeight];
    self.view.backgroundColor = [UIColor colorWithRed:30.0/255.0 green:140.0/255.0 blue:190.0/255.0 alpha:1.0];
        
    [self addScrollview];
    [self addPage1Controls];
    [self addPage2Controls];
    [self addPage3Controls];
    [self equalizePreviousAndNextButtonWidths];
    [self layoutPage1Controls];
    [self layoutPage2Controls];
    [self layoutPage3Controls];
    [self equalizePreviousAndNextButtonWidths];
    
    if (!IS_IPAD) {
        // We don't need to shift the controls up on the iPad as there's enough space.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide) name:UIKeyboardDidHideNotification object:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self layoutScrollview];
    [self layoutPage1Controls];
    [self layoutPage2Controls];
    [self layoutPage3Controls];
    [self savePositionsOfStickyControls];
    
    if (_hasViewAppeared) {
        // This is for the case when the user pulls up the select language view on page 2 and returns to this view. When that
        // happens the sticky controls on the top won't be in the correct place, so in order to set them up we
        // 'page' to the current content offset in the _scrollView to ensure that the cancel button and help button
        // are in the correct place6
        [self moveStickyControlsForContentOffset:CGPointMake(_scrollView.contentOffset.x, 0)];
    }
    
    _hasViewAppeared = true;
}

- (NSUInteger)supportedInterfaceOrientations {
    if (IS_IPHONE)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - UITextField Delegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _page1EmailText) {
        [_page1UsernameText becomeFirstResponder];
    } else if (textField == _page1UsernameText) {
        [_page1PasswordText becomeFirstResponder];
    } else if (textField == _page1PasswordText) {
        if (_page1NextButton.enabled) {
            [self clickedPage1NextButton];            
        }
    } else if (textField == _page2SiteTitleText) {
        [_page2SiteAddressText becomeFirstResponder];
    } else if (textField == _page2SiteAddressText) {
        if (_page2NextButton.enabled) {
            [self clickedPage2NextButton];
        }
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSArray *page1Fields = @[_page1EmailText, _page1UsernameText, _page1PasswordText];
    NSArray *page2Fields = @[_page2SiteTitleText, _page2SiteAddressText];
    
    NSMutableString *updatedString = [[NSMutableString alloc] initWithString:textField.text];
    [updatedString replaceCharactersInRange:range withString:string];

    if ([page1Fields containsObject:textField]) {
        _page1FieldsValid = false;
        [self updatePage1ButtonEnabledStatusFor:textField andUpdatedString:updatedString];
    } else if ([page2Fields containsObject:textField]) {
        _page2FieldsValid = false;
        [self updatePage2ButtonEnabledStatusFor:textField andUpdatedString:updatedString];
    }
    
    return YES;
}

- (void)updatePage1ButtonEnabledStatusFor:(UITextField *)textField andUpdatedString:(NSString *)updatedString
{
    BOOL isEmailFilled = [self isEmailedFilled];
    BOOL isUsernameFilled = [self isUsernameFilled];
    BOOL isPasswordFilled = [self isPasswordFilled];
    BOOL updatedStringHasContent = [[updatedString trim] length] != 0;
    
    if (textField == _page1EmailText) {
        isEmailFilled = updatedStringHasContent;
    } else if (textField == _page1UsernameText) {
        isUsernameFilled = updatedStringHasContent;
    } else if (textField == _page1PasswordText) {
        isPasswordFilled = updatedStringHasContent;
    }
    
    _page1NextButton.enabled = isEmailFilled && isUsernameFilled && isPasswordFilled;
}

- (void)updatePage2ButtonEnabledStatusFor:(UITextField *)textField andUpdatedString:(NSString *)updatedString
{
    BOOL isSiteTitleFilled = [self isSiteTitleFilled];
    BOOL isSiteAddressFilled = [self isSiteAddressFilled];
    BOOL updatedStringHasContent = [[updatedString trim] length] != 0;
    
    if (textField == _page2SiteTitleText) {
        isSiteTitleFilled = updatedStringHasContent;
    } else if (textField == _page2SiteAddressText) {
        isSiteAddressFilled = updatedStringHasContent;
    }
    
    _page2NextButton.enabled = isSiteTitleFilled && isSiteAddressFilled;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    _page1NextButton.enabled = [self page1FieldsFilled];
    _page2NextButton.enabled = [self page2FieldsFilled];
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    _page1NextButton.enabled = [self page1FieldsFilled];
    _page2NextButton.enabled = [self page2FieldsFilled];
    return YES;
}

#pragma mark - UIScrollView Delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSUInteger pageViewed = ceil(scrollView.contentOffset.x/_viewWidth) + 1;
    [self flagPageViewed:pageViewed];
    [self moveStickyControlsForContentOffset:scrollView.contentOffset];
}

#pragma mark - Private Methods

- (void)addScrollview
{
    _scrollView = [[UIScrollView alloc] init];
    CGSize scrollViewSize = _scrollView.contentSize;
    scrollViewSize.width = _viewWidth * 3;
    _scrollView.scrollEnabled = NO;
    _scrollView.frame = self.view.bounds;
    _scrollView.contentSize = scrollViewSize;
    _scrollView.pagingEnabled = true;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.pagingEnabled = YES;
    [self.view addSubview:_scrollView];
    _scrollView.delegate = self;
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickedOnScrollView:)];
    gestureRecognizer.numberOfTapsRequired = 1;
    gestureRecognizer.cancelsTouchesInView = NO;
    [_scrollView addGestureRecognizer:gestureRecognizer];
}

- (void)layoutScrollview
{
    _scrollView.frame = self.view.bounds;
}

- (void)addPage1Controls
{
    // Add Help Button
    UIImage *helpButtonImage = [UIImage imageNamed:@"btn-help"];
    UIImage *helpButtonImageHighlighted = [UIImage imageNamed:@"btn-help-tap"];
    if (_helpButton == nil) {
        _helpButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_helpButton setImage:helpButtonImage forState:UIControlStateNormal];
        [_helpButton setImage:helpButtonImageHighlighted forState:UIControlStateHighlighted];
        _helpButton.frame = CGRectMake(CreateAccountAndBlogStandardOffset, CreateAccountAndBlogStandardOffset, helpButtonImage.size.width, helpButtonImage.size.height);
        [_helpButton addTarget:self action:@selector(clickedInfoButton) forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:_helpButton];
    }
    
    // Add Cancel Button
    if (_cancelButton == nil) {
        UIImage *mainImage = [[UIImage imageNamed:@"btn-back"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 4)];
        UIImage *tappedImage = [[UIImage imageNamed:@"btn-back-tap"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 4)];
        _cancelButton = [[UIButton alloc] init];
        _cancelButton.titleLabel.font = [UIFont fontWithName:@"OpenSans" size:12.0];
        [_cancelButton setTitleEdgeInsets:UIEdgeInsetsMake(-1.0, 12.0, 0, 10.0)];
        [_cancelButton setTitleColor:[UIColor colorWithRed:22.0/255.0 green:160.0/255.0 blue:208.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        [_cancelButton setTitleColor:[UIColor colorWithRed:17.0/255.0 green:134.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateHighlighted];
        [_cancelButton setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
        [_cancelButton setBackgroundImage:mainImage forState:UIControlStateNormal];
        [_cancelButton setBackgroundImage:tappedImage forState:UIControlStateHighlighted];
        [_cancelButton addTarget:self action:@selector(clickedCancelButton) forControlEvents:UIControlEventTouchUpInside];
        [_cancelButton sizeToFit];
        _cancelButton.frame = CGRectMake(0, 0, CGRectGetWidth(_cancelButton.frame)+_cancelButton.titleEdgeInsets.left+_cancelButton.titleEdgeInsets.right, CGRectGetHeight(_cancelButton.frame));
        [_scrollView addSubview:_cancelButton];
    }
    
    // Add Icon
    if (_page1Icon == nil) {
        UIImage *icon = [UIImage imageNamed:@"icon-wp"];
        _page1Icon = [[UIImageView alloc] initWithImage:icon];
        [_scrollView addSubview:_page1Icon];
    }
    
    // Add Title
    if (_page1Title == nil) {
        _page1Title = [[UILabel alloc] init];
        _page1Title.textAlignment = UITextAlignmentCenter;
        _page1Title.text = NSLocalizedString(@"NUX_Create_Account_Page1_Title", nil);
        _page1Title.numberOfLines = 0;
        _page1Title.backgroundColor = [UIColor clearColor];
        _page1Title.font = [WPNUXUtility titleFont];
        _page1Title.shadowColor = [WPNUXUtility textShadowColor];
        _page1Title.shadowOffset = CGSizeMake(0.0, 1.0);
        _page1Title.textColor = [UIColor whiteColor];
        _page1Title.lineBreakMode = UILineBreakModeWordWrap;
        [_scrollView addSubview:_page1Title];
    }
    
    // Add Email
    if (_page1EmailText == nil) {
        _page1EmailText = [[WPWalkthroughTextField alloc] init];
        _page1EmailText.backgroundColor = [UIColor whiteColor];
        _page1EmailText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page1_Email_Placeholder", nil);
        _page1EmailText.font = [WPNUXUtility textFieldFont];
        _page1EmailText.adjustsFontSizeToFitWidth = true;
        _page1EmailText.delegate = self;
        _page1EmailText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page1EmailText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_scrollView addSubview:_page1EmailText];
    }
    
    // Add Username
    if (_page1UsernameText == nil) {
        _page1UsernameText = [[WPWalkthroughTextField alloc] init];
        _page1UsernameText.backgroundColor = [UIColor whiteColor];
        _page1UsernameText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page1_Username_Placeholder", nil);
        _page1UsernameText.font = [WPNUXUtility textFieldFont];
        _page1UsernameText.adjustsFontSizeToFitWidth = true;
        _page1UsernameText.delegate = self;
        _page1UsernameText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page1UsernameText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_scrollView addSubview:_page1UsernameText];
    }
    
    // Add Password
    if (_page1PasswordText == nil) {
        _page1PasswordText = [[WPWalkthroughTextField alloc] init];
        _page1PasswordText.secureTextEntry = true;
        _page1PasswordText.backgroundColor = [UIColor whiteColor];
        _page1PasswordText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page1_Password_Placeholder", nil);
        _page1PasswordText.font = [WPNUXUtility textFieldFont];
        _page1PasswordText.adjustsFontSizeToFitWidth = true;
        _page1PasswordText.delegate = self;
        _page1PasswordText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page1PasswordText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_scrollView addSubview:_page1PasswordText];
    }
    
    // Add Next Button
    if (_page1NextButton == nil) {
        _page1NextButton = [[WPNUXPrimaryButton alloc] init];
        [_page1NextButton setTitle:NSLocalizedString(@"Next", nil) forState:UIControlStateNormal];
        _page1NextButton.enabled = false;
        [_page1NextButton addTarget:self action:@selector(clickedPage1NextButton) forControlEvents:UIControlEventTouchUpInside];
        [_page1NextButton sizeToFit];
        [_scrollView addSubview:_page1NextButton];
    }
}

- (void)layoutPage1Controls
{
    CGFloat x,y;
    CGFloat currentPage=1;
    
    // Layout Help Button
    UIImage *helpButtonImage = [UIImage imageNamed:@"btn-help"];
    x = _viewWidth - CreateAccountAndBlogStandardOffset - helpButtonImage.size.width;
    y = CreateAccountAndBlogStandardOffset;
    _helpButton.frame = CGRectMake(x, y, helpButtonImage.size.width, helpButtonImage.size.height);
    
    // Layout Cancel Button
    x = CreateAccountAndBlogStandardOffset;
    y = CreateAccountAndBlogStandardOffset;
    _cancelButton.frame = CGRectMake(x, y, CGRectGetWidth(_cancelButton.frame), CGRectGetHeight(_cancelButton.frame));
        
    // Layout the controls starting out from y of 0, then offset them once the height of the controls
    // is accurately calculated we can determine the vertical center and adjust everything accordingly.
    
    // Layout Icon
    x = (_viewWidth - CGRectGetWidth(_page1Icon.frame))/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = 0;
    _page1Icon.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page1Icon.frame), CGRectGetHeight(_page1Icon.frame)));
    
    // Layout Title
    CGSize titleSize = [_page1Title.text sizeWithFont:_page1Title.font constrainedToSize:CGSizeMake(CreateAccountAndBlogMaxTextWidth, CGFLOAT_MAX) lineBreakMode:UILineBreakModeWordWrap];
    x = (_viewWidth - titleSize.width)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page1Icon.frame) + CreateAccountAndBlogStandardOffset;
    _page1Title.frame = CGRectIntegral(CGRectMake(x, y, titleSize.width, titleSize.height));
    
    // Layout Email
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page1Title.frame) + CreateAccountAndBlogStandardOffset;
    _page1EmailText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));

    // Layout Username
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page1EmailText.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page1UsernameText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));

    // Layout Password
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page1UsernameText.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page1PasswordText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));
    
    // Layout Next Button
    x = (_viewWidth - CGRectGetWidth(_page1NextButton.frame))/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page1PasswordText.frame) + CreateAccountAndBlogStandardOffset;
    _page1NextButton.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page1NextButton.frame), CGRectGetHeight(_page1NextButton.frame)));
    
    NSArray *controls = @[_page1Icon, _page1Title, _page1EmailText, _page1UsernameText, _page1PasswordText, _page1NextButton];
    [WPNUXUtility centerViews:controls withStartingView:_page1Icon andEndingView:_page1NextButton forHeight:_viewHeight];
}

- (void)addPage2Controls
{
    // Add Icon
    if (_page2Icon == nil) {
        UIImage *icon = [UIImage imageNamed:@"icon-wp"];
        _page2Icon = [[UIImageView alloc] initWithImage:icon];
        [_scrollView addSubview:_page2Icon];
    }
    
    // Add Title
    if (_page2Title == nil) {
        _page2Title = [[UILabel alloc] init];
        _page2Title.textAlignment = UITextAlignmentCenter;
        _page2Title.text = NSLocalizedString(@"NUX_Create_Account_Page2_Site_Title_Placeholder", nil);
        _page2Title.numberOfLines = 0;
        _page2Title.backgroundColor = [UIColor clearColor];
        _page2Title.font = [WPNUXUtility titleFont];
        _page2Title.shadowColor = [WPNUXUtility textShadowColor];
        _page2Title.shadowOffset = CGSizeMake(0.0, 1.0);
        _page2Title.textColor = [UIColor whiteColor];
        _page2Title.lineBreakMode = UILineBreakModeWordWrap;
        [_scrollView addSubview:_page2Title];
    }
    
    // Add Site Title
    if (_page2SiteTitleText == nil) {
        _page2SiteTitleText = [[WPWalkthroughTextField alloc] init];
        _page2SiteTitleText.backgroundColor = [UIColor whiteColor];
        _page2SiteTitleText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page2_Site_Title_Placeholder", nil);
        _page2SiteTitleText.font = [WPNUXUtility textFieldFont];
        _page2SiteTitleText.adjustsFontSizeToFitWidth = true;
        _page2SiteTitleText.delegate = self;
        _page2SiteTitleText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page2SiteTitleText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_scrollView addSubview:_page2SiteTitleText];
    }
    
    // Add Site Address
    if (_page2SiteAddressText == nil) {
        _page2SiteAddressText = [[WPWalkthroughTextField alloc] init];
        _page2SiteAddressText.backgroundColor = [UIColor whiteColor];
        _page2SiteAddressText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page2_Site_Address_Placeholder", nil);
        _page2SiteAddressText.font = [WPNUXUtility textFieldFont];
        _page2SiteAddressText.adjustsFontSizeToFitWidth = true;
        _page2SiteAddressText.delegate = self;
        _page2SiteAddressText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page2SiteAddressText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_scrollView addSubview:_page2SiteAddressText];
    }
    
    // Add Site Language
    if (_page2SiteLanguageText == nil) {
        _page2SiteLanguageText = [[WPWalkthroughTextField alloc] init];
        _page2SiteLanguageText.backgroundColor = [UIColor whiteColor];
        _page2SiteLanguageText.placeholder = NSLocalizedString(@"NUX_Create_Account_Page2_Site_Language_Placeholder", nil);
        _page2SiteLanguageText.font = [WPNUXUtility textFieldFont];
        _page2SiteLanguageText.adjustsFontSizeToFitWidth = true;
        _page2SiteLanguageText.delegate = self;
        _page2SiteLanguageText.autocorrectionType = UITextAutocorrectionTypeNo;
        _page2SiteLanguageText.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _page2SiteLanguageText.enabled = NO;
        _page2SiteLanguageText.text = [_currentLanguage objectForKey:@"name"];
        [_scrollView addSubview:_page2SiteLanguageText];
    }
    
    if (_page2SiteLanguageDropdownImage == nil) {
        UIImage *dropDownImage = [UIImage imageNamed:@"textDropdownIcon"];
        _page2SiteLanguageDropdownImage = [[UIImageView alloc] initWithImage:dropDownImage];
        [_scrollView addSubview:_page2SiteLanguageDropdownImage];
    }
    
    // Add Next Button
    if (_page2NextButton == nil) {
        _page2NextButton = [[WPNUXPrimaryButton alloc] init];
        [_page2NextButton setTitle:NSLocalizedString(@"Next", nil) forState:UIControlStateNormal];
        [_page2NextButton addTarget:self action:@selector(clickedPage2NextButton) forControlEvents:UIControlEventTouchUpInside];
        [_page2NextButton sizeToFit];
        [_scrollView addSubview:_page2NextButton];
    }

    // Add Previous Button
    if (_page2PreviousButton == nil) {
        _page2PreviousButton = [[WPNUXPrimaryButton alloc] init];
        [_page2PreviousButton setTitle:NSLocalizedString(@"Previous", nil) forState:UIControlStateNormal];
        [_page2PreviousButton addTarget:self action:@selector(clickedPage2PreviousButton) forControlEvents:UIControlEventTouchUpInside];
        [_page2PreviousButton sizeToFit];
        [_scrollView addSubview:_page2PreviousButton];
    }
}

- (void)layoutPage2Controls
{
    CGFloat x,y;
    CGFloat currentPage=2;
    
    // Layout the controls starting out from y of 0, then offset them once the height of the controls
    // is accurately calculated we can determine the vertical center and adjust everything accordingly.

    // Layout Icon
    x = (_viewWidth - CGRectGetWidth(_page2Icon.frame))/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = 0;
    _page2Icon.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page2Icon.frame), CGRectGetHeight(_page2Icon.frame)));
    
    // Layout Title
    CGSize titleSize = [_page2Title.text sizeWithFont:_page2Title.font constrainedToSize:CGSizeMake(CreateAccountAndBlogMaxTextWidth, CGFLOAT_MAX) lineBreakMode:UILineBreakModeWordWrap];
    x = (_viewWidth - titleSize.width)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page2Icon.frame) + CreateAccountAndBlogStandardOffset;
    _page2Title.frame = CGRectIntegral(CGRectMake(x, y, titleSize.width, titleSize.height));
    
    // Layout Site Title
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page2Title.frame) + CreateAccountAndBlogStandardOffset;
    _page2SiteTitleText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));
    
    // Layout Site Address
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page2SiteTitleText.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page2SiteAddressText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));

    // Layout Site Language
    x = (_viewWidth - CreateAccountAndBlogTextFieldWidth)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page2SiteAddressText.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page2SiteLanguageText.frame = CGRectIntegral(CGRectMake(x, y, CreateAccountAndBlogTextFieldWidth, CreateAccountAndBlogTextFieldHeight));
    
    // Layout Dropdown Image
    x = CGRectGetMaxX(_page2SiteLanguageText.frame) - CGRectGetWidth(_page2SiteLanguageDropdownImage.frame) - CreateAccountAndBlogStandardOffset;
    y = CGRectGetMinY(_page2SiteLanguageText.frame) + (CGRectGetHeight(_page2SiteLanguageText.frame) - CGRectGetHeight(_page2SiteLanguageDropdownImage.frame))/2.0;
    _page2SiteLanguageDropdownImage.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page2SiteLanguageDropdownImage.frame), CGRectGetHeight(_page2SiteLanguageDropdownImage.frame)));
    
    // Layout Previous Button
    x = (_viewWidth - CGRectGetWidth(_page2PreviousButton.frame) - CGRectGetWidth(_page2NextButton.frame) - CreateAccountAndBlogStandardOffset)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page2SiteLanguageText.frame) + CreateAccountAndBlogStandardOffset;
    _page2PreviousButton.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page2PreviousButton.frame), CGRectGetHeight(_page2PreviousButton.frame)));
    
    // Layout Next Button
    x = CGRectGetMaxX(_page2PreviousButton.frame) + CreateAccountAndBlogStandardOffset;
    y = CGRectGetMaxY(_page2SiteLanguageText.frame) + CreateAccountAndBlogStandardOffset;
    _page2NextButton.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page2NextButton.frame), CGRectGetHeight(_page2NextButton.frame)));
    
    NSArray *controls = @[_page2Icon, _page2Title, _page2SiteTitleText, _page2SiteAddressText, _page2SiteLanguageText, _page2SiteLanguageDropdownImage, _page2PreviousButton, _page2NextButton];
    [WPNUXUtility centerViews:controls withStartingView:_page2Icon andEndingView:_page2NextButton forHeight:_viewHeight];
}

- (void)addPage3Controls
{
    // Add Icon
    if (_page3Icon == nil) {
        UIImage *icon = [UIImage imageNamed:@"icon-wp"];
        _page3Icon = [[UIImageView alloc] initWithImage:icon];
        [_scrollView addSubview:_page3Icon];
    }
    
    // Add Title
    if (_page3Title == nil) {
        _page3Title = [[UILabel alloc] init];
        _page3Title.textAlignment = UITextAlignmentCenter;
        _page3Title.text = NSLocalizedString(@"NUX_Create_Account_Page3_Title", nil);
        _page3Title.numberOfLines = 0;
        _page3Title.backgroundColor = [UIColor clearColor];
        _page3Title.font = [WPNUXUtility titleFont];
        _page3Title.shadowColor = [WPNUXUtility textShadowColor];
        _page3Title.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3Title.textColor = [UIColor whiteColor];
        _page3Title.lineBreakMode = UILineBreakModeWordWrap;
        [_scrollView addSubview:_page3Title];
    }

    // Add First Line Separator
    if (_page3FirstLineSeparator == nil) {
        _page3FirstLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3FirstLineSeparator];
    }

    // Add Email Label
    if (_page3EmailLabel == nil) {
        _page3EmailLabel = [[UILabel alloc] init];
        _page3EmailLabel.textAlignment = UITextAlignmentCenter;
        _page3EmailLabel.text = @"Email: ";
        _page3EmailLabel.numberOfLines = 1;
        _page3EmailLabel.backgroundColor = [UIColor clearColor];
        _page3EmailLabel.font = [UIFont fontWithName:@"OpenSans" size:14];
        _page3EmailLabel.shadowColor = [WPNUXUtility textShadowColor];
        _page3EmailLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3EmailLabel.textColor = _confirmationLabelColor;
        _page3EmailLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [_scrollView addSubview:_page3EmailLabel];
    }

    // Add Second Line Separator
    if (_page3SecondLineSeparator == nil) {
        _page3SecondLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3SecondLineSeparator];
    }

    // Add Username
    if (_page3UsernameLabel == nil) {
        _page3UsernameLabel = [[UILabel alloc] init];
        _page3UsernameLabel.textAlignment = UITextAlignmentCenter;
        _page3UsernameLabel.text = @"Username: ";
        _page3UsernameLabel.numberOfLines = 1;
        _page3UsernameLabel.backgroundColor = [UIColor clearColor];
        _page3UsernameLabel.font = [UIFont fontWithName:@"OpenSans" size:14];
        _page3UsernameLabel.shadowColor = [WPNUXUtility textShadowColor];
        _page3UsernameLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3UsernameLabel.textColor = _confirmationLabelColor;
        _page3UsernameLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [_scrollView addSubview:_page3UsernameLabel];
    }

    // Add Third Line Separator
    if (_page3ThirdLineSeparator == nil) {
        _page3ThirdLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3ThirdLineSeparator];
    }

    if (_page3SiteTitleLabel == nil) {
        _page3SiteTitleLabel = [[UILabel alloc] init];
        _page3SiteTitleLabel.textAlignment = UITextAlignmentCenter;
        _page3SiteTitleLabel.text = @"Site Title: ";
        _page3SiteTitleLabel.numberOfLines = 1;
        _page3SiteTitleLabel.backgroundColor = [UIColor clearColor];
        _page3SiteTitleLabel.font = [UIFont fontWithName:@"OpenSans" size:14];
        _page3SiteTitleLabel.shadowColor = [WPNUXUtility textShadowColor];
        _page3SiteTitleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3SiteTitleLabel.textColor = _confirmationLabelColor;
        _page3SiteTitleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [_scrollView addSubview:_page3SiteTitleLabel];
    }

    if (_page3FourthLineSeparator == nil) {
        _page3FourthLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3FourthLineSeparator];
    }

    if (_page3SiteAddressLabel == nil) {
        _page3SiteAddressLabel = [[UILabel alloc] init];
        _page3SiteAddressLabel.textAlignment = UITextAlignmentCenter;
        _page3SiteAddressLabel.text = @"Site Address: ";
        _page3SiteAddressLabel.numberOfLines = 1;
        _page3SiteAddressLabel.backgroundColor = [UIColor clearColor];
        _page3SiteAddressLabel.font = [UIFont fontWithName:@"OpenSans" size:14];
        _page3SiteAddressLabel.shadowColor = [WPNUXUtility textShadowColor];
        _page3SiteAddressLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3SiteAddressLabel.textColor = _confirmationLabelColor;
        _page3SiteAddressLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [_scrollView addSubview:_page3SiteAddressLabel];
    }

    if (_page3FifthLineSeparator == nil) {
        _page3FifthLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3FifthLineSeparator];
    }
    
    if (_page3SiteLanguageLabel == nil) {
        _page3SiteLanguageLabel = [[UILabel alloc] init];
        _page3SiteLanguageLabel.textAlignment = UITextAlignmentCenter;
        _page3SiteLanguageLabel.text = @"Site Language: ";
        _page3SiteLanguageLabel.numberOfLines = 1;
        _page3SiteLanguageLabel.backgroundColor = [UIColor clearColor];
        _page3SiteLanguageLabel.font = [UIFont fontWithName:@"OpenSans" size:14];
        _page3SiteLanguageLabel.shadowColor = [WPNUXUtility textShadowColor];
        _page3SiteAddressLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _page3SiteLanguageLabel.textColor = _confirmationLabelColor;
        _page3SiteLanguageLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [_scrollView addSubview:_page3SiteLanguageLabel];
    }
    
    if (_page3SixthLineSeparator == nil) {
        _page3SixthLineSeparator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui-line"]];
        [_scrollView addSubview:_page3SixthLineSeparator];
    }

    // Add Next Button
    if (_page3NextButton == nil) {
        _page3NextButton = [[WPNUXPrimaryButton alloc] init];
        [_page3NextButton setTitle:NSLocalizedString(@"Next", nil) forState:UIControlStateNormal];
        [_page3NextButton addTarget:self action:@selector(clickedPage3NextButton) forControlEvents:UIControlEventTouchUpInside];
        [_page3NextButton sizeToFit];
        [_scrollView addSubview:_page3NextButton];
    }
    
    // Add Previous Button
    if (_page3PreviousButton == nil) {
        _page3PreviousButton = [[WPNUXPrimaryButton alloc] init];
        [_page3PreviousButton setTitle:NSLocalizedString(@"Previous", nil) forState:UIControlStateNormal];
        [_page3PreviousButton addTarget:self action:@selector(clickedPage3PreviousButton) forControlEvents:UIControlEventTouchUpInside];
        [_page3PreviousButton sizeToFit];
        [_scrollView addSubview:_page3PreviousButton];
    }
}

- (void)layoutPage3Controls
{
    CGFloat x,y;
    CGFloat currentPage=3;
    
    // Layout the controls starting out from y of 0, then offset then once the height of the controls
    // is accurately calculated we can determine the vertical center and adjust everything accordingly.
    
    x = (_viewWidth - CGRectGetWidth(_page3Icon.frame))/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = 0;
    _page3Icon.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page2Icon.frame), CGRectGetHeight(_page2Icon.frame)));
    
    // Layout Title
    CGSize titleSize = [_page3Title.text sizeWithFont:_page3Title.font constrainedToSize:CGSizeMake(CreateAccountAndBlogMaxTextWidth, CGFLOAT_MAX) lineBreakMode:UILineBreakModeWordWrap];
    x = (_viewWidth - titleSize.width)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3Icon.frame) + CreateAccountAndBlogStandardOffset;
    _page3Title.frame = CGRectIntegral(CGRectMake(x, y, titleSize.width, titleSize.height));
    
    // Layout First Line Separator
    CGFloat lineSeparatorWidth = _viewWidth - 2*CreateAccountAndBlogStandardOffset;
    CGFloat lineSeparatorHeight = 2;
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3Title.frame) + CreateAccountAndBlogStandardOffset;
    _page3FirstLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Email Label
    CGSize emailLabelSize = [_page3EmailLabel.text sizeWithFont:_page3EmailLabel.font forWidth:CreateAccountAndBlogMaxTextWidth lineBreakMode:UILineBreakModeTailTruncation];
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3FirstLineSeparator.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3EmailLabel.frame = CGRectMake(x, y, emailLabelSize.width, emailLabelSize.height);
    
    // Layout Second Line Separator
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3EmailLabel.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3SecondLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Username Label
    CGSize usernameLabelSize = [_page3UsernameLabel.text sizeWithFont:_page3UsernameLabel.font forWidth:CreateAccountAndBlogMaxTextWidth lineBreakMode:UILineBreakModeTailTruncation];
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3SecondLineSeparator.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3UsernameLabel.frame = CGRectMake(x, y, usernameLabelSize.width, usernameLabelSize.height);
    
    // Layout Third Line Separator
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3UsernameLabel.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3ThirdLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Site Title Label
    CGSize siteTitleLabel = [_page3SiteTitleLabel.text sizeWithFont:_page3SiteTitleLabel.font forWidth:CreateAccountAndBlogMaxTextWidth lineBreakMode:UILineBreakModeTailTruncation];
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3ThirdLineSeparator.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3SiteTitleLabel.frame = CGRectMake(x, y, siteTitleLabel.width, siteTitleLabel.height);
    
    // Layout Fourth Line Separator
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3SiteTitleLabel.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3FourthLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Site Address Label
    CGSize siteAddressLabel = [_page3SiteAddressLabel.text sizeWithFont:_page3SiteAddressLabel.font forWidth:CreateAccountAndBlogMaxTextWidth lineBreakMode:UILineBreakModeTailTruncation];
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3FourthLineSeparator.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3SiteAddressLabel.frame = CGRectMake(x, y, siteAddressLabel.width, siteAddressLabel.height);
    
    // Layout Fifth Line Separator
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3SiteAddressLabel.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3FifthLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Site Address Label
    CGSize siteLanguageLabelSize = [_page3SiteLanguageLabel.text sizeWithFont:_page3SiteLanguageLabel.font forWidth:CreateAccountAndBlogMaxTextWidth lineBreakMode:UILineBreakModeTailTruncation];
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3FifthLineSeparator.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3SiteLanguageLabel.frame = CGRectMake(x, y, siteLanguageLabelSize.width, siteLanguageLabelSize.height);

    // Layout Sixth Line Separator
    x = CreateAccountAndBlogStandardOffset;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3SiteLanguageLabel.frame) + 0.5*CreateAccountAndBlogStandardOffset;
    _page3SixthLineSeparator.frame = CGRectMake(x, y, lineSeparatorWidth, lineSeparatorHeight);
    
    // Layout Previous Button
    x = (_viewWidth - CGRectGetWidth(_page3PreviousButton.frame) - CGRectGetWidth(_page3NextButton.frame) - CreateAccountAndBlogStandardOffset)/2.0;
    x = [self adjustX:x forPage:currentPage];
    y = CGRectGetMaxY(_page3SixthLineSeparator.frame) + CreateAccountAndBlogStandardOffset;
    _page3PreviousButton.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page3PreviousButton.frame), CGRectGetHeight(_page3NextButton.frame)));
    
    // Layout Next Button
    x = CGRectGetMaxX(_page3PreviousButton.frame) + CreateAccountAndBlogStandardOffset;
    y = CGRectGetMaxY(_page3SixthLineSeparator.frame) + CreateAccountAndBlogStandardOffset;
    _page3NextButton.frame = CGRectIntegral(CGRectMake(x, y, CGRectGetWidth(_page3NextButton.frame), CGRectGetHeight(_page3NextButton.frame)));
    
    NSArray *controls = @[_page3Icon, _page3Title, _page3FirstLineSeparator, _page3EmailLabel, _page3SecondLineSeparator, _page3UsernameLabel, _page3ThirdLineSeparator, _page3SiteTitleLabel, _page3FourthLineSeparator, _page3SiteAddressLabel, _page3FifthLineSeparator, _page3SiteLanguageLabel, _page3SixthLineSeparator, _page3PreviousButton, _page3NextButton];
    [WPNUXUtility centerViews:controls withStartingView:_page3Icon andEndingView:_page3NextButton forHeight:_viewHeight];
}

- (void)equalizePreviousAndNextButtonWidths
{
    // Ensure Buttons are same width as the sizeToFit command will generate slightly different widths and we want to make the
    // all the previous/next buttons appear uniform.
    
    CGFloat nextButtonWidth = CGRectGetWidth(_page2NextButton.frame);
    CGFloat previousButtonWidth = CGRectGetWidth(_page2PreviousButton.frame);
    CGFloat biggerWidth = nextButtonWidth > previousButtonWidth ? nextButtonWidth : previousButtonWidth;
    NSArray *controls = @[_page1NextButton, _page2PreviousButton, _page2NextButton, _page3PreviousButton, _page3NextButton];
    for (UIControl *control in controls) {
        CGRect frame = control.frame;
        frame.size.width = biggerWidth;
        control.frame = frame;
    }
}

- (void)updatePage3Labels
{
    _page3EmailLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUX_Create_Account_Page3_Email_Review", nil), _page1EmailText.text];
    _page3UsernameLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUX_Create_Account_Page3_Username_Review", nil), _page1UsernameText.text];
    _page3SiteTitleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUX_Create_Account_Page3_Site_Title_Review", nil), _page2SiteTitleText.text];
    _page3SiteAddressLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUX_Create_Account_Page3_Site_Address_Review", nil), [NSString stringWithFormat:@"%@.wordpress.com", [self getSiteAddressWithoutWordPressDotCom]]];
    _page3SiteLanguageLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUX_Create_Account_Page3_Site_Language_Review", nil), [_currentLanguage objectForKey:@"name"]];
    
    [self layoutPage3Controls];
}

- (void)clickedInfoButton
{
    HelpViewController *helpViewController = [[HelpViewController alloc] init];
    helpViewController.isBlogSetup = YES;
    [self.navigationController pushViewController:helpViewController animated:YES];
}

- (void)clickedCancelButton
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)moveToPage:(NSUInteger)page
{
    [_scrollView setContentOffset:CGPointMake(_viewWidth*(page-1), 0) animated:YES];
}

- (void)clickedOnScrollView:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint touchPoint = [gestureRecognizer locationInView:_scrollView];
    BOOL clickedSiteLanguage = CGRectContainsPoint(_page2SiteLanguageText.frame, touchPoint);
    
    if (clickedSiteLanguage) {
        [self showLanguagePicker];
    } else {
        BOOL clickedPage1Next = CGRectContainsPoint(_page1NextButton.frame, touchPoint) && _page1NextButton.enabled;
        BOOL clickedPage2Next = CGRectContainsPoint(_page2NextButton.frame, touchPoint) && _page2NextButton.enabled;
        BOOL clickedPage2Previous = CGRectContainsPoint(_page2PreviousButton.frame, touchPoint);

        if (_keyboardVisible) {
            // When the keyboard is displayed, the normal button events don't fire off properly as
            // this gesture recognizer intercepts them. We double check that the user didn't press a button
            // while in this mode and if they did hand off the event.
            if (clickedPage1Next) {
                [self clickedPage1NextButton];
            } else if(clickedPage2Next) {
                [self clickedPage2NextButton];
            } else if (clickedPage2Previous) {
                [self clickedPage2PreviousButton];
            }            
        }
        
        [self.view endEditing:YES];
    }
}

- (void)clickedPage1NextButton
{
    [self.view endEditing:YES];
    if (![self page1FieldsValid]) {
        [self showFieldsNotFilledError];
        return;
    }
    
    if (_page1FieldsValid) {
        [self moveToPage:2];
    } else {
        _page1NextButton.enabled = NO;
        [self validateUserFields];
    }
}

- (void)clickedPage2NextButton
{
    [self.view endEditing:YES];
    if (![self page2FieldsValid]) {
        [self showFieldsNotFilledError];
        return;
    }
    
    if (_page2FieldsValid) {
        [self moveToPage:3];
    } else {
        _page2NextButton.enabled = NO;
        [self validateSiteFields];
    }
}

- (void)clickedPage2PreviousButton
{
    [self.view endEditing:YES];
    [self moveToPage:1];
}

- (void)clickedPage3NextButton
{
    [self createUserAndSite];
}

- (void)clickedPage3PreviousButton
{
    [self moveToPage:2];
}


- (void)savePositionsOfStickyControls
{
    if (!_savedOriginalPositionsOfStickyControls) {
        _savedOriginalPositionsOfStickyControls = true;
        _infoButtonOriginalX = CGRectGetMinX(_helpButton.frame);
        _cancelButtonOriginalX = CGRectGetMinX(_cancelButton.frame);
    }
}

- (CGFloat)adjustX:(CGFloat)x forPage:(NSUInteger)page
{
    return (x + _viewWidth*(page-1));
}

- (void)flagPageViewed:(NSUInteger)page
{
    _currentPage = page;
}

- (void)moveStickyControlsForContentOffset:(CGPoint)contentOffset
{
    if (contentOffset.x < 0)
        return;
    
    CGRect cancelButtonFrame = _cancelButton.frame;
    cancelButtonFrame.origin.x = _cancelButtonOriginalX + contentOffset.x;
    _cancelButton.frame =  cancelButtonFrame;
    
    CGRect infoButtonFrame = _helpButton.frame;
    infoButtonFrame.origin.x = _infoButtonOriginalX + contentOffset.x;
    _helpButton.frame = infoButtonFrame;
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    if (_currentPage == 1) {
        _keyboardOffset = (CGRectGetMaxY(_page1NextButton.frame) - CGRectGetMinY(keyboardFrame)) + CGRectGetHeight(_page1NextButton.frame);
    } else {
        _keyboardOffset = (CGRectGetMaxY(_page2NextButton.frame) - CGRectGetMinY(keyboardFrame)) + CGRectGetHeight(_page2NextButton.frame);
    }

    [UIView animateWithDuration:0.3 animations:^{
        NSArray *controlsToMove = @[];
        NSArray *controlsToHide = @[];
        if (_currentPage == 1) {
            controlsToMove = @[_page1Title, _page1UsernameText, _page1EmailText, _page1PasswordText, _page1NextButton];
            controlsToHide = @[_page1Icon, _helpButton, _cancelButton];
        } else if (_currentPage == 2) {
            controlsToMove = @[_page2Title, _page2SiteTitleText, _page2SiteAddressText, _page2SiteLanguageText, _page2SiteLanguageDropdownImage, _page2NextButton, _page2PreviousButton];
            controlsToHide = @[_page2Icon, _helpButton, _cancelButton];
        }
        
        for (UIControl *control in controlsToMove) {
            CGRect frame = control.frame;
            frame.origin.y -= _keyboardOffset;
            control.frame = frame;
        }
        
        for (UIControl *control in controlsToHide) {
            control.alpha = 0.0;
        }        
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [UIView animateWithDuration:0.3 animations:^{
        NSArray *controlsToMove = @[];
        NSArray *controlsToShow = @[];
        if (_currentPage == 1) {
            controlsToMove = @[_page1Title, _page1UsernameText, _page1EmailText, _page1PasswordText, _page1NextButton];
            controlsToShow = @[_page1Icon, _helpButton, _cancelButton];
        } else if (_currentPage == 2) {
            controlsToMove = @[_page2Title, _page2SiteTitleText, _page2SiteAddressText, _page2SiteLanguageText, _page2SiteLanguageDropdownImage, _page2NextButton, _page2PreviousButton];
            controlsToShow = @[_page2Icon, _helpButton, _cancelButton];
        }
        
        for (UIControl *control in controlsToMove) {
            CGRect frame = control.frame;
            frame.origin.y += _keyboardOffset;
            control.frame = frame;
        }
        
        for (UIControl *control in controlsToShow) {
            control.alpha = 1.0;
        }
    }];
}

- (void)keyboardDidShow
{
    _keyboardVisible = true;
}

- (void)keyboardDidHide
{
    _keyboardVisible = false;
}

- (void)showLanguagePicker
{
    [self.view endEditing:YES];
    SelectWPComLanguageViewController *languageViewController = [[SelectWPComLanguageViewController alloc] init];
    languageViewController.currentlySelectedLanguageId = [[_currentLanguage objectForKey:@"lang_id"] intValue];
    languageViewController.didSelectLanguage = ^(NSDictionary *language){
        [self updateLanguage:language];
    };
    [self.navigationController pushViewController:languageViewController animated:YES];
}

- (void)updateLanguage:(NSDictionary *)language
{
    _currentLanguage = language;
    _page2SiteLanguageText.text = [_currentLanguage objectForKey:@"name"];
    _page2FieldsValid = false;
}

- (void)handleRemoteError:(NSError *)error
{
    NSString *errorCode = [error.userInfo objectForKey:WordPressComApiErrorCodeKey];
    NSString *errorMessage;
    
    if ([errorCode isEqualToString:WordPressComApiErrorCodeInvalidUser]) {
        errorMessage = NSLocalizedString(@"Invalid username", @"");
    } else if ([errorCode isEqualToString:WordPressComApiErrorCodeInvalidEmail]) {
        errorMessage = NSLocalizedString(@"Invalid email address", @"");
    } else if ([errorCode isEqualToString:WordPressComApiErrorCodeInvalidPassword]) {
        errorMessage = NSLocalizedString(@"Invalid password", @"");
    } else if ([errorCode isEqualToString:WordPressComApiErrorCodeInvalidBlogUrl]) {
        errorMessage = NSLocalizedString(@"Invalid blog url", @"");
    } else if ([errorCode isEqualToString:WordPressComApiErrorCodeInvalidBlogTitle]) {
        errorMessage = NSLocalizedString(@"Invalid Blog Title", @"");
    } else if ([errorCode isEqualToString:WordPressComApiErrorCodeTooManyRequests]) {
        errorMessage = NSLocalizedString(@"Limit Reached - Contact Support", @"");
    } else {
        errorMessage = NSLocalizedString(@"Unknown error", @"");
    }
    
    [self showError:errorMessage];
}

- (BOOL)page1FieldsFilled
{
    return [self isEmailedFilled] && [self isUsernameFilled] && [self isPasswordFilled];
}

- (BOOL)isEmailedFilled
{
    return ([[_page1EmailText.text trim] length] != 0);
}

- (BOOL)isUsernameFilled
{
    return ([[_page1UsernameText.text trim] length] != 0);
}

- (BOOL)isPasswordFilled
{
    return ([[_page1PasswordText.text trim] length] != 0);
}

- (BOOL)page1FieldsValid
{
    return [self page1FieldsFilled];
}

- (void)showFieldsNotFilledError
{
    [self showError:NSLocalizedString(@"Please fill out all the fields", nil)];
}

- (void)validateUserFields
{
    void (^userValidationSuccess)(id) = ^(id responseObject) {
        _page1NextButton.enabled = YES;
        [SVProgressHUD dismiss];
        _page1FieldsValid = true;
        [self moveToPage:2];
    };
    
    void (^userValidationFailure)(NSError *) = ^(NSError *error){
        _page1NextButton.enabled = YES;
        [SVProgressHUD dismiss];
        [self handleRemoteError:error];
    };
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Validating User Data", nil) maskType:SVProgressHUDMaskTypeBlack];
    [[WordPressComApi sharedApi] validateWPComAccountWithEmail:_page1EmailText.text
                                                   andUsername:_page1UsernameText.text
                                                   andPassword:_page1PasswordText.text
                                                       success:userValidationSuccess
                                                       failure:userValidationFailure];

}

- (BOOL)page2FieldsValid
{
    return [self page2FieldsFilled];
}

- (BOOL)page2FieldsFilled
{
    return [self isSiteTitleFilled] && [self isSiteAddressFilled];
}

- (BOOL)isSiteTitleFilled
{
    return ([[_page2SiteTitleText.text trim] length] != 0);
}

- (BOOL)isSiteAddressFilled
{
    return ([[_page2SiteAddressText.text trim] length] != 0);
}

- (NSString *)getSiteAddressWithoutWordPressDotCom
{
    NSRegularExpression *dotCom = [NSRegularExpression regularExpressionWithPattern:@"\\.wordpress\\.com/?$" options:NSRegularExpressionCaseInsensitive error:nil];
    return [dotCom stringByReplacingMatchesInString:_page2SiteAddressText.text options:0 range:NSMakeRange(0, [_page2SiteAddressText.text length]) withTemplate:@""];
}


- (void)showError:(NSString *)message
{
    WPWalkthroughGrayOverlayView *overlayView = [[WPWalkthroughGrayOverlayView alloc] initWithFrame:self.view.bounds];
    overlayView.overlayMode = WPWalkthroughGrayOverlayViewOverlayModeTapToDismiss;
    overlayView.overlayTitle = NSLocalizedString(@"Error", nil);
    overlayView.overlayDescription = message;
    overlayView.footerDescription = NSLocalizedString(@"TAP TO DISMISS", nil);
    overlayView.singleTapCompletionBlock = ^(WPWalkthroughGrayOverlayView *overlayView){
        [overlayView dismiss];
    };
    [self.view addSubview:overlayView];
}

- (void)validateSiteFields
{
    void (^blogValidationSuccess)(id) = ^(id responseObject) {
        _page2NextButton.enabled = YES;
        [SVProgressHUD dismiss];
        _page2FieldsValid = true;
        [self updatePage3Labels];
        [self moveToPage:3];
    };
    void (^blogValidationFailure)(NSError *) = ^(NSError *error) {
        _page2NextButton.enabled = YES;
        [SVProgressHUD dismiss];
        [self handleRemoteError:error];
    };
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Validating Site Data", nil) maskType:SVProgressHUDMaskTypeBlack];

    NSNumber *languageId = [_currentLanguage objectForKey:@"lang_id"];
    [[WordPressComApi sharedApi] validateWPComBlogWithUrl:[self getSiteAddressWithoutWordPressDotCom]
                                             andBlogTitle:_page2SiteTitleText.text
                                            andLanguageId:languageId
                                                  success:blogValidationSuccess
                                                  failure:blogValidationFailure];
}

- (void)createUserAndSite
{
    WPAsyncBlockOperation *userCreation = [WPAsyncBlockOperation operationWithBlock:^(WPAsyncBlockOperation *operation){
        void (^createUserSuccess)(id) = ^(id responseObject){
            [operation didSucceed];
        };
        void (^createUserFailure)(NSError *) = ^(NSError *error) {
            [operation didFail];
            [SVProgressHUD dismiss];
            [self handleRemoteError:error];
        };
        
        [[WordPressComApi sharedApi] createWPComAccountWithEmail:_page1EmailText.text
                                                     andUsername:_page1UsernameText.text
                                                     andPassword:_page1PasswordText.text
                                                         success:createUserSuccess
                                                         failure:createUserFailure];
        
    }];
    WPAsyncBlockOperation *userSignIn = [WPAsyncBlockOperation operationWithBlock:^(WPAsyncBlockOperation *operation){
        void (^signInSuccess)(void) = ^{
            [operation didSucceed];
        };
        void (^signInFailure)(NSError *) = ^(NSError *error) {
            // We've hit a strange failure at this point, the user has been created successfully but for some reason
            // we are unable to sign in and proceed
            [operation didFail];
            [SVProgressHUD dismiss];
            [self handleRemoteError:error];
        };
        
        [[WordPressComApi sharedApi] signInWithUsername:_page1UsernameText.text
                                               password:_page1PasswordText.text
                                                success:signInSuccess
                                                failure:signInFailure];
    }];
    
    WPAsyncBlockOperation *blogCreation = [WPAsyncBlockOperation operationWithBlock:^(WPAsyncBlockOperation *operation){
        void (^createBlogSuccess)(id) = ^(id responseObject){
            [operation didSucceed];
            [SVProgressHUD dismiss];
            if (self.onCreatedUser) {
                self.onCreatedUser(_page1UsernameText.text, _page1PasswordText.text);
            }
        };
        void (^createBlogFailure)(NSError *error) = ^(NSError *error) {
            [SVProgressHUD dismiss];
            [operation didFail];
            [self handleRemoteError:error];
        };
        
        NSNumber *languageId = [_currentLanguage objectForKey:@"lang_id"];
        [[WordPressComApi sharedApi] createWPComBlogWithUrl:[self getSiteAddressWithoutWordPressDotCom]
                                               andBlogTitle:_page2SiteTitleText.text
                                              andLanguageId:languageId
                                          andBlogVisibility:WordPressComApiBlogVisibilityPublic
                                                    success:createBlogSuccess
                                                    failure:createBlogFailure];

    }];
    
    [blogCreation addDependency:userSignIn];
    [userSignIn addDependency:userCreation];
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Creating User and Site", nil) maskType:SVProgressHUDMaskTypeBlack];
    
    [_operationQueue addOperation:userCreation];
    [_operationQueue addOperation:userSignIn];
    [_operationQueue addOperation:blogCreation];
}

@end
